resource "azuread_app_role_assignment" "desktop_admins" {
  for_each = data.azuread_user.desktop_admins
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.nerdio_manager.object_id
  app_role_id         = "ed0cdef0-4267-4470-bfff-5e0b6944f9e4"
}

resource "azuread_app_role_assignment" "desktop_users" {
  for_each = data.azuread_user.desktop_users
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.nerdio_manager.object_id
  app_role_id         = "e856de81-1e53-486a-8668-7d564866ae39"
}


resource "azuread_app_role_assignment" "help_desk" {
  for_each = data.azuread_user.helpdesk_users
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.nerdio_manager.object_id
  app_role_id         = "a94e83da-b314-4232-b8c8-94508c5ed533"
}


resource "azuread_app_role_assignment" "reviewers" {
  for_each = data.azuread_user.reviewers
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.nerdio_manager.object_id
  app_role_id         =  "0a1b7425-f55a-44a6-9caa-b9a5cc9448da"
}

resource "azuread_app_role_assignment" "wvd_admin" {
 for_each = data.azuread_user.nerdio_admins
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.nerdio_manager.object_id
  app_role_id         = "d1c2ade8-98f8-45fd-aa4a-6d06b947c66f"
}
