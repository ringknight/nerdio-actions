variable "base_name" {
  description = "(Required) Base name for all resources to be deployed. Resource-specific suffixes will be appended."
  type        = string
}

variable "location" {
  description = "(Required) Azure region into which all resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "(Optional) Name of the Azure resource group. If not provided and create_resource_group is true, will be constructed from base_name."
  type        = string
  default     = ""
}

variable "create_resource_group" {
  description = "(Optional) Whether to create a new resource group (true) or use an existing one (false). Defaults to true."
  type        = bool
  default     = true
}

variable "packageUri" {
  description = "(Required) URI of the zip package to be deployed to the web app. This package should contain the Nerdio Manager for WVD application files."
  type        = string
  validation {
    condition     = can(regex("https://.*\\.zip", var.packageUri))
    error_message = "The packageUri must be a valid HTTPS URL ending with .zip"
  }
  
}

variable "vnet_address_space" {
  description = "(Required) Address space to be assigned to the new virtual network."
  type        = list(string)
}

variable "allow_public_access" {
  description = "(Optional) Should public access be enabled to services. Defaults to `false`."
  type        = bool
  default     = true
}

variable "webapp_sku" {
  description = "(Optional) SKU of the SQL database to deploy. Defaults to `B3`."
  type        = string
  default     = "B3"
}

variable "sql_sku" {
  description = "(Optional) SKU of the SQL database to deploy. Defaults to `S1`."
  type        = string
  default     = "S1"
}

variable "allow_delegated_write_permissions" {
  description = "(Optional) Should the Entra ID application be deployed with delegated Entra ID write permissions. Defaults to `true`."
  type        = bool
  default     = true
}

variable "nerdio_tag_prefix" {
  description = "(Optional) Prefix to be used by Nerdio for its tags. Defaults to `NMW`."
  type        = string
  default     = "NMW"
}

variable "desktop_admins" {
  description = "(Optional) Map of identities to be added to the Desktop Admin role."
  type        = map(string)
  default     = {}
}

variable "desktop_users" {
  description = "(Optional) Map of identities to be added the Desktop User role."
  type        = map(string)
  default     = {}
}

variable "helpdesk_users" {
  description = "(Optional) Map of identities to be added the Help Desk role."
  type        = map(string)
  default     = {}
}

variable "reviewers" {
  description = "(Optional) Map of identities to be added the Reviewers role."
  type        = map(string)
  default     = {}
}

variable "nerdio_admins" {
  description = "(Optional) Map of identities to be added the Nerdio Admin role."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "(Optional) Tags to be applied to all resources."
  type        = map(string)
  default     = {}
}
