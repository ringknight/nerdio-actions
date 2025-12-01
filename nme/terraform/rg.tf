resource "azurerm_resource_group" "nerdio" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name != "" ? var.resource_group_name : "${lower(var.base_name)}-rg"
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  resource_group_name     = var.create_resource_group ? azurerm_resource_group.nerdio[0].name : data.azurerm_resource_group.existing[0].name
  resource_group_location = var.create_resource_group ? azurerm_resource_group.nerdio[0].location : data.azurerm_resource_group.existing[0].location
}
