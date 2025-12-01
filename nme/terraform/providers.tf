

provider "azurerm" {
  
  storage_use_azuread = true
  features {
    application_insights {
      disable_generated_rule = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

