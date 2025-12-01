locals {
  pl_zones = {
    automation = "privatelink.azure-automation.net"
    keyvault   = "privatelink.vaultcore.azure.net"
    sqlserver  = "privatelink.database.windows.net"
    website    = "privatelink.azurewebsites.net"
  }
}

resource "azurerm_private_dns_zone" "private_link" {
  for_each = local.pl_zones

  name                = each.value
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_link" {
  for_each = azurerm_private_dns_zone.private_link

  name                  = azurerm_virtual_network.nerdio.name
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.nerdio.id
}
