# Private Endpoints variable for advanced networking scenarios
variable "private_endpoints" {
	type = map(object({
		application_security_group_associations = optional(map(string), {})
		# Add other fields as needed for your use case
	}))
	default     = {}
	description = "Map of private endpoint configurations, including application security group associations."
}
# Advanced Databricks Workspace variables for full feature support
variable "access_connector_id" {
	type        = string
	default     = null
	description = "The ID of the Databricks Access Connector to provide access to the workspace."
}

variable "default_storage_firewall_enabled" {
	type        = bool
	default     = false
	description = "Disallow public access to default storage account. Defaults to false."
}

variable "load_balancer_backend_address_pool_id" {
	type        = string
	default     = null
	description = "Resource ID of the Outbound Load balancer Backend Address Pool for Secure Cluster Connectivity (No Public IP) workspace."
}

variable "managed_disk_cmk_key_vault_id" {
	type        = string
	default     = null
	description = "Resource ID of the Key Vault which contains the managed_disk_cmk_key_vault_key_id key."
}

variable "managed_disk_cmk_key_vault_key_id" {
	type        = string
	default     = null
	description = "The ID of the customer-managed key for managed disks."
}

variable "managed_disk_cmk_rotation_to_latest_version_enabled" {
	type        = bool
	default     = null
	description = "Whether to automatically rotate managed disk CMK to the latest version."
}

variable "managed_services_cmk_key_vault_id" {
	type        = string
	default     = null
	description = "Resource ID of the Key Vault for managed services CMK."
}

variable "managed_services_cmk_key_vault_key_id" {
	type        = string
	default     = null
	description = "The ID of the customer-managed key for managed services."
}

variable "network_security_group_rules_required" {
	type        = string
	default     = null
	description = "Specifies which NSG rules are required for the workspace."
}

variable "enhanced_security_compliance" {
  description = "Enhanced security compliance settings for the Databricks workspace."
  type = object({
    automatic_cluster_update_enabled      = bool
    compliance_security_profile_enabled   = bool
    compliance_security_profile_standards = string
    enhanced_security_monitoring_enabled  = bool
  })
  default = null
}

# ============================================================================
# Required Variables
# ============================================================================

variable "name" {
	type        = string
	description = "The name of the Databricks Workspace."
	nullable    = false
}

variable "location" {
	type        = string
	description = "Azure region where the Databricks Workspace should be deployed."
	nullable    = false
}

variable "resource_group_name" {
	type        = string
	description = "The name of the Resource Group where the Databricks Workspace will be deployed."
	nullable    = false
}

variable "sku" {
	type        = string
	description = "The SKU for the Databricks Workspace. Common values: standard, premium."
	nullable    = false
	validation {
		condition     = contains(["standard", "premium"], lower(var.sku))
		error_message = "The value must be either 'standard' or 'premium'."
	}
}

# ============================================================================
# Optional Variables
# ============================================================================

variable "tags" {
	type        = map(string)
	default     = {}
	description = "A map of tags to assign to the resource."
}

variable "public_network_access_enabled" {
	type        = bool
	default     = true
	description = "Whether public network access is enabled for the workspace."
}

variable "managed_resource_group_name" {
	type        = string
	default     = null
	description = "The name of the managed resource group for Databricks. If not set, Azure will create one."
}

variable "customer_managed_key_enabled" {
	type        = bool
	default     = false
	description = "Whether customer managed keys are enabled for the workspace."
}

variable "infrastructure_encryption_enabled" {
	type        = bool
	default     = false
	description = "Whether infrastructure encryption is enabled for the workspace."
}

variable "custom_parameters" {
  type = object({
    machine_learning_workspace_id                        = optional(string, null)
    nat_gateway_name                                     = optional(string)
    public_ip_name                                       = optional(string)
    no_public_ip                                         = optional(bool, false)
    public_subnet_name                                   = optional(string, null)
    public_subnet_network_security_group_association_id  = optional(string, null)
    private_subnet_name                                  = optional(string, null)
    private_subnet_network_security_group_association_id = optional(string, null)
    storage_account_name                                 = optional(string, null) # Defaults to a randomized name
    storage_account_sku_name                             = optional(string, "Standard_GRS")
    virtual_network_id                                   = optional(string, null)
    vnet_address_prefix                                  = optional(string)
  })
  default     = {}
  description = <<DESCRIPTION
A map of custom parameters for configuring the Databricks Workspace. This object allows for detailed configuration, with each attribute representing a specific setting:

- `machine_learning_workspace_id` - (Optional) The ID of an Azure Machine Learning workspace to link with the Databricks workspace.
- `nat_gateway_name` - (Optional) Name of the NAT gateway for Secure Cluster Connectivity (No Public IP) workspace subnets. Defaults to 'nat-gateway'.
- `public_ip_name` - (Optional) Name of the Public IP for No Public IP workspace with managed vNet. Defaults to 'nat-gw-public-ip'.
- `no_public_ip` - (Optional) Specifies whether public IP Addresses are not allowed. Defaults to false. Note: Updating this parameter is only allowed if the value is changing from false to true and only for VNet-injected workspaces.
- `public_subnet_name` - (Optional) The name of the Public Subnet within the Virtual Network.
- `public_subnet_network_security_group_association_id` - (Optional) The resource ID of the azurerm_subnet_network_security_group_association which is referred to by the public_subnet_name field.
- `private_subnet_name` - (Optional) The name of the Private Subnet within the Virtual Network.
- `private_subnet_network_security_group_association_id` - (Optional) The resource ID of the azurerm_subnet_network_security_group_association which is referred to by the private_subnet_name field.
- `storage_account_name` - (Optional) Default Databricks File Storage account name. Defaults to a randomized name.
- `storage_account_sku_name` - (Optional) Storage account SKU name. Defaults to 'Standard_GRS'.
- `virtual_network_id` - (Optional) The ID of a Virtual Network where the Databricks Cluster should be created. More information about VNet injection can be found [here](https://learn.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/vnet-inject).
- `vnet_address_prefix` - (Optional) Address prefix for Managed virtual network. Defaults to '10.139'.

Note: Databricks requires that a network security group is associated with the public and private subnets when a virtual_network_id has been defined.
DESCRIPTION

  validation {
    condition = var.custom_parameters.virtual_network_id == null || (var.custom_parameters.public_subnet_name != null &&
      var.custom_parameters.private_subnet_name != null &&
      var.custom_parameters.public_subnet_network_security_group_association_id != null &&
    var.custom_parameters.private_subnet_network_security_group_association_id != null)
    error_message = "'public_subnet_name', 'private_subnet_name', 'public_subnet_network_security_group_association_id' and 'private_subnet_network_security_group_association_id' must all have values if 'virtual_network_id' is set."
  }
}

# ============================================================================
# Advanced/Optional Features
# ============================================================================

variable "lock" {
	type = object({
		kind = string
		name = optional(string)
	})
	default     = null
	description = "Optional management lock configuration. Example: { kind = \"CanNotDelete\", name = \"my-lock\" }"
}

variable "role_assignments" {
	type = map(object({
		principal_id                           = string
		condition                              = optional(string)
		condition_version                      = optional(string)
		delegated_managed_identity_resource_id = optional(string)
		role_definition_id                     = optional(string)
		role_definition_name                   = optional(string)
		skip_service_principal_aad_check       = optional(bool)
	}))
	default     = null
	description = "Map of role assignments to create on the Databricks workspace."
}

variable "diagnostic_settings" {
	type = map(object({
		name                              = optional(string)
		event_hub_authorization_rule_resource_id = optional(string)
		event_hub_name                    = optional(string)
		workspace_resource_id             = optional(string)
		marketplace_partner_resource_id   = optional(string)
		storage_account_resource_id       = optional(string)
		log_categories                    = optional(list(string))
		log_groups                        = optional(list(string))
	}))
	default     = null
	description = "Map of diagnostic settings for the Databricks workspace."
}

variable "dbfs_root_cmk_key_vault_key_id" {
	type        = string
	default     = null
	description = "The Key Vault Key ID for the root DBFS customer managed key. Required if customer_managed_key_enabled is true and you want to enable root DBFS CMK."
}

variable "virtual_network_peering" {
	type = map(object({
		name                         = optional(string)
		remote_address_space_prefixes = list(string)
		remote_virtual_network_id    = string
		resource_group_name          = optional(string)
		allow_forwarded_traffic      = optional(bool)
		allow_gateway_transit        = optional(bool)
		allow_virtual_network_access = optional(bool)
		use_remote_gateways          = optional(bool)
	}))
	default     = null
	description = "Map of virtual network peering configurations for the Databricks workspace."
}

variable "access_connector" {
	type = map(object({
		location            = optional(string)
		name                = optional(string)
		resource_group_name = optional(string)
		tags                = optional(map(string))
		identity = optional(object({
			type         = string
			identity_ids = optional(list(string))
		}))
	}))
	default     = null
	description = "Map of Databricks access connector configurations."
}
