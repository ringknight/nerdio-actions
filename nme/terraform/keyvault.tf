resource "azurerm_key_vault" "nerdio" {
  name                = "${lower(var.base_name)}-kv"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  sku_name                 = "standard"
  purge_protection_enabled = false

  enable_rbac_authorization = false # Nerdio requires Access Policies
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  public_network_access_enabled = true

  network_acls {
    default_action = var.allow_public_access ? "Allow" : "Deny"
    bypass         = "None"
    # ip_rules       = var.allowed_public_ips
  }

  tags = var.tags
}

# Access Policies
resource "azurerm_key_vault_access_policy" "nerdio_webapp" {
  key_vault_id = azurerm_key_vault.nerdio.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_web_app.nerdio.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
  ]
}

resource "azurerm_key_vault_access_policy" "nerdio_service_principal" {
  key_vault_id = azurerm_key_vault.nerdio.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.nerdio_manager.object_id

  secret_permissions = [
    "Get",
  ]
}

resource "azurerm_key_vault_access_policy" "nerdio_WVDAdmin" {
    key_vault_id = azurerm_key_vault.nerdio.id
    tenant_id = data.azurerm_client_config.current.tenant_id
    #object_id =  "b0fae5ac-6380-4d7d-9b28-bd51f9fc65fe" #need to resolve as to why it can't get the object ID
    object_id =  data.azuread_client_config.current.object_id

      secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Backup",
      "Recover",
      "Restore"
    ]

    key_permissions = [
      "Get",
      "List",
      "Sign",
      "Verify",
      "Encrypt",
      "Decrypt",
      "WrapKey",
      "UnwrapKey",
      "Backup",
      "Restore",
      "Create",
      "Update",
      "Import",
      "Delete"

    ]

    storage_permissions = [
      "Get",
      "List",
      "Delete",
      "Set",
      "Update",
      "RegenerateKey"
    ]

    certificate_permissions = [

      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore"

     ]
  }

# Secrets
resource "azurerm_key_vault_secret" "azuread_client_secret" {
  name         = "AzureAD--ClientSecret"
  value        = azuread_service_principal_password.nerdio_manager.value
  key_vault_id = azurerm_key_vault.nerdio.id

  not_before_date = azuread_service_principal_password.nerdio_manager.start_date
  expiration_date = azuread_service_principal_password.nerdio_manager.end_date

  depends_on = [ azurerm_key_vault_access_policy.nerdio_WVDAdmin ]
}

resource "azurerm_key_vault_secret" "sql_connection" {
  name = "ConnectionStrings--DefaultConnection"
  value = join(";", [
    "Server=tcp:${azurerm_mssql_server.nerdio.fully_qualified_domain_name},1433",
    "Database=${azurerm_mssql_database.nerdio.name}",
   // "Authentication=Active Directory Managed Identity",
    "Persist Security Info=False",
    "User ID=${azurerm_mssql_server.nerdio.administrator_login}",
    "Password=${azurerm_mssql_server.nerdio.administrator_login_password}",
    "MultipleActiveResultSets=False",
    "Encrypt=True",
    "TrustServerCertificate=False",
    "Connection Timeout=30",
  ])
  key_vault_id = azurerm_key_vault.nerdio.id

depends_on = [ azurerm_key_vault_access_policy.nerdio_WVDAdmin ]

}

# Private Endpoint
resource "azurerm_private_endpoint" "key_vault" {
  name                = "${azurerm_key_vault.nerdio.name}-ple"
  resource_group_name = azurerm_key_vault.nerdio.resource_group_name
  location            = azurerm_key_vault.nerdio.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_dns_zone_group {
    name = azurerm_key_vault.nerdio.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.private_link["keyvault"].id
    ]
  }

  private_service_connection {
    name                           = "Nerdio"
    private_connection_resource_id = azurerm_key_vault.nerdio.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

depends_on = [ azapi_resource.msdeploy,azurerm_key_vault_access_policy.nerdio_service_principal,azurerm_key_vault_access_policy.nerdio_webapp,azurerm_key_vault_certificate.nerdio,azurerm_key_vault_secret.azuread_client_secret,azurerm_key_vault_secret.sql_connection ]
  tags = var.tags
}
