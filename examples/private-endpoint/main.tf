terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.117, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "this" {}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = ">= 0.8.0"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.1"
}

resource "azurerm_resource_group" "this" {
  location = "West Europe"
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "public" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "public"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  delegation {
    name = "databricks-del-public"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "private"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  delegation {
    name = "databricks-del-private"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

# Subnet for Private Endpoint
resource "azurerm_subnet" "privateendpoint" {
  address_prefixes     = ["10.0.3.0/24"]
  name                 = "private-endpoint"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

# Network Security Group and associations
resource "azurerm_network_security_group" "this" {
  location            = azurerm_resource_group.this.location
  name                = "databricks-nsg"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet_network_security_group_association" "public" {
  network_security_group_id = azurerm_network_security_group.this.id
  subnet_id                 = azurerm_subnet.public.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  network_security_group_id = azurerm_network_security_group.this.id
  subnet_id                 = azurerm_subnet.private.id
}

resource "azurerm_subnet_network_security_group_association" "privateendpoint" {
  network_security_group_id = azurerm_network_security_group.this.id
  subnet_id                 = azurerm_subnet.privateendpoint.id
}

# Private DNS Zone and VNet link
resource "azurerm_private_dns_zone" "azuredatabricks" {
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "databricks" {
  name                  = "vnet-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.azuredatabricks.name
  virtual_network_id    = azurerm_virtual_network.this.id
}

# Databricks Access Connector
resource "azurerm_databricks_access_connector" "this" {
  location            = azurerm_resource_group.this.location
  name                = "databricks-access-connector"
  resource_group_name = azurerm_resource_group.this.name
  identity {
    type = "SystemAssigned"
  }
}

module "databricks" {
  source              = "../.."
  name                = module.naming.databricks_workspace.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "premium"
  access_connector_id = azurerm_databricks_access_connector.this.id
  default_storage_firewall_enabled = true
  public_network_access_enabled = false
  network_security_group_rules_required = "NoAzureDatabricksRules"
  custom_parameters = {
    private_subnet_name                                  = azurerm_subnet.private.name
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private.id
    public_subnet_name                                   = azurerm_subnet.public.name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.public.id
    virtual_network_id                                   = azurerm_virtual_network.this.id
    no_public_ip                                         = true
  }
  private_endpoints = {
    databricks_ui_api = {
      name                            = "pe-databricks-ui-api"
      private_service_connection_name = "pse-databricks-ui-api"
      subresource_name                = "databricks_ui_api"
      location                        = azurerm_resource_group.this.location
      private_dns_zone_resource_ids   = [azurerm_private_dns_zone.azuredatabricks.id]
      subnet_resource_id              = azurerm_subnet.privateendpoint.id
    }
  }
  tags = {
    environment = "dev"
    project     = "databricks"
  }
}

output "workspace_id" {
  value = module.databricks.databricks_workspace_id
}
output "workspace_url" {
  value = module.databricks.databricks_workspace_url
}
