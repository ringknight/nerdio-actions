locals {
  # Generate a unique string based on subscription and resource group
  unique_str = substr(sha256("${data.azurerm_client_config.current.subscription_id}${data.azurerm_resource_group.main.id}"), 0, 13)

  # Resource names with conditional overrides
  web_app_portal_name                  = var.web_app_portal_name != "" ? var.web_app_portal_name : "${var.app_name}-${local.unique_str}"
  app_service_plan_name                = var.app_service_plan_name != "" ? var.app_service_plan_name : "${var.app_name}-plan-${local.unique_str}"
  sql_server_name                      = var.sql_server_name != "" ? var.sql_server_name : "${var.app_name}-sql-${local.unique_str}"
  database_name                        = var.database_name != "" ? var.database_name : "${var.app_name}-db"
  key_vault_name                       = var.key_vault_name != "" ? var.key_vault_name : "${var.app_name}-kv-${local.unique_str}"
  app_insights_name                    = var.app_insights_name != "" ? var.app_insights_name : "${var.app_name}-insights-${local.unique_str}"
  automation_account_name              = var.automation_account_name != "" ? var.automation_account_name : "${var.app_name}-automation-${local.unique_str}"
  law_name                             = var.law_name != "" ? var.law_name : "${var.app_name}-law-${local.unique_str}"
  logs_law_name                        = var.logs_law_name != "" ? var.logs_law_name : "${var.app_name}-law-insights-${local.unique_str}"
  scripted_action_account_name         = var.scripted_action_account_name != "" ? var.scripted_action_account_name : "${var.app_name}-scripted-actions-${local.unique_str}"
  data_protection_storage_account_name = var.data_protection_storage_account_name != "" ? var.data_protection_storage_account_name : "dps${local.unique_str}"

  # Specific resource names
  dce_name                 = "dce-${local.law_name}"
  dcr_name                 = "microsoft-avdi-${local.law_name}"
  data_protection_key_name = "DataProtection-${local.unique_str}"
  data_protection_key_uri  = "https://${local.key_vault_name}${local.keyvault_suffix}/keys/${local.data_protection_key_name}"

  # Container names
  data_protection_storage_blob_container = "dataprotectionkeys"
  blob_lease_container                   = "locks"

  # Role definitions
  contributor_role_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"

  # Environment detection using cloud environment variable
  environment = var.azure_environment != "" ? var.azure_environment : "public"

  # Environment-specific suffixes and URIs
  sql_server_suffix = local.environment == "usgovernment" ? ".database.usgovcloudapi.net" : (
    local.environment == "china" ? ".database.chinacloudapi.cn" :
  ".database.windows.net")

  microsoft_login_uri = local.environment == "usgovernment" ? "https://login.microsoftonline.us/" : (
    local.environment == "china" ? "https://login.chinacloudapi.cn/" :
  "https://login.microsoftonline.com/")

  keyvault_suffix = local.environment == "usgovernment" ? ".vault.usgovcloudapi.net" : (
    local.environment == "china" ? ".vault.azure.cn" :
  ".vault.azure.net")

  storage_suffix = local.environment == "usgovernment" ? "core.usgovcloudapi.net" : (
    local.environment == "china" ? "core.chinacloudapi.cn" :
  "core.windows.net")

  # Private DNS Zone names (environment-specific)
  sql_private_dns_zone_name = "privatelink${local.sql_server_suffix}"

  app_service_private_dns_zone_name = local.environment == "usgovernment" ? "privatelink.azurewebsites.us" : (
    local.environment == "china" ? "privatelink.chinacloudsites.cn" :
  "privatelink.azurewebsites.net")

  key_vault_private_dns_zone_name = local.environment == "usgovernment" ? "privatelink.vaultcore.usgovcloudapi.net" : (
    local.environment == "china" ? "privatelink.vaultcore.azure.cn" :
  "privatelink.vaultcore.azure.net")

  blob_private_dns_zone_name = "privatelink.blob.${local.storage_suffix}"
  file_private_dns_zone_name = "privatelink.file.${local.storage_suffix}"

  automation_private_dns_zone_name = local.environment == "usgovernment" ? "privatelink.azure-automation.us" : (
    local.environment == "china" ? "privatelink.azure-automation.cn" :
  "privatelink.azure-automation.net")
}
