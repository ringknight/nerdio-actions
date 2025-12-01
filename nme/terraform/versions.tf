terraform {
  required_version = ">= 1.3"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.31"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.36"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10.0"
    }
  }
}
