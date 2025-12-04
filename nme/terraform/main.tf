
resource "azurerm_windows_web_app" "nerdio" {
  name                      = "${lower(var.base_name)}-app"
  location                  = local.resource_group_location
  resource_group_name       = local.resource_group_name
  service_plan_id           = azurerm_service_plan.nerdio.id
  https_only                = true
  virtual_network_subnet_id = azurerm_subnet.appsvc.id

  site_config {
    always_on = true
    # health_check_path      = "/public/health/status" # Can't use this as it has a 5 min threshold internally
    http2_enabled          = true
    minimum_tls_version    = 1.2
    ftps_state             = "Disabled"
    use_32_bit_worker      = false
    vnet_route_all_enabled = true

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
  }

  app_settings = {
    "ApplicationInsights:ConnectionString"   = azurerm_application_insights.nerdio.connection_string
    "ApplicationInsights:InstrumentationKey" = azurerm_application_insights.nerdio.instrumentation_key
    "AzureAd:Instance"                       = "https://login.microsoftonline.com/"
    "AzureAd:ClientId"                       = azuread_application.nerdio_manager.client_id
    "AzureAd:TenantId"                       = data.azurerm_subscription.current.tenant_id
    "Billing:Mode"                           = "MAU"
    "Deployment:AutomationAccountName"       = azurerm_automation_account.nerdio.name
    "Deployment:AutomationEnabled"           = "True"
    "Deployment:AzureTagPrefix"               = var.nerdio_tag_prefix
    "Deployment:AzureType"                   = "AzureCloud"
    "Deployment:KeyVaultName"                = azurerm_key_vault.nerdio.name
    "Deployment:LogAnalyticsWorkspace"       = azurerm_log_analytics_workspace.nerdio.id
    "Deployment:Region"                      = local.resource_group_location
    "Deployment:ResourceGroupName"           = local.resource_group_name
    "Deployment:ScriptedActionAccount"       = azurerm_automation_account.nerdio.id
    "Deployment:SubscriptionId"              = data.azurerm_subscription.current.subscription_id
    "Deployment:SubscriptionDisplayName"     = data.azurerm_subscription.current.display_name
    "Deployment:TenantId"                    = data.azurerm_subscription.current.tenant_id
    "Deployment:UpdaterRunbookRunAs"         = "nmwUpdateRunAs"
    "Deployment:WebAppName"                  = "${lower(var.base_name)}-app"
    "RoleAuthorization:Enabled"              = "True"
    "WVD:AadTenantId"                        = data.azurerm_subscription.current.tenant_id
    "WVD:SubscriptionId"                     = data.azurerm_subscription.current.subscription_id
    "WEBSITE_RUN_FROM_PACKAGE"               = var.packageUri
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_service_plan" "nerdio" {
  name                = "${lower(var.base_name)}-plan"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  sku_name            = var.webapp_sku
  os_type             = "Windows"

  tags = var.tags
}

resource "azurerm_private_endpoint" "webapp" {
  name                = "${azurerm_windows_web_app.nerdio.name}-ple"
  resource_group_name = azurerm_windows_web_app.nerdio.resource_group_name
  location            = azurerm_windows_web_app.nerdio.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_dns_zone_group {
    name = azurerm_windows_web_app.nerdio.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.private_link["website"].id
    ]
  }

  private_service_connection {
    name                           = "Nerdio"
    private_connection_resource_id = azurerm_windows_web_app.nerdio.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  depends_on = [ 
    azapi_resource.msdeploy,  # Deploy package BEFORE creating private endpoint
    azurerm_key_vault_access_policy.nerdio_service_principal,
    azurerm_key_vault_access_policy.nerdio_webapp,
    azurerm_key_vault_certificate.nerdio,
    azurerm_key_vault_secret.azuread_client_secret,
    azurerm_key_vault_secret.sql_connection
  ]

  tags = var.tags
}

# Wait for web app to be fully configured before deploying package
resource "time_sleep" "wait_for_webapp" {
  depends_on = [
    azurerm_windows_web_app.nerdio,
    azurerm_key_vault_access_policy.nerdio_webapp
  ]

  create_duration = "60s"
}

resource "azapi_resource" "msdeploy" {
  type = "Microsoft.Web/sites/extensions@2022-09-01"
  name = "MSDeploy"
  parent_id = azurerm_windows_web_app.nerdio.id
  body = jsonencode({
    properties = {
         packageUri = var.packageUri //This is the sitep.zip or the zip deploy package that Nerdio team needs to provide
     }
  })

  depends_on = [ 
    time_sleep.wait_for_webapp,  # Wait for webapp to be ready
    azurerm_windows_web_app.nerdio,
    azurerm_private_endpoint.key_vault,
    azurerm_private_endpoint.sql,
    azurerm_key_vault_access_policy.nerdio_webapp,
    azurerm_key_vault_secret.sql_connection,
    azurerm_key_vault_certificate.nerdio,  # Add certificate dependency
    azurerm_key_vault_secret.azuread_client_secret  # Add secret dependency
  ]
}

