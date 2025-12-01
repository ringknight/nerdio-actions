# Nerdio Manager for Enterprise

This Terraform module deployes [Nerdio Manager for Enterprise][nme] with the hardening configurations recommended by Nerdio.

# Deployment Process

1. Run this Terraform module.
2. Grant admin consent for the API permissions requested by Nerdio.
3. Download and [deploy the Nerdio application zip file][zipdeploy]. This can be requested from Nerdio support.
4. Log-in to Nerdio as a Nerdio Admin and [complete the setup process as per normal][setup].
5. [Deploy Nerdio licensing from Azure Marketplace][license].

## Resource Group Configuration

The module supports both creating a new resource group or using an existing one:

### Create a new resource group with auto-generated name

```hcl
base_name = "nerdio-prod"
# Resource group will be named: nerdio-prod-rg
```

### Create a new resource group with custom name

```hcl
base_name = "nerdio-prod"
resource_group_name = "my-custom-rg-name"
create_resource_group = true
```

### Use an existing resource group

```hcl
base_name = "nerdio-prod"
resource_group_name = "existing-rg-name"
create_resource_group = false
```

## Deployment permissions

### Azure Permissions

To install Nerdio, the following permissions are required on the Azure Subscription into which the deployment is made:

- Owner
- Key Vault Secrets Officer
- Key Vault Certificates Officer
- Automation Contributor

### Entra ID Permissions

To deploy the Terraform module, the following Entra ID Permissions are required:

- Application Administrator
- Groups Administrator

To grant administrative consent to the API permissions required on the Entra ID application, the following permissions are required:

- Privileged Role Administrator

[license]: https://nmw.zendesk.com/hc/en-us/articles/4731654866199-License-Activation
[nme]: https://getnerdio.com/nerdio-manager-for-enterprise/
[setup]: https://nmw.zendesk.com/hc/en-us/articles/4731671460759-Nerdio-Manager-Installation-Guide#Configur
[zipdeploy]: https://nmw.zendesk.com/hc/en-us/articles/4731650896407-Update-the-Nerdio-Manager-Application
