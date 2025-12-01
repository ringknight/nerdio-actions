resource "azurerm_network_security_rule" "webapp_inbound_private" {
  name                         = "Inbound-To-WebApp-Private"
  priority                     = 1000
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "*"
  destination_address_prefixes = [for k, v in azurerm_private_endpoint.webapp.private_service_connection : v.private_ip_address]
  resource_group_name          = azurerm_network_security_group.nerdio.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nerdio.name
}

resource "azurerm_network_security_rule" "webapp_to_sql" {
  name                         = "Inbound-WebApp-To-Sql"
  priority                     = 2000
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "1433"
  source_address_prefixes      = azurerm_subnet.appsvc.address_prefixes
  destination_address_prefixes = [for k, v in azurerm_private_endpoint.sql.private_service_connection : v.private_ip_address]
  resource_group_name          = azurerm_network_security_group.nerdio.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nerdio.name
}

resource "azurerm_network_security_rule" "webapp_to_key_vault" {
  name                         = "Inbound-WebApp-To-KeyVault"
  priority                     = 2100
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefixes      = azurerm_subnet.appsvc.address_prefixes
  destination_address_prefixes = [for k, v in azurerm_private_endpoint.key_vault.private_service_connection : v.private_ip_address]
  resource_group_name          = azurerm_network_security_group.nerdio.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nerdio.name
}

resource "azurerm_network_security_rule" "webapp_to_automation" {
  name                         = "Inbound-WebApp-To-Automation"
  priority                     = 2200
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefixes      = azurerm_subnet.appsvc.address_prefixes
  destination_address_prefixes = [for k, v in azurerm_private_endpoint.automation_webhook.private_service_connection : v.private_ip_address]
  resource_group_name          = azurerm_network_security_group.nerdio.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nerdio.name
}

#
# Deny all
#
resource "azurerm_network_security_rule" "inbound_deny_all" {
  name                        = "Inbound-Deny-All"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.nerdio.resource_group_name
  network_security_group_name = azurerm_network_security_group.nerdio.name
}
