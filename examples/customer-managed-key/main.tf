terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.15.0"
    }
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


# Key Vault needed for CMK
resource "azurerm_key_vault" "this" {
  location = azurerm_resource_group.this.location
  name     = module.naming.key_vault.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku_name = "standard"
  tenant_id = data.azurerm_client_config.this.tenant_id
  purge_protection_enabled = true
  soft_delete_retention_days = 7
}

# Create keys for CMK
resource "azurerm_key_vault_key" "cmkms" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.this.id
  name         = "${module.naming.key_vault_key.name_unique}-cmkms"
  key_size     = 2048

  rotation_policy {
    expire_after         = "P90D"
    notify_before_expiry = "P29D"

    automatic {
      time_before_expiry = "P30D"
    }
  }
}

resource "azurerm_key_vault_key" "managed_disk_cmk" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.this.id
  name         = "${module.naming.key_vault_key.name_unique}-cmkds"
  key_size     = 2048

  rotation_policy {
    expire_after         = "P90D"
    notify_before_expiry = "P29D"

    automatic {
      time_before_expiry = "P30D"
    }
  }
}

resource "azurerm_key_vault_key" "dbfs_root" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.this.id
  name         = "${module.naming.key_vault_key.name_unique}-dbfs-root"
  key_size     = 2048

  rotation_policy {
    expire_after         = "P90D"
    notify_before_expiry = "P29D"

    automatic {
      time_before_expiry = "P30D"
    }
  }
}

# Add the current user to the key vault access policy
resource "azurerm_role_assignment" "current_user" {
  principal_id         = data.azurerm_client_config.this.object_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
}

module "databricks" {
  source = "../.."
  location                                            = azurerm_resource_group.this.location
  name                                                = module.naming.databricks_workspace.name_unique
  resource_group_name                                 = azurerm_resource_group.this.name
  sku                                                 = "premium"
  customer_managed_key_enabled                        = true
  dbfs_root_cmk_key_vault_key_id                      = azurerm_key_vault_key.dbfs_root.id
  managed_disk_cmk_key_vault_key_id                   = azurerm_key_vault_key.managed_disk_cmk.id
  managed_disk_cmk_rotation_to_latest_version_enabled = true
  managed_services_cmk_key_vault_key_id               = azurerm_key_vault_key.cmkms.id
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
