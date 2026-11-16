# Databricks Workspace Module

This module deploys an Azure Databricks Workspace with optional support for networking, private endpoints, access connectors, and customer-managed keys.

## Features
- Databricks workspace creation
- Optional VNet/subnet integration
- Private endpoint support
- Access connector support
- Customer-managed key support
- Flexible custom parameters

## Usage

### Simple Example
```hcl
module "databricks" {
  source              = "."
  name                = "example-dbricks"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "standard"
}
```

### Complex Example
```hcl
module "databricks" {
  source              = "."
  name                = "complex-dbricks"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "premium"
  public_network_access_enabled = false
  custom_parameters = {
    private_subnet_name = azurerm_subnet.private.name
    virtual_network_id  = azurerm_virtual_network.this.id
    no_public_ip        = true
  }
}
```

### Managed Key Example
```hcl
module "databricks" {
  source              = "."
  name                = "managedkey-dbricks"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "premium"
  customer_managed_key_enabled = true
  custom_parameters = {
    managed_disk_cmk_key_vault_id     = azurerm_key_vault.this.id
    managed_disk_cmk_key_vault_key_id = azurerm_key_vault_key.this.id
  }
}
```

## Inputs
See `variables.tf` for all available variables.

## Outputs
- `databricks_workspace_id`: The ID of the Databricks workspace
- `databricks_workspace_url`: The URL of the Databricks workspace
