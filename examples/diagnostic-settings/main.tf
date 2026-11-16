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
  version = ">= 0.4.1"
}

resource "azurerm_resource_group" "this" {
  location = "West Europe"
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

module "databricks" {
  source              = "../.."
  name                = module.naming.databricks_workspace.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "standard"
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
