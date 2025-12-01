data "azuread_client_config" "current" {}
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
 client_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}

#The below is meant to convert the user_principal onto a valid UUID


data "azuread_user" "desktop_admins" {
    for_each = var.desktop_admins
  user_principal_name = each.value
}

data "azuread_user" "desktop_users" {
    for_each = var.desktop_users
  user_principal_name = each.value
}

data "azuread_user" "helpdesk_users" {
    for_each = var.helpdesk_users
  user_principal_name = each.value
}

data "azuread_user" "reviewers" {
    for_each = var.reviewers
  user_principal_name = each.value
}

data "azuread_user" "nerdio_admins" {
    for_each = var.nerdio_admins
  user_principal_name = each.value
}