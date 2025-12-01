@description('Location for all resources')
param location string = resourceGroup().location

@description('Prefix for Azure Tags')
param azureTagPrefix string = 'NMW'

@description('The SKU of App Service Plan')
param appServicePlanSkuName string = 'B3'

@description('The database collation')
param sqlCollation string = 'SQL_Latin1_General_CP1_CI_AS'
param databaseMaxSize int = 268435456000
param databaseTier string = 'Standard'
param databaseSkuName string = 'S1'
param automationRoleAssignmentName string = guid(subscription().subscriptionId, resourceGroup().id, 'automationRoleAssignment')
param tagsByResource object = {}

@description('Specifies whether Private Endpoints will be configured')
param configurePrivateEndpoints bool = false

@description('Name of the Virtual Network for private endpoints')
param privateEndpointsVnetName string = 'nmw-private-vnet'

@description('CIDR block for the Virtual Network for private endpoints')
param privateEndpointsVnetCidr string = '10.200.0.0/16'

@description('Name of the Subnet for private endpoints')
param privateEndpointsSubnetName string = 'nmw-privateendpoints-subnet'

@description('CIDR block for the Subnet for private endpoints')
param privateEndpointsSubnetCidr string = '10.200.1.0/24'

@description('Name of the Subnet for the application')
param appSubnetName string = 'nmw-app-subnet'

@description('CIDR block for the Subnet for the application')
param appSubnetCidr string = '10.200.2.0/27'

@description('Specifies whether the Web App should be private or public')
param privateWebApp bool = false

@description('Prefix to be used for resource names with a default value')
@minLength(2)
param appName string = 'nmw-app'

@description('Web App resource name. Leave the field blank to use the default value')
param _webAppPortalName string = ''

@description('App Service Plan resource name. Leave the field blank to use the default value')
param _appServicePlanName string = ''

@description('SQL server resource name. Leave the field blank to use the default value')
param _sqlServerName string = ''

@description('SQL database resource name. Leave the field blank to use the default value')
param _databaseName string = ''

@description('Key Vault resource name. Leave the field blank to use the default value')
param _keyVaultName string = ''

@description('Application Insights resource name. Leave the field blank to use the default value')
param _appInsightsName string = ''

@description('Automation Account resource name that will be used to update Nerdio Manager for Enterprise application. Leave the field blank to use the default value')
param _automationAccountName string = ''

@description('Log Analytics Workspace resource name that will be used for session hosts monitoring. Leave the field blank to use the default value')
param _lawName string = ''

@description('Log Analytics Workspace resource name that will be used for Application Insights data. Leave the field blank to use the default value')
param _logsLawName string = ''

@description('Automation Account resource name that will be used to run Scripted Actions. Leave the field blank to use the default value')
param _scriptedActionAccountName string = ''

@description('Storage Account resource name that will be used to store Data Protection Keys. Leave the field blank to use the default value')
param _dataProtectionStorageAccountName string = ''

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation. When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param _artifactsLocationSasToken string = ''

var uniqueStr = uniqueString(subscription().id, resourceGroup().id)
var webAppPortalName = (empty(_webAppPortalName) ? '${appName}-${uniqueStr}' : _webAppPortalName)
var appServicePlanName = (empty(_appServicePlanName) ? '${appName}-plan-${uniqueStr}' : _appServicePlanName)
var sqlServerName = (empty(_sqlServerName) ? '${appName}-sql-${uniqueStr}' : _sqlServerName)
var databaseName = (empty(_databaseName) ? '${appName}-db' : _databaseName)
var keyVaultName = (empty(_keyVaultName) ? '${appName}-kv-${uniqueStr}' : _keyVaultName)
var appInsightsName = (empty(_appInsightsName) ? '${appName}-insights-${uniqueStr}' : _appInsightsName)
var automationAccountName = (empty(_automationAccountName)
  ? '${appName}-automation-${uniqueStr}'
  : _automationAccountName)
var contributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b24988ac-6180-42a0-ab88-20f7382dd24c'
)
var lawName = (empty(_lawName) ? '${appName}-law-${uniqueStr}' : _lawName)
var logsLawName = (empty(_logsLawName) ? '${appName}-law-insights-${uniqueStr}' : _logsLawName)
var dceName = 'dce-${lawName}'
var dcrName = 'microsoft-avdi-${lawName}'
var sqlServerSuffix = environment().suffixes.sqlServerHostname
var microsoftLoginUri = environment().authentication.loginEndpoint
var keyvaultSuffix = environment().suffixes.keyvaultDns
var storageSuffix = environment().suffixes.storage
var scriptedActionAccountName = (empty(_scriptedActionAccountName)
  ? '${appName}-scripted-actions-${uniqueStr}'
  : _scriptedActionAccountName)
var dataProtectionKeyName = 'DataProtection-${uniqueStr}'
var dataProtectionKeyUri = uri('https://${keyVaultName}${keyvaultSuffix}', 'keys/${dataProtectionKeyName}')
var dataProtectionStorageAccountName = (empty(_dataProtectionStorageAccountName)
  ? 'dps${uniqueStr}'
  : _dataProtectionStorageAccountName)
var dataProtectionStorageBlobContainer = 'dataprotectionkeys'
var dataProtectionStorageContainerSasProperties = {
  canonicalizedResource: '/blob/${dataProtectionStorageAccountName}/${dataProtectionStorageBlobContainer}'
  signedResource: 'c'
  signedPermission: 'rcw'
  signedExpiry: '2050-01-01T00:00:00Z'
  signedProtocol: 'https'
}
var blobLeaseContainer = 'locks'
var blobLeaseContainerSasProperties = {
  canonicalizedResource: '/blob/${dataProtectionStorageAccountName}/${blobLeaseContainer}'
  signedResource: 'c'
  signedPermission: 'rcw'
  signedExpiry: '2050-01-01T00:00:00Z'
  signedProtocol: 'https'
}
var automation = {
  runbooks: [
    {
      name: 'nmwUpdateRunAs'
      url: uri(_artifactsLocation, 'scripts/nmw-update-run-as.ps1${_artifactsLocationSasToken}')
      version: '1.0.0.0'
      type: 'PowerShell'
      description: 'Update using automation Run As account'
    }
  ]
}
var privateDnsZoneNames = {
  AppService: {
    AzureCloud: 'privatelink.azurewebsites.net'
    AzureUSGovernment: 'privatelink.azurewebsites.us'
    AzureChinaCloud: 'privatelink.chinacloudsites.cn'
  }
  KeyVault: {
    AzureCloud: 'privatelink.vaultcore.azure.net'
    AzureUSGovernment: 'privatelink.vaultcore.usgovcloudapi.net'
    AzureChinaCloud: 'privatelink.vaultcore.azure.cn'
  }
  Automation: {
    AzureCloud: 'privatelink.azure-automation.net'
    AzureUSGovernment: 'privatelink.azure-automation.us'
    AzureChinaCloud: 'privatelink.azure-automation.cn'
  }
}
var sqlPrivateDnsZoneName = 'privatelink${environment().suffixes.sqlServerHostname}'
var appServicePrivateDnsZoneName = privateDnsZoneNames.AppService[environment().name]
var keyVaultPrivateDnsZoneName = privateDnsZoneNames.KeyVault[environment().name]
var blobPrivateDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'
var filePrivateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'
var automationPrivateDnsZoneName = privateDnsZoneNames.Automation[environment().name]

module pid_8c1c30c0_3e0a_4655_9e05_51dea63a0e32_partnercenter './nested_pid_8c1c30c0_3e0a_4655_9e05_51dea63a0e32_partnercenter.bicep' = {
  name: 'pid-8c1c30c0-3e0a-4655-9e05-51dea63a0e32-partnercenter'
  params: {}
}

resource logsLaw 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logsLawName
  location: location
  tags: (tagsByResource[?'Microsoft.OperationalInsights/workspaces'] ?? json('{}'))
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: union(
    json('{"displayName":"AppInsightsComponent"}'),
    (tagsByResource[?'Microsoft.Insights/components'] ?? json('{}'))
  )
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logsLaw.id
  }
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  tags: union(json('{"displayName":"SqlServer"}'), (tagsByResource[?'Microsoft.Sql/servers'] ?? json('{}')))
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: (configurePrivateEndpoints ? 'Disabled' : 'Enabled')
  }
}

resource sqlServerName_database 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: union(json('{"displayName":"Database"}'), (tagsByResource[?'Microsoft.Sql/servers/databases'] ?? json('{}')))
  properties: {
    collation: sqlCollation
    maxSizeBytes: databaseMaxSize
  }
  sku: {
    name: databaseSkuName
    tier: databaseTier
  }
}

resource sqlServerName_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2021-11-01' = if (!configurePrivateEndpoints) {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  kind: 'app'
  location: location
  properties: {}
  sku: {
    name: appServicePlanSkuName
  }
  tags: (tagsByResource[?'Microsoft.Web/serverfarms'] ?? json('{}'))
}

resource webAppPortal 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppPortalName
  kind: 'app'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: (tagsByResource[?'Microsoft.Web/sites'] ?? json('{}'))
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    publicNetworkAccess: ((configurePrivateEndpoints && privateWebApp) ? 'Disabled' : 'Enabled')
    virtualNetworkSubnetId: (configurePrivateEndpoints ? resourceId('Microsoft.Network/virtualNetworks/subnets', privateEndpointsVnetName, appSubnetName) : null)
    siteConfig: {
      alwaysOn: true
      http20Enabled: true
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.3'
      netFrameworkVersion: 'v8.0'
      appSettings: [
        {
          name: 'AzureAd:Instance'
          value: microsoftLoginUri
        }
        {
          name: 'Deployment:AzureType'
          value: environment().name
        }
        {
          name: 'Deployment:Region'
          value: location
        }
        {
          name: 'Deployment:KeyVaultName'
          value: keyVaultName
        }
        {
          name: 'Deployment:SubscriptionId'
          value: subscription().subscriptionId
        }
        {
          name: 'Deployment:SubscriptionDisplayName'
          value: subscription().displayName
        }
        {
          name: 'Deployment:TenantId'
          value: subscription().tenantId
        }
        {
          name: 'Deployment:ResourceGroupName'
          value: resourceGroup().name
        }
        {
          name: 'Deployment:WebAppName'
          value: webAppPortalName
        }
        {
          name: 'Deployment:AutomationAccountName'
          value: automationAccountName
        }
        {
          name: 'Deployment:AutomationAccountAzInstalled'
          value: 'True'
        }
        {
          name: 'Deployment:AutomationEnabled'
          value: 'True'
        }
        {
          name: 'Deployment:AzureTagPrefix'
          value: azureTagPrefix
        }
        {
          name: 'Deployment:UpdaterRunbookRunAs'
          value: 'nmwUpdateRunAs'
        }
        {
          name: 'Deployment:LogAnalyticsWorkspace'
          value: law.id
        }
        {
          name: 'Deployment:ScriptedActionAccount'
          value: scriptedActionAccount.id
        }
        {
          name: 'ApplicationInsights:InstrumentationKey'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsights:ConnectionString'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'DataProtection:Storage:Type'
          value: 'AzureBlobStorage'
        }
        {
          name: 'DataProtection:Protect:KeyIdentifier'
          value: dataProtectionKeyUri
        }
      ]
    }
  }
}

resource webAppPortalName_MSDeploy 'Microsoft.Web/sites/extensions@2023-01-01' = {
  parent: webAppPortal
  name: 'MSDeploy'
  properties: {
    packageUri: uri(_artifactsLocation, 'web-app/app.zip${_artifactsLocationSasToken}')
  }
  dependsOn: [
    webAppPortalName_pe
  ]
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: (tagsByResource[?'Microsoft.KeyVault/vaults'] ?? json('{}'))
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: webAppPortal.identity.tenantId
    accessPolicies: [
      {
        tenantId: webAppPortal.identity.tenantId
        objectId: webAppPortal.identity.principalId
        permissions: {
          keys: [
            'wrapKey'
            'unwrapKey'
          ]
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
        }
      }
    ]
    enabledForDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: (configurePrivateEndpoints ? 'Disabled' : 'Enabled')
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: (configurePrivateEndpoints ? 'Deny' : 'Allow')
    }
  }
}

resource keyVaultName_dataProtectionKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: dataProtectionKeyName
  properties: {
    kty: 'RSA'
    attributes: {
      enabled: true
    }
  }
}

resource keyVaultName_DataProtection_Storage_Path 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'DataProtection--Storage--Path'
  properties: {
    value: 'https://${dataProtectionStorageAccountName}.blob.${storageSuffix}/${dataProtectionStorageBlobContainer}/keys-${uniqueStr}.xml?${listServiceSas(dataProtectionStorageAccountName,'2023-04-01',dataProtectionStorageContainerSasProperties).serviceSasToken}'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    dataProtectionStorageAccountName_default_dataProtectionStorageBlobContainer
  ]
}

resource keyVaultName_ConnectionStrings_DefaultConnection 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ConnectionStrings--DefaultConnection'
  properties: {
    value: 'Server=tcp:${sqlServerName}${sqlServerSuffix},1433;Initial Catalog=${databaseName};Persist Security Info=False;Authentication=Active Directory Service Principal;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    attributes: {
      enabled: true
    }
  }
}

resource keyVaultName_Deployment_LocksContainerSasUrl 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'Deployment--LocksContainerSasUrl'
  properties: {
    value: 'https://${dataProtectionStorageAccountName}.blob.${storageSuffix}/${blobLeaseContainer}?${listServiceSas(dataProtectionStorageAccountName,'2023-04-01',blobLeaseContainerSasProperties).serviceSasToken}'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    dataProtectionStorageAccountName_default_blobLeaseContainer
  ]
}

resource dataProtectionStorageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: dataProtectionStorageAccountName
  location: location
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  tags: (tagsByResource[?'Microsoft.Storage/storageAccounts'] ?? json('{}'))
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: (configurePrivateEndpoints ? 'Disabled' : 'Enabled')
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource dataProtectionStorageAccountName_default_dataProtectionStorageBlobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  name: '${dataProtectionStorageAccountName}/default/${dataProtectionStorageBlobContainer}'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    dataProtectionStorageAccount
  ]
}

resource dataProtectionStorageAccountName_default_blobLeaseContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  name: '${dataProtectionStorageAccountName}/default/${blobLeaseContainer}'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    dataProtectionStorageAccount
  ]
}

resource scriptedActionAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: scriptedActionAccountName
  location: location
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  tags: (tagsByResource[?'Microsoft.Automation/automationAccounts'] ?? json('{}'))
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  tags: (tagsByResource[?'Microsoft.Automation/automationAccounts'] ?? json('{}'))
}

resource automationAccountName_subscriptionId 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: automationAccount
  name: 'subscriptionId'
  properties: {
    isEncrypted: true
    description: 'Azure Subscription Id'
    value: '"${subscription().subscriptionId}"'
  }
}

resource automationAccountName_webApp 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: automationAccount
  name: 'webAppName'
  properties: {
    isEncrypted: true
    description: 'Web App Name'
    value: '"${webAppPortalName}"'
  }
}

resource automationAccountName_resourceGroup 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: automationAccount
  name: 'resourceGroupName'
  properties: {
    isEncrypted: true
    description: 'Resource group'
    value: '"${resourceGroup().name}"'
  }
}

resource automationRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: webAppPortal
  name: automationRoleAssignmentName
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: automationAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource automationAccountName_automation_runbooks_0_automation_runbooks_name 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = [
  for i in range(0, length(automation.runbooks)): {
    parent: automationAccount
    name: automation.runbooks[i].name
    location: location
    properties: {
      description: automation.runbooks[i].description
      runbookType: automation.runbooks[i].type
      logProgress: false
      logVerbose: true
      publishContentLink: {
        uri: automation.runbooks[i].url
        version: automation.runbooks[i].version
      }
    }
    tags: (tagsByResource[?'Microsoft.Automation/automationAccounts/runbooks'] ?? json('{}'))
  }
]

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: union(
    json('{"NMW_OBJECT_TYPE":"LOG_ANALYTICS_WORKSPACE"}'),
    (tagsByResource[?'Microsoft.OperationalInsights/workspaces'] ?? json('{}'))
  )
}

resource lawName_SystemEvents 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'SystemEvents'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'System'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
    ]
  }
}

resource lawName_ApplicationEvents 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'ApplicationEvents'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'Application'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
    ]
  }
}

resource lawName_TerminalServicesLocalSessionManagerOperational 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'TerminalServicesLocalSessionManagerOperational'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
}

resource lawName_TerminalServicesRemoteConnectionManagerAdmin 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'TerminalServicesRemoteConnectionManagerAdmin'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
}

resource lawName_MicrosoftFSLogixAppsOperational 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'MicrosoftFSLogixAppsOperational'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'Microsoft-FSLogix-Apps/Operational'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
}

resource lawName_MicrosoftFSLogixAppsAdmin 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'MicrosoftFSLogixAppsAdmin'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'Microsoft-FSLogix-Apps/Admin'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  }
}

resource lawName_perfcounter1 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter1'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'LogicalDisk'
    instanceName: 'C:'
    intervalSeconds: 60
    counterName: '% Free Space'
  }
}

resource lawName_perfcounter2 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter2'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'LogicalDisk'
    instanceName: 'C:'
    intervalSeconds: 30
    counterName: 'Avg. Disk Queue Length'
  }
}

resource lawName_perfcounter3 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter3'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'LogicalDisk'
    instanceName: 'C:'
    intervalSeconds: 60
    counterName: 'Avg. Disk sec/Transfer'
  }
}

resource lawName_perfcounter4 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter4'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'LogicalDisk'
    instanceName: 'C:'
    intervalSeconds: 30
    counterName: 'Current Disk Queue Length'
  }
}

resource lawName_perfcounter5 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter5'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Available Mbytes'
  }
}

resource lawName_perfcounter6 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter6'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Page Faults/sec'
  }
}

resource lawName_perfcounter7 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter7'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Pages/sec'
  }
}

resource lawName_perfcounter8 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter8'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 30
    counterName: '% Committed Bytes In Use'
  }
}

resource lawName_perfcounter9 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter9'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Avg. Disk Queue Length'
  }
}

resource lawName_perfcounter10 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter10'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Avg. Disk sec/Read'
  }
}

resource lawName_perfcounter11 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter11'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Avg. Disk sec/Transfer'
  }
}

resource lawName_perfcounter12 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter12'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'PhysicalDisk'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Avg. Disk sec/Write'
  }
}

resource lawName_perfcounter18 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter18'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'Processor Information'
    instanceName: '_Total'
    intervalSeconds: 30
    counterName: '% Processor Time'
  }
}

resource lawName_perfcounter19 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter19'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'Terminal Services'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Active Sessions'
  }
}

resource lawName_perfcounter20 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter20'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'Terminal Services'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Inactive Sessions'
  }
}

resource lawName_perfcounter21 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter21'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'Terminal Services'
    instanceName: '*'
    intervalSeconds: 60
    counterName: 'Total Sessions'
  }
}

resource lawName_perfcounter22 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter22'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'User Input Delay per Process'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Max Input Delay'
  }
}

resource lawName_perfcounter23 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter23'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'User Input Delay per Session'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Max Input Delay'
  }
}

resource lawName_perfcounter24 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter24'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'RemoteFX Network'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Current TCP RTT'
  }
}

resource lawName_perfcounter25 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: law
  name: 'perfcounter25'
  kind: 'WindowsPerformanceCounter'
  properties: {
    objectName: 'RemoteFX Network'
    instanceName: '*'
    intervalSeconds: 30
    counterName: 'Current UDP Bandwidth'
  }
}

resource dce 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = {
  name: dceName
  location: location
  tags: union(
    json('{"NMW_OBJECT_TYPE":"DATA_COLLECTION_ENDPOINT"}'),
    (tagsByResource[?'Microsoft.Insights/dataCollectionEndpoints'] ?? json('{}'))
  )
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
  dependsOn: [
    law
  ]
}

resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: location
  tags: union(
    json('{"NMW_OBJECT_TYPE":"DATA_COLLECTION_RULE"}'),
    (tagsByResource[?'Microsoft.Insights/dataCollectionRules'] ?? json('{}'))
  )
  kind: 'Windows'
  properties: {
    dataCollectionEndpointId: dce.id
    dataSources: {
      performanceCounters: [
        {
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\LogicalDisk(C:)\\% Free Space'
            '\\LogicalDisk(C:)\\Avg. Disk sec/Transfer'
            '\\Terminal Services(*)\\Active Sessions'
            '\\Terminal Services(*)\\Inactive Sessions'
            '\\Terminal Services(*)\\Total Sessions'
          ]
          name: 'DS_WindowsPerformanceCounter_1'
        }
        {
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 30
          counterSpecifiers: [
            '\\LogicalDisk(C:)\\Avg. Disk Queue Length'
            '\\LogicalDisk(C:)\\Current Disk Queue Length'
            '\\Memory\\Available Mbytes'
            '\\Memory\\Page Faults/sec'
            '\\Memory\\Pages/sec'
            '\\Memory\\% Committed Bytes In Use'
            '\\PhysicalDisk(*)\\Avg. Disk Queue Length'
            '\\PhysicalDisk(*)\\Avg. Disk sec/Read'
            '\\PhysicalDisk(*)\\Avg. Disk sec/Transfer'
            '\\PhysicalDisk(*)\\Avg. Disk sec/Write'
            '\\Processor Information(_Total)\\% Processor Time'
            '\\User Input Delay per Process(*)\\Max Input Delay'
            '\\User Input Delay per Session(*)\\Max Input Delay'
            '\\RemoteFX Network(*)\\Current TCP RTT'
            '\\RemoteFX Network(*)\\Current UDP Bandwidth'
          ]
          name: 'DS_WindowsPerformanceCounter_2'
        }
      ]
      windowsEventLogs: [
        {
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'System!*[System[(Level=2 or Level=3)]]'
            'Application!*[System[(Level=2 or Level=3)]]'
            'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
            'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
            'Microsoft-FSLogix-Apps/Operational!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
            'Microsoft-FSLogix-Apps/Admin!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
          ]
          name: 'DS_WindowsEventLogs'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: law.id
          name: lawName
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
          'Microsoft-Event'
        ]
        destinations: [
          lawName
        ]
      }
    ]
  }
}

resource keyVaultName_lock 'Microsoft.Authorization/locks@2020-05-01' = {
  scope: keyVault
  name: '${keyVaultName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'KeyVault should not be deleted.'
  }
}

resource databaseName_lock 'Microsoft.Authorization/locks@2020-05-01' = {
  scope: sqlServerName_database
  name: '${databaseName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Database should not be deleted.'
  }
}

resource dataProtectionStorageAccountName_lock 'Microsoft.Authorization/locks@2020-05-01' = {
  scope: dataProtectionStorageAccount
  name: '${dataProtectionStorageAccountName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'StorageAccount to data protection should not be deleted.'
  }
}

resource privateEndpointsVnet 'Microsoft.Network/virtualNetworks@2022-07-01' = if (configurePrivateEndpoints) {
  name: privateEndpointsVnetName
  location: location
  tags: (tagsByResource[?'Microsoft.Network/virtualNetworks'] ?? json('{}'))
  properties: {
    addressSpace: {
      addressPrefixes: [
        privateEndpointsVnetCidr
      ]
    }
    subnets: [
      {
        name: privateEndpointsSubnetName
        properties: {
          addressPrefix: privateEndpointsSubnetCidr
          privateEndpointNetworkPolicies: 'RouteTableEnabled'
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetCidr
          delegations: [
            {
              name: 'serverFarmsDelegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
              locations: [
                location
              ]
            }
          ]
          privateEndpointNetworkPolicies: 'RouteTableEnabled'
        }
      }
    ]
  }
}

resource sqlServerName_pe 'Microsoft.Network/privateEndpoints@2021-05-01' = if (configurePrivateEndpoints) {
  name: '${sqlServerName}-pe'
  location: location
  tags: (tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? json('{}'))
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', privateEndpointsVnetName, privateEndpointsSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlServerName}-pls'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
          requestMessage: 'Please approve this connection'
        }
      }
    ]
  }
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (configurePrivateEndpoints) {
  name: sqlPrivateDnsZoneName
  location: 'global'
  properties: {}
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones'] ?? json('{}'))
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource sqlPrivateDnsZoneName_privateEndpointsVnetName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (configurePrivateEndpoints) {
  parent: sqlPrivateDnsZone
  name: '${privateEndpointsVnetName}-link'
  location: 'global'
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones/virtualNetworkLinks'] ?? json('{}'))
  properties: {
    virtualNetwork: {
      id: privateEndpointsVnet.id
    }
    registrationEnabled: false
  }
}

resource sqlServerName_pe_default 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (configurePrivateEndpoints) {
  parent: sqlServerName_pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sqlDnsZoneConfig'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}

resource webAppPortalName_pe 'Microsoft.Network/privateEndpoints@2021-05-01' = if (configurePrivateEndpoints) {
  name: '${webAppPortalName}-pe'
  location: location
  tags: (tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? json('{}'))
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', privateEndpointsVnetName, privateEndpointsSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: '${webAppPortalName}-pls'
        properties: {
          privateLinkServiceId: webAppPortal.id
          groupIds: [
            'sites'
          ]
          requestMessage: 'Please approve this connection'
        }
      }
    ]
  }
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource appServicePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (configurePrivateEndpoints) {
  name: appServicePrivateDnsZoneName
  location: 'global'
  properties: {}
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones'] ?? json('{}'))
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource appServicePrivateDnsZoneName_privateEndpointsVnetName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (configurePrivateEndpoints) {
  parent: appServicePrivateDnsZone
  name: '${privateEndpointsVnetName}-link'
  location: 'global'
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones/virtualNetworkLinks'] ?? json('{}'))
  properties: {
    virtualNetwork: {
      id: privateEndpointsVnet.id
    }
    registrationEnabled: false
  }
}

resource webAppPortalName_pe_default 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (configurePrivateEndpoints) {
  parent: webAppPortalName_pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'appServiceDnsZoneConfig'
        properties: {
          privateDnsZoneId: appServicePrivateDnsZone.id
        }
      }
    ]
  }
}

resource keyVaultName_pe 'Microsoft.Network/privateEndpoints@2021-05-01' = if (configurePrivateEndpoints) {
  name: '${keyVaultName}-pe'
  location: location
  tags: (tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? json('{}'))
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', privateEndpointsVnetName, privateEndpointsSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-pls'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
          requestMessage: 'Please approve this connection'
        }
      }
    ]
  }
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (configurePrivateEndpoints) {
  name: keyVaultPrivateDnsZoneName
  location: 'global'
  properties: {}
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones'] ?? json('{}'))
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource keyVaultPrivateDnsZoneName_privateEndpointsVnetName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (configurePrivateEndpoints) {
  parent: keyVaultPrivateDnsZone
  name: '${privateEndpointsVnetName}-link'
  location: 'global'
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones/virtualNetworkLinks'] ?? json('{}'))
  properties: {
    virtualNetwork: {
      id: privateEndpointsVnet.id
    }
    registrationEnabled: false
  }
}

resource keyVaultName_pe_default 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (configurePrivateEndpoints) {
  parent: keyVaultName_pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'keyVaultDnsZoneConfig'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

resource dataProtectionStorageAccountName_pe 'Microsoft.Network/privateEndpoints@2021-05-01' = if (configurePrivateEndpoints) {
  name: '${dataProtectionStorageAccountName}-pe'
  location: location
  tags: (tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? json('{}'))
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', privateEndpointsVnetName, privateEndpointsSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: '${dataProtectionStorageAccountName}-pls'
        properties: {
          privateLinkServiceId: dataProtectionStorageAccount.id
          groupIds: [
            'blob'
          ]
          requestMessage: 'Please approve this connection'
        }
      }
    ]
  }
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (configurePrivateEndpoints) {
  name: blobPrivateDnsZoneName
  location: 'global'
  properties: {}
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones'] ?? json('{}'))
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource blobPrivateDnsZoneName_privateEndpointsVnetName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (configurePrivateEndpoints) {
  parent: blobPrivateDnsZone
  name: '${privateEndpointsVnetName}-link'
  location: 'global'
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones/virtualNetworkLinks'] ?? json('{}'))
  properties: {
    virtualNetwork: {
      id: privateEndpointsVnet.id
    }
    registrationEnabled: false
  }
}

resource dataProtectionStorageAccountName_pe_default 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (configurePrivateEndpoints) {
  parent: dataProtectionStorageAccountName_pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storageDnsZoneConfig'
        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (configurePrivateEndpoints) {
  name: filePrivateDnsZoneName
  location: 'global'
  properties: {}
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones'] ?? json('{}'))
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource filePrivateDnsZoneName_privateEndpointsVnetName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (configurePrivateEndpoints) {
  parent: filePrivateDnsZone
  name: '${privateEndpointsVnetName}-link'
  location: 'global'
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones/virtualNetworkLinks'] ?? json('{}'))
  properties: {
    virtualNetwork: {
      id: privateEndpointsVnet.id
    }
    registrationEnabled: false
  }
}

resource automationPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (configurePrivateEndpoints) {
  name: automationPrivateDnsZoneName
  location: 'global'
  properties: {}
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones'] ?? json('{}'))
  dependsOn: [
    privateEndpointsVnet
  ]
}

resource automationPrivateDnsZoneName_privateEndpointsVnetName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (configurePrivateEndpoints) {
  parent: automationPrivateDnsZone
  name: '${privateEndpointsVnetName}-link'
  location: 'global'
  tags: (tagsByResource[?'Microsoft.Network/privateDnsZones/virtualNetworkLinks'] ?? json('{}'))
  properties: {
    virtualNetwork: {
      id: privateEndpointsVnet.id
    }
    registrationEnabled: false
  }
}

output appUrl string = uri('https://${webAppPortal.properties.defaultHostName}', '')
