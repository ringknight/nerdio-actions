resource "azurerm_shared_image_gallery" "nerdio" {
  name                = "${lower(replace(var.base_name, "-", ""))}sig"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  description         = "Images for Virtual Desktops"

  tags = var.tags
}
