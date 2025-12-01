# Terraform Deployment Commands

## Main Infrastructure (without monitoring data sources)
terraform init
terraform apply -var="resource_group_name=rg-NerdioManager1-aue" -auto-approve

## Monitoring Data Sources (optional - apply after main infrastructure)
# These resources have known state sync issues with azurerm provider
# Apply them separately once main infrastructure is deployed:
terraform apply -var="resource_group_name=rg-NerdioManager1-aue" -auto-approve

## Destroy Everything
terraform destroy -var="resource_group_name=rg-NerdioManager1-aue" -auto-approve

## Verify Resources
az resource list --resource-group rg-NerdioManager1-aue --output table
