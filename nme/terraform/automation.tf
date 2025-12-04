locals {
  aa_modules = {
    "AzureAD"         = "https://www.powershellgallery.com/api/v2/package/AzureAD/2.0.2.76"
    "AzureRM.Profile" = "https://www.powershellgallery.com/api/v2/package/AzureRM.profile/5.8.3"
  }

  aa_runbooks = {
  }

  aa_variables = {
    subscriptionId = {
      type        = "string"
      description = "Azure Subscription Id"
      value       = data.azurerm_subscription.current.subscription_id
      encrypted   = false
    }
    webAppName = {
      type        = "string"
      description = "Web App Name"
      value       = azurerm_windows_web_app.nerdio.name
      encrypted   = false
    }
    resourceGroupName = {
      type        = "string"
      description = "Resource group"
      value       = local.resource_group_name
      encrypted   = false
    }
  }
}

resource "azurerm_automation_account" "nerdio" {
  name                = "${lower(var.base_name)}-aa"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  sku_name            = "Basic"

  tags = var.tags
}

resource "azurerm_automation_module" "nerdio" {
  for_each = local.aa_modules

  name                    = each.key
  automation_account_name = azurerm_automation_account.nerdio.name
  resource_group_name     = azurerm_automation_account.nerdio.resource_group_name

  module_link {
    uri = each.value
  }
}

resource "azurerm_automation_runbook" "nerdio" {
  for_each = local.aa_runbooks

  name                    = each.key
  automation_account_name = azurerm_automation_account.nerdio.name
  resource_group_name     = azurerm_automation_account.nerdio.resource_group_name
  location                = azurerm_automation_account.nerdio.location
  log_verbose             = false
  log_progress            = true
  description             = each.value.description
  runbook_type            = each.value.type

  publish_content_link {
    uri     = each.value.uri
    version = each.value.version
  }
}

resource "azurerm_automation_variable_string" "nerdio" {
  for_each = { for k, v in local.aa_variables :
    k => v
    if v.type == "string"
  }

  name                    = each.key
  automation_account_name = azurerm_automation_account.nerdio.name
  resource_group_name     = azurerm_automation_account.nerdio.resource_group_name
  value                   = each.value.value
  description             = each.value.description
  encrypted               = each.value.encrypted
}

# Automation Run-As Account
resource "azuread_application" "automation_runas" {
  display_name = "Nerdio Manager Automation"

  feature_tags {
    hide = true
  }
}

resource "azuread_service_principal" "automation_runas" {
  client_id                    = azuread_application.automation_runas.client_id
  app_role_assignment_required = true

  feature_tags {
    hide = true
  }
}

# Create certificates for run as account
resource "azurerm_key_vault_certificate" "nerdio" {
  for_each = toset(["automation", "scripted-action"])

  name         = "${lower(var.nerdio_tag_prefix)}-${each.key}-cert"
  key_vault_id = azurerm_key_vault.nerdio.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = [
        "1.3.6.1.5.5.7.3.1", # Server Authentication
        "1.3.6.1.5.5.7.3.2", # Client Authentication
      ]

      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]

      subject            = "CN=${lower(var.nerdio_tag_prefix)}-${each.key}-cert"
      validity_in_months = 12
    }
  }

  depends_on = [ azurerm_key_vault_access_policy.nerdio_WVDAdmin ]
}

# Since we need the private key, we have to get the secret
data "azurerm_key_vault_secret" "nerdio_certificate" {
  for_each = azurerm_key_vault_certificate.nerdio

  name         = each.value.name
  key_vault_id = each.value.key_vault_id
}

resource "azurerm_automation_certificate" "nerdio" {
  for_each = data.azurerm_key_vault_secret.nerdio_certificate

  name = coalesce(
    each.key == "automation" ? "AzureRunAsCertificate" : null,
    each.key == "scripted-action" ? "ScriptedActionRunAsCert" : null,
  )
  automation_account_name = azurerm_automation_account.nerdio.name
  resource_group_name     = azurerm_automation_account.nerdio.resource_group_name
  base64                  = each.value.value
  exportable              = true
}

resource "azurerm_automation_connection_certificate" "runas" {
  for_each = azurerm_automation_certificate.nerdio

  name                        = each.value.name
  automation_account_name     = azurerm_automation_account.nerdio.name
  resource_group_name         = azurerm_automation_account.nerdio.resource_group_name
  automation_certificate_name = each.value.name
  subscription_id             = data.azurerm_subscription.current.subscription_id
}

resource "azuread_service_principal_certificate" "automation_runas" {
  service_principal_id = azuread_service_principal.automation_runas.id
  encoding             = "hex"
  type                 = "AsymmetricX509Cert"
  value                = azurerm_key_vault_certificate.nerdio["automation"].certificate_data
  start_date           = azurerm_key_vault_certificate.nerdio["automation"].certificate_attribute[0].not_before
  end_date             = azurerm_key_vault_certificate.nerdio["automation"].certificate_attribute[0].expires
}

resource "azuread_service_principal_certificate" "scripted_action" {
  service_principal_id = azuread_service_principal.nerdio_manager.id
  encoding             = "hex"
  type                 = "AsymmetricX509Cert"
  value                = azurerm_key_vault_certificate.nerdio["scripted-action"].certificate_data
  start_date           = azurerm_key_vault_certificate.nerdio["scripted-action"].certificate_attribute[0].not_before
  end_date             = azurerm_key_vault_certificate.nerdio["scripted-action"].certificate_attribute[0].expires
}

# Private Endpoint
resource "azurerm_private_endpoint" "automation_webhook" {
  name                = "${azurerm_automation_account.nerdio.name}-webhook-ple"
  resource_group_name = azurerm_automation_account.nerdio.resource_group_name
  location            = azurerm_automation_account.nerdio.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_dns_zone_group {
    name = azurerm_automation_account.nerdio.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.private_link["automation"].id
    ]
  }

  private_service_connection {
    name                           = "Nerdio"
    private_connection_resource_id = azurerm_automation_account.nerdio.id
    is_manual_connection           = false
    subresource_names              = ["Webhook"]
  }

  depends_on = [
    azapi_resource.msdeploy,
    azurerm_key_vault_access_policy.nerdio_service_principal,
    azurerm_key_vault_access_policy.nerdio_webapp,
    azurerm_key_vault_certificate.nerdio,
    azurerm_key_vault_secret.azuread_client_secret,
    azurerm_key_vault_secret.sql_connection
  ]

  tags = var.tags
}

resource "azurerm_private_endpoint" "automation_worker" {
  name                = "${azurerm_automation_account.nerdio.name}-worker-ple"
  resource_group_name = azurerm_automation_account.nerdio.resource_group_name
  location            = azurerm_automation_account.nerdio.location
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_dns_zone_group {
    name = azurerm_automation_account.nerdio.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.private_link["automation"].id
    ]
  }

  private_service_connection {
    name                           = "Nerdio"
    private_connection_resource_id = azurerm_automation_account.nerdio.id
    is_manual_connection           = false
    subresource_names              = ["DSCAndHybridWorker"]
  }

  tags = var.tags
}
