# Terraform Apply Issue - Log Analytics Data Sources

## Problem
When running `terraform apply` on an empty resource group, you're encountering errors like:
```
Error: a resource with the ID "...dataSources/perfcounter18" already exists - 
to be managed via Terraform this resource needs to be imported into the State.
```

## Root Cause
This is a timing/state synchronization issue with `azurerm_log_analytics_datasource_*` resources:
1. Terraform creates the resources successfully in Azure
2. Due to eventual consistency or API delays, Terraform doesn't immediately recognize them in its state
3. On the same apply run, Terraform tries to create them again and finds they already exist

## Solution Options

### Option 1: Run Apply Multiple Times (Recommended)
Simply run `terraform apply` again. The second run should pick up the existing resources properly:
```bash
terraform apply -var="resource_group_name=rg-NerdioManager1-aue" -auto-approve
```

### Option 2: Use Target Apply
Apply resources in stages:
```bash
# First, create everything except Log Analytics data sources
terraform apply -var="resource_group_name=rg-NerdioManager1-aue" \
  -target=azurerm_log_analytics_workspace.avd

# Then apply the data sources
terraform apply -var="resource_group_name=rg-NerdioManager1-aue"
```

### Option 3: Import After Manual Creation
If resources are stuck, import them:
```bash
terraform import -var="resource_group_name=rg-NerdioManager1-aue" \
  'azurerm_log_analytics_datasource_windows_performance_counter.network_bytes_total' \
  "/subscriptions/8f82cd1b-2c66-4426-8a80-6bd35c5a4586/resourceGroups/rg-NerdioManager1-aue/providers/Microsoft.OperationalInsights/workspaces/nmw-app-law-d2f727bede2d4/dataSources/perfcounter18"
```

## Prevention
This is a known issue with the Azure provider for these specific resource types. 
The best approach is to run apply twice on fresh deployments.
