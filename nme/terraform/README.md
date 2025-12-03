# Nerdio Manager for Enterprise - Terraform Deployment

This Terraform configuration deploys [Nerdio Manager for Enterprise (NME)](https://getnerdio.com/nerdio-manager-for-enterprise/) on Azure with security hardening and best practices recommended by Nerdio.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Resources Deployed](#resources-deployed)
- [Variables and Inputs](#variables-and-inputs)
- [Outputs](#outputs)
- [Deployment Instructions](#deployment-instructions)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Destroying Resources](#destroying-resources)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

## Overview

This Terraform module automates the deployment of Nerdio Manager for Enterprise infrastructure, including:

- Azure Web App hosting the Nerdio application
- SQL Database for data persistence
- Azure Automation Account for runbook execution
- Key Vault for secure credential storage
- Virtual Network with private endpoints for secure connectivity
- Azure AD application and service principal with required permissions
- Monitoring and logging with Application Insights and Log Analytics
- Shared Image Gallery for custom images

## Architecture

The deployment creates a secure, enterprise-ready environment with:

- **Private networking**: All services connected via private endpoints
- **VNet integration**: Web app deployed with virtual network integration
- **Private DNS zones**: For private endpoint resolution
- **Certificate-based authentication**: For automation accounts
- **Role-based access control**: Multiple user roles supported
- **Monitoring**: Application Insights and Log Analytics integration

## Prerequisites

### Required Software

- [Terraform](https://www.terraform.io/downloads.html) >= 1.3
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (authenticated to your Azure subscription)
- Access to Nerdio Manager deployment package (site.zip)

### Azure Permissions

To deploy this infrastructure, you need the following permissions on the target Azure subscription:

- **Owner** role (or combination of Contributor + User Access Administrator)
- **Key Vault Secrets Officer**
- **Key Vault Certificates Officer**
- **Automation Contributor**

### Azure AD (Entra ID) Permissions

The deployment requires these Entra ID roles:

- **Application Administrator** - To create Azure AD applications and service principals
- **Groups Administrator** - To create and manage security groups
- **Privileged Role Administrator** - To grant admin consent for API permissions (post-deployment)

### Azure Providers

This configuration uses the following Terraform providers:

- `hashicorp/azurerm` ~> 3.36
- `hashicorp/azuread` ~> 2.31
- `hashicorp/time` ~> 0.9
- `azure/azapi` ~> 1.10.0

## Resources Deployed

### Core Infrastructure

#### 1. Resource Group (`rg.tf`)
- Creates or uses an existing resource group
- Supports custom naming or auto-generated names

#### 2. Virtual Network (`vnet.tf`)
- Virtual Network with configurable address space
- **Subnets:**
  - `private-endpoints`: For private endpoint connections
  - `appsvc`: For Azure App Service integration (delegated to Microsoft.Web/serverFarms)
- Network Security Group with subnet associations

#### 3. Private DNS Zones (`private-dns.tf`)
- `privatelink.azure-automation.net` - For Automation Account
- `privatelink.vaultcore.azure.net` - For Key Vault
- `privatelink.database.windows.net` - For SQL Server
- `privatelink.azurewebsites.net` - For Web App
- VNet links for all DNS zones

### Application Layer

#### 4. Windows Web App (`main.tf`)
- App Service Plan (configurable SKU, default: B3)
- Windows Web App running .NET 6.0
- System-assigned managed identity
- VNet integration and private endpoint
- Application settings for Nerdio configuration
- MSDeploy extension for package deployment

#### 5. SQL Database (`sql.tf`)
- Azure SQL Server (v12.0)
- SQL Database: "NerdioManager" (configurable SKU, default: S1)
- SQL authentication and Azure AD authentication
- Azure AD admin group for SQL administrators
- Private endpoint for secure access
- Auto-generated strong password (30 characters)

#### 6. Key Vault (`keyvault.tf`)
- Standard SKU Key Vault
- Access policies for:
  - Web App managed identity
  - Nerdio service principal
  - Deployment identity
- Stored secrets:
  - Azure AD client secret
  - SQL connection string
- Certificates for automation accounts
- Private endpoint for secure access
- Configurable public access (default: enabled)

### Automation & Identity

#### 7. Azure Automation Account (`automation.tf`)
- Automation Account (Basic SKU)
- PowerShell modules: AzureAD, AzureRM.Profile
- Automation variables (subscription ID, web app name, resource group)
- Two Run-As accounts:
  - **Automation RunAs**: For general automation
  - **Scripted Action RunAs**: For Nerdio scripted actions
- Self-signed certificates (12-month validity, auto-renewal)
- Private endpoints for webhook and hybrid worker

#### 8. Azure AD Application & Service Principal (`identity.tf`)
- Enterprise application: "Nerdio Manager for Enterprise"
- **App Roles:**
  - Desktop Admin
  - Desktop User
  - Help Desk
  - REST Client
  - Reviewer
  - Nerdio Admin (WvdAdmin)
- **API Permissions:**
  - Microsoft Graph (Application): Organization.Read.All, User.Read.All, Group.Read.All, GroupMember.Read.All
  - Microsoft Graph (Delegated): Multiple permissions including Directory.Read.All, User.Read, Mail.Send
  - Azure Service Management: user_impersonation
- Service principal with certificate authentication
- Auto-rotating password (90-day rotation)
- Contributor role on resource group

#### 9. Role Assignments (`role-assignments.tf`)
- Maps Azure AD users to Nerdio app roles
- Supports bulk user assignment via variables

### Monitoring & Logging

#### 10. Application Insights (`monitoring.tf`)
- Web application monitoring
- Workspace-based Application Insights
- Connected to Log Analytics workspace

#### 11. Log Analytics Workspace (`monitoring.tf`)
- 30-day retention
- PerGB2018 pricing tier
- Log Analytics solutions:
  - Security
  - SecurityCenterFree
  - SQLAdvancedThreatProtection
  - SQLVulnerabilityAssessment

### Storage & Imaging

#### 12. Shared Image Gallery (`sig.tf`)
- Azure Compute Gallery for custom VM images
- Auto-generated name from base_name

## Variables and Inputs

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `base_name` | string | Base name for all resources. Resource-specific suffixes will be appended (e.g., `-app`, `-sql`, `-kv`). |
| `location` | string | Azure region for deployment (e.g., `australiaeast`, `eastus`, `westeurope`). |
| `packageUri` | string | HTTPS URL to the Nerdio Manager deployment package (site.zip). Must be a valid HTTPS URL ending with `.zip`. |
| `vnet_address_space` | list(string) | Address space for the virtual network (e.g., `["10.15.0.0/16"]`). |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `resource_group_name` | string | `""` | Name of the resource group. If empty and `create_resource_group` is true, will be `{base_name}-rg`. |
| `create_resource_group` | bool | `true` | Whether to create a new resource group (`true`) or use an existing one (`false`). |
| `allow_public_access` | bool | `true` | Enable public access to services. Set to `false` for fully private deployment. |
| `webapp_sku` | string | `"B3"` | Azure App Service Plan SKU (e.g., `B1`, `B3`, `S1`, `P1v2`). |
| `sql_sku` | string | `"S1"` | SQL Database SKU (e.g., `Basic`, `S0`, `S1`, `P1`). |
| `allow_delegated_write_permissions` | bool | `true` | Grant delegated Azure AD write permissions to the Nerdio application. |
| `nerdio_tag_prefix` | string | `"NMW"` | Prefix for Nerdio-specific Azure tags. |
| `desktop_admins` | map(string) | `{}` | Map of users for Desktop Admin role (key = identifier, value = UPN). |
| `desktop_users` | map(string) | `{}` | Map of users for Desktop User role (key = identifier, value = UPN). |
| `helpdesk_users` | map(string) | `{}` | Map of users for Help Desk role (key = identifier, value = UPN). |
| `reviewers` | map(string) | `{}` | Map of users for Reviewer role (key = identifier, value = UPN). |
| `nerdio_admins` | map(string) | `{}` | Map of users for Nerdio Admin role (key = identifier, value = UPN). |
| `tags` | map(string) | `{}` | Common tags to apply to all resources. |

### User Role Mapping Example

```hcl
desktop_admins = {
  "admin1" = "john.doe@contoso.com"
  "admin2" = "jane.smith@contoso.com"
}

nerdio_admins = {
  "superadmin" = "admin@contoso.com"
}
```

## Outputs

The module provides the following outputs:

| Output | Description |
|--------|-------------|
| `webapp` | Web App details (id, name, resource_group_name, default_hostname) |
| `automation_account` | Automation Account details (id, name, resource_group_name, dsc_server_endpoint, hybrid_service_url) |
| `key_vault` | Key Vault details (id, name, resource_group_name, vault_uri) |
| `shared_image_gallery` | Shared Image Gallery details (id, name, resource_group_name, unique_name) |
| `sql_server` | SQL Server details (id, name, resource_group_name, fqdn) |
| `virtual_network` | Virtual Network details (id, name, resource_group_name) |

## Deployment Instructions

### Step 1: Authenticate to Azure

```bash
# Login to Azure
az login

# Set the subscription (if you have multiple)
az account set --subscription "Your-Subscription-Name-or-ID"

# Verify the selected subscription
az account show
```

### Step 2: Prepare Configuration Files

1. **Create a `terraform.tfvars` file** with your specific values:

```hcl
# Required variables
base_name          = "nerdio-prod"
location           = "australiaeast"
packageUri         = "https://yourstorageaccount.blob.core.windows.net/container/site.zip?<SAS-token>"
vnet_address_space = ["10.15.0.0/16"]

# Optional variables
allow_public_access               = true
webapp_sku                        = "B3"
sql_sku                           = "S1"
allow_delegated_write_permissions = true

# Resource group configuration (choose one)
# Option 1: Create new with auto-generated name
create_resource_group = true

# Option 2: Create new with custom name
# resource_group_name   = "rg-nerdio-prod"
# create_resource_group = true

# Option 3: Use existing resource group
# resource_group_name   = "rg-existing-nerdio"
# create_resource_group = false

# User role assignments
nerdio_admins = {
  "admin1" = "admin@yourdomain.com"
}

desktop_admins = {
  "dadmin1" = "desktop.admin@yourdomain.com"
}

# Tags
tags = {
  Environment = "Production"
  Project     = "Nerdio Manager"
  CostCenter  = "IT"
}
```

2. **Obtain the Nerdio deployment package**:
   - Contact Nerdio support to obtain the `site.zip` file
   - Upload to Azure Blob Storage
   - Generate a SAS token with read permissions
   - Use the full URL with SAS token for `packageUri` variable

### Step 3: Initialize Terraform

```bash
# Navigate to the terraform directory
cd /path/to/nerdio/nme/terraform

# Initialize Terraform (downloads providers)
terraform init
```

### Step 4: Plan the Deployment

```bash
# Review what will be created
terraform plan

# Save the plan to a file (optional but recommended)
terraform plan -out=tfplan
```

Review the output carefully to ensure all resources are correct.

### Step 5: Apply the Configuration

```bash
# Deploy the infrastructure
terraform apply

# Or use the saved plan
terraform apply tfplan
```

When prompted, type `yes` to confirm the deployment.

The deployment typically takes **10-15 minutes** to complete.

### Step 6: Capture Outputs

```bash
# Display all outputs
terraform output

# Get specific output values
terraform output -json > outputs.json
```

## Post-Deployment Configuration

After Terraform completes successfully, perform these additional steps:

### 1. Grant Admin Consent for API Permissions

The Nerdio Azure AD application requires admin consent for Microsoft Graph API permissions:

1. Navigate to the [Azure Portal](https://portal.azure.com)
2. Go to **Azure Active Directory** > **App registrations**
3. Find the application: "Nerdio Manager for Enterprise - {base_name}"
4. Click **API permissions**
5. Click **Grant admin consent for {your-tenant}**
6. Confirm by clicking **Yes**

**Required Permission**: Privileged Role Administrator

### 2. Verify Application Deployment

The Terraform configuration automatically deploys the Nerdio application package via MSDeploy. Verify the deployment:

1. Navigate to the Web App in Azure Portal
2. Go to **Deployment Center** > **Logs**
3. Verify the MSDeploy deployment succeeded
4. Browse to the Web App URL (found in `terraform output`)

### 3. Initial Nerdio Setup

1. Navigate to the Nerdio Manager web application: `https://{base_name}-app.azurewebsites.net`
2. Sign in with a user assigned the **Nerdio Admin** role
3. Complete the initial setup wizard:
   - Configure organization settings
   - Set up Azure subscriptions
   - Configure host pool defaults
   - Set up autoscaling policies
4. Follow [Nerdio's installation guide](https://nmw.zendesk.com/hc/en-us/articles/4731671460759-Nerdio-Manager-Installation-Guide)

### 4. Deploy Nerdio Licensing

1. Navigate to [Azure Marketplace](https://azuremarketplace.microsoft.com/)
2. Search for "Nerdio Manager for Enterprise"
3. Deploy the licensing solution
4. Follow [Nerdio's license activation guide](https://nmw.zendesk.com/hc/en-us/articles/4731654866199-License-Activation)

### 5. Configure Network Security (Optional)

If deploying in a fully private environment:

1. Set `allow_public_access = false` in `terraform.tfvars`
2. Configure Azure Bastion or VPN for administrative access
3. Update NSG rules as needed (`vnet.nsg-rules.tf`)
4. Re-run `terraform apply`

## Destroying Resources

To completely remove all resources created by this Terraform configuration:

### Important Warnings

⚠️ **This action is destructive and irreversible!**
- All data in the SQL database will be deleted
- All secrets in Key Vault will be deleted
- All automation runbooks will be removed
- User assignments and role configurations will be lost

### Pre-Destruction Checklist

Before destroying resources, ensure you have:

- [ ] Backed up the SQL database
- [ ] Exported any important secrets from Key Vault
- [ ] Documented automation runbooks
- [ ] Notified all Nerdio users
- [ ] Removed any dependencies on these resources
- [ ] Backed up custom images from Shared Image Gallery

### Destruction Steps

#### Option 1: Destroy Everything

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy
```

When prompted, review the list of resources to be destroyed and type `yes` to confirm.

#### Option 2: Destroy Specific Resources

```bash
# Destroy a specific resource
terraform destroy -target=azurerm_windows_web_app.nerdio

# Destroy multiple specific resources
terraform destroy \
  -target=azurerm_windows_web_app.nerdio \
  -target=azurerm_service_plan.nerdio
```

#### Option 3: Remove from State Without Destroying

If you want to keep resources but remove them from Terraform management:

```bash
# Remove a resource from state (does not delete it)
terraform state rm azurerm_windows_web_app.nerdio

# List all resources in state
terraform state list

# Remove multiple resources
terraform state rm 'azurerm_private_endpoint.webapp' 'azurerm_private_endpoint.sql'
```

### Handling Destroy Failures

If `terraform destroy` fails due to dependencies:

1. **Check for explicit dependencies in `depends_on` blocks**
2. **Try destroying in phases**:

```bash
# Phase 1: Remove application layer
terraform destroy \
  -target=azapi_resource.msdeploy \
  -target=azurerm_windows_web_app.nerdio

# Phase 2: Remove private endpoints
terraform destroy -target=azurerm_private_endpoint.webapp

# Phase 3: Complete destruction
terraform destroy
```

3. **Manually delete stuck resources**:
   - Private endpoints often need manual deletion
   - Key Vault may require purge protection override
   - Check Azure Portal for resource locks

4. **Force destroy with refresh skip** (use with caution):

```bash
terraform destroy -refresh=false
```

### Post-Destruction Cleanup

After running `terraform destroy`, some resources may require manual cleanup:

#### 1. Azure AD Application
The Azure AD application may not be fully deleted:

```bash
# List all Nerdio-related applications
az ad app list --query "[?contains(displayName, 'Nerdio')].{Name:displayName, AppId:appId}" -o table

# Delete the application
az ad app delete --id <app-id>

# Delete service principal
az ad sp delete --id <sp-id>
```

#### 2. Key Vault Soft-Delete
Key Vaults with purge protection may be soft-deleted:

```bash
# List soft-deleted Key Vaults
az keyvault list-deleted --resource-type vault

# Purge the Key Vault permanently
az keyvault purge --name <keyvault-name> --location <location>
```

#### 3. Private DNS Zones
Private DNS zones may have residual records:

```bash
# Delete private DNS zone
az network private-dns zone delete --name <zone-name> --resource-group <rg-name>
```

#### 4. Log Analytics Workspace
If workspace is set to permanent deletion:

```bash
# Force delete workspace
az monitor log-analytics workspace delete \
  --resource-group <rg-name> \
  --workspace-name <workspace-name> \
  --force true
```

#### 5. Resource Group (if created by Terraform)
If `create_resource_group = true`, the resource group itself will be destroyed. Verify it's gone:

```bash
# List resource groups
az group list --query "[?contains(name, 'nerdio')]" -o table

# Force delete if needed
az group delete --name <rg-name> --yes --no-wait
```

### Terraform State Cleanup

After destruction, clean up the Terraform state:

```bash
# Verify state is empty
terraform state list

# Remove state files (if no longer needed)
rm -f terraform.tfstate
rm -f terraform.tfstate.backup
rm -f tfplan
```

### Destroy Timeouts

Some resources take longer to destroy. Common timeout errors:

```bash
# Increase timeout by setting environment variable
export TF_CLI_ARGS_destroy="-parallelism=1"

# Or edit the resource with a custom timeout (in .tf files)
resource "azurerm_private_endpoint" "example" {
  # ... other config ...
  
  timeouts {
    delete = "30m"  # Increase from default
  }
}
```

## Security Considerations

### Network Security

- **Private Endpoints**: All Azure PaaS services are accessed via private endpoints
- **VNet Integration**: Web App integrates with VNet for secure outbound connectivity
- **NSG Rules**: Network Security Group controls traffic flow
- **Private DNS**: DNS resolution for private endpoints via private DNS zones

### Identity & Access

- **Managed Identity**: Web App uses system-assigned managed identity
- **Certificate Authentication**: Automation accounts use certificate-based authentication
- **Password Rotation**: Service principal passwords auto-rotate every 90 days
- **RBAC**: Role-based access control with multiple permission levels
- **Least Privilege**: Service principals have minimal required permissions

### Secrets Management

- **Key Vault**: All secrets stored in Azure Key Vault
- **Access Policies**: Scoped access policies per service
- **No Hardcoded Secrets**: SQL password auto-generated with 30-character complexity
- **Connection Strings**: Stored securely in Key Vault, referenced by Web App

### Compliance & Monitoring

- **Application Insights**: Application performance monitoring
- **Log Analytics**: Centralized logging and analysis
- **Azure Defender**: Security solutions enabled
- **SQL Threat Protection**: Advanced threat detection for SQL
- **Vulnerability Assessment**: SQL vulnerability scanning enabled

### Hardening Recommendations

1. **Disable Public Access**: Set `allow_public_access = false` after initial setup
2. **Enable Azure Firewall**: For advanced network filtering
3. **Implement Azure Bastion**: For secure VM access
4. **Configure NSG Rules**: Customize rules in `vnet.nsg-rules.tf`
5. **Enable Azure Policy**: For compliance and governance
6. **Implement Azure AD Conditional Access**: Restrict access by location/device
7. **Enable Multi-Factor Authentication**: For all admin accounts

## Troubleshooting

### Common Issues

#### Issue: MSDeploy Fails During Deployment

**Symptoms**: Terraform completes but Web App shows errors

**Solutions**:
1. Verify `packageUri` is accessible (test the URL with SAS token)
2. Check Web App logs: Azure Portal > Web App > Log Stream
3. Ensure the zip file is a valid Nerdio deployment package
4. Try manual deployment: Azure Portal > Web App > Deployment Center

#### Issue: Key Vault Access Denied

**Symptoms**: Terraform fails with Key Vault permission errors

**Solutions**:
1. Verify you have Key Vault Secrets Officer and Certificates Officer roles
2. Check if Key Vault firewall is blocking your IP
3. Ensure access policies are correctly configured
4. Wait 5-10 minutes after role assignment (permission propagation delay)

#### Issue: SQL Connection Failures

**Symptoms**: Web App cannot connect to SQL database

**Solutions**:
1. Verify private endpoint is properly configured
2. Check private DNS zone resolution
3. Ensure Web App has VNet integration
4. Verify SQL firewall rules
5. Check connection string in Key Vault

#### Issue: Azure AD Admin Consent Required

**Symptoms**: Users cannot sign in to Nerdio

**Solutions**:
1. Navigate to Azure AD > App registrations
2. Select the Nerdio application
3. Go to API permissions
4. Click "Grant admin consent for {tenant}"
5. Requires Privileged Role Administrator role

#### Issue: Terraform State Lock

**Symptoms**: "Error acquiring the state lock"

**Solutions**:
```bash
# If using remote state (e.g., Azure Storage)
terraform force-unlock <lock-id>

# Or delete the lock blob manually in Azure Storage
```

#### Issue: Provider Version Conflicts

**Symptoms**: Provider version errors during init

**Solutions**:
```bash
# Remove lock file and reinitialize
rm .terraform.lock.hcl
terraform init -upgrade
```

### Debugging Tips

1. **Enable Terraform Debug Logging**:
   ```bash
   export TF_LOG=DEBUG
   terraform apply
   ```

2. **Check Resource Dependencies**:
   ```bash
   terraform graph | dot -Tsvg > graph.svg
   ```

3. **Validate Configuration**:
   ```bash
   terraform validate
   terraform fmt -check
   ```

4. **Inspect State**:
   ```bash
   terraform show
   terraform state list
   terraform state show <resource>
   ```

5. **Check Azure Activity Logs**:
   - Azure Portal > Monitor > Activity Log
   - Filter by time range and operation

## File Structure

```
nme/terraform/
├── README.md                           # This file
├── main.tf                             # Web App and App Service Plan
├── variables.tf                        # Input variable definitions
├── versions.tf                         # Terraform and provider versions
├── providers.tf                        # Provider configurations
├── output.tf                           # Output definitions
├── data.tf                             # Data source queries
├── rg.tf                               # Resource group configuration
├── vnet.tf                             # Virtual network and subnets
├── vnet.nsg-rules.tf                   # Network security group rules
├── sql.tf                              # SQL Server and database
├── keyvault.tf                         # Key Vault and secrets
├── automation.tf                       # Automation account and runbooks
├── identity.tf                         # Azure AD app and service principal
├── sig.tf                              # Shared Image Gallery
├── private-dns.tf                      # Private DNS zones
├── monitoring.tf                       # Application Insights
├── monitoring.log-analytics.tf         # Log Analytics workspace
├── monitoring.locals.tf                # Monitoring local variables
├── monitoring.azure-monitor.tf         # Azure Monitor configuration
├── role-assignments.tf                 # User role assignments
├── terraform.tfvars                    # Variable values (customize this)
├── .terraform.lock.hcl                 # Provider version lock file
└── _resources/
    └── nerdio.png                      # Nerdio logo for Azure AD app
```

## Support and Resources

### Official Documentation

- [Nerdio Manager Documentation](https://nmw.zendesk.com/hc/en-us)
- [Nerdio Installation Guide](https://nmw.zendesk.com/hc/en-us/articles/4731671460759-Nerdio-Manager-Installation-Guide)
- [Advanced Installation Guide](https://nmw.zendesk.com/hc/en-us/articles/4731655590679-Advanced-Installation-Create-Azure-AD-Application)
- [License Activation](https://nmw.zendesk.com/hc/en-us/articles/4731654866199-License-Activation)
- [Update Nerdio Application](https://nmw.zendesk.com/hc/en-us/articles/4731650896407-Update-the-Nerdio-Manager-Application)

### Terraform Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Azure AD Provider Documentation](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs)

### Getting Help

- **Nerdio Support**: [https://getnerdio.com/support/](https://getnerdio.com/support/)
- **Terraform Issues**: [https://github.com/hashicorp/terraform/issues](https://github.com/hashicorp/terraform/issues)
- **Azure Support**: [https://azure.microsoft.com/support/](https://azure.microsoft.com/support/)

## License

This Terraform configuration is provided as-is. Nerdio Manager for Enterprise requires a valid license from Nerdio.

## Contributing

For improvements or bug fixes to this Terraform configuration, please submit issues or pull requests to the repository maintainer.

---

**Last Updated**: December 2025  
**Terraform Version**: >= 1.3  
**Azure Provider Version**: ~> 3.36
