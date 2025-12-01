resource "random_password" "sql_password" {
  length           = 30
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_mssql_database" "nerdio" {
  name      = "Nerdio"
  server_id = azurerm_mssql_server.nerdio.id
  collation = "Latin1_General_CI_AS"
  sku_name  = var.sql_sku

  zone_redundant = false

  tags = var.tags
}

resource "azurerm_mssql_server" "nerdio" {
  name                = "${lower(var.base_name)}-sql"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  version             = "12.0"
  minimum_tls_version = "1.2"
  connection_policy   = "Default"
  administrator_login          = "adminlogin"
  administrator_login_password = random_password.sql_password.result

  public_network_access_enabled        = var.allow_public_access
  outbound_network_restriction_enabled = true

  azuread_administrator {
    login_username              = azuread_group.sql_admins.display_name
    object_id                   = azuread_group.sql_admins.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = false
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

#
# Entra ID Admin Group
#
resource "azuread_group" "sql_admins" {
  display_name            = "Azure SQL Server Administrators - ${lower(var.base_name)}-sql"
  prevent_duplicate_names = true
  security_enabled        = true
}

resource "azuread_group_member" "nerdio_webapp_sql_admin" {
  group_object_id  = azuread_group.sql_admins.id
  member_object_id = azurerm_windows_web_app.nerdio.identity[0].principal_id
}

#
# Private Endpoint
#
resource "azurerm_private_endpoint" "sql" {
  name                = "${azurerm_mssql_server.nerdio.name}-ple"
  resource_group_name = azurerm_mssql_server.nerdio.resource_group_name
  location            = azurerm_mssql_server.nerdio.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_dns_zone_group {
    name = azurerm_mssql_server.nerdio.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.private_link["sqlserver"].id
    ]
  
  }

  private_service_connection {
    name                           = "Nerdio"
    private_connection_resource_id = azurerm_mssql_server.nerdio.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }


depends_on = [ azapi_resource.msdeploy,azurerm_key_vault_access_policy.nerdio_service_principal,azurerm_key_vault_access_policy.nerdio_webapp,azurerm_key_vault_certificate.nerdio,azurerm_key_vault_secret.azuread_client_secret,azurerm_key_vault_secret.sql_connection ]
  tags = var.tags
}
