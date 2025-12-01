output "webapp" {
  description = "Details of the deployed Web App."
  value = {
    id                  = azurerm_windows_web_app.nerdio.id
    name                = azurerm_windows_web_app.nerdio.name
    resource_group_name = azurerm_windows_web_app.nerdio.resource_group_name
    default_hostname    = azurerm_windows_web_app.nerdio.default_hostname
  }
}

output "automation_account" {
  description = "Details of the deployed Automation Account."
  value = {
    id                  = azurerm_automation_account.nerdio.id
    name                = azurerm_automation_account.nerdio.name
    resource_group_name = azurerm_automation_account.nerdio.resource_group_name
    dsc_server_endpoint = azurerm_automation_account.nerdio.dsc_server_endpoint
    hybrid_service_url  = azurerm_automation_account.nerdio.hybrid_service_url
  }
}

output "key_vault" {
  description = "Details of the deployed Key Vault."
  value = {
    id                  = azurerm_key_vault.nerdio.id
    name                = azurerm_key_vault.nerdio.name
    resource_group_name = azurerm_key_vault.nerdio.resource_group_name
    vault_uri           = azurerm_key_vault.nerdio.vault_uri
  }
}

output "shared_image_gallery" {
  description = "Details of the deployed Shared Image Gallery."
  value = {
    id                  = azurerm_shared_image_gallery.nerdio.id
    name                = azurerm_shared_image_gallery.nerdio.name
    resource_group_name = azurerm_shared_image_gallery.nerdio.resource_group_name
    unique_name         = azurerm_shared_image_gallery.nerdio.unique_name
  }
}

output "sql_server" {
  description = "Details of the deployed SQL Server."
  value = {
    id                  = azurerm_mssql_server.nerdio.id
    name                = azurerm_mssql_server.nerdio.name
    resource_group_name = azurerm_mssql_server.nerdio.resource_group_name
    fqdn                = azurerm_mssql_server.nerdio.fully_qualified_domain_name
  }
}

output "virtual_network" {
  description = "Details of the deployed SQL Server."
  value = {
    id                  = azurerm_virtual_network.nerdio.id
    name                = azurerm_virtual_network.nerdio.name
    resource_group_name = azurerm_virtual_network.nerdio.resource_group_name
  }
}
