@description('The location for all resources')
param location string = resourceGroup().location

@description('The name of the App Service Plan')
param appServicePlanName string = 'asp-${uniqueString(resourceGroup().id)}'

@description('The name of the Web App')
param webAppName string = 'app-${uniqueString(resourceGroup().id)}'

@description('The SKU for the App Service Plan')
param appServicePlanSku string = 'B1'

@description('The .NET runtime version')
param dotnetVersion string = '8.0'

@description('The name of the Log Analytics Workspace')
param logAnalyticsWorkspaceName string = 'log-${uniqueString(resourceGroup().id)}'

@description('The name of the Application Insights instance')
param appInsightsName string = 'appi-${uniqueString(resourceGroup().id)}'

@description('The name of the Storage Account')
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('The name of the Key Vault')
param keyVaultName string = 'kv-${uniqueString(resourceGroup().id)}'

@description('The secret value to store in Key Vault')
@secure()
param secretValue string

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    RetentionInDays: 30
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// Blob container for crash dumps
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource crashDumpsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'crashdumps'
  properties: {
    publicAccess: 'None'
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableSoftDelete: false
    accessPolicies: []
  }
}

// Key Vault Secret
resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'MyAppSecret'
  properties: {
    value: secretValue
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Generate SAS token for crash dumps storage
var sasConfig = {
  signedProtocol: 'https'
  signedResourceTypes: 'sco'
  signedPermission: 'rwdlacup'
  signedServices: 'b'
  signedExpiry: '2099-12-31T23:59:59Z'
}
var storageSasToken = listAccountSas(storageAccount.id, '2023-01-01', sasConfig).accountSasToken
var crashDumpsSasUrl = '${storageAccount.properties.primaryEndpoints.blob}crashdumps?${storageSasToken}'

// Web App
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|${dotnetVersion}'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'DIAGNOSTICS_AZUREBLOBCONTAINERSASURL'
          value: crashDumpsSasUrl
        }
        {
          name: 'WEBSITE_CRASHDUMPS_ENABLED'
          value: 'true'
        }
        {
          name: 'WEBSITE_DAAS_STORAGE_CONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=core.windows.net'
        }
        {
          name: 'MyAppSecret'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVaultSecret.name})'
        }
      ]
    }
    httpsOnly: true
  }
}

// Key Vault Secrets User role assignment for Web App
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webApp.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor role assignment for Web App
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, webApp.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Queue Data Contributor role assignment for Web App
resource storageQueueRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, webApp.id, 'Storage Queue Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Table Data Contributor role assignment for Web App
resource storageTableRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, webApp.id, 'Storage Table Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3') // Storage Table Data Contributor
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('The default hostname of the web app')
output webAppHostname string = webApp.properties.defaultHostName

@description('The resource ID of the web app')
output webAppId string = webApp.id

@description('The name of the web app')
output webAppName string = webApp.name

@description('The Application Insights connection string')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('The Application Insights instrumentation key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('The Storage Account name')
output storageAccountName string = storageAccount.name

@description('The Storage Account primary endpoint')
output storageAccountPrimaryEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('The Key Vault name')
output keyVaultName string = keyVault.name

@description('The Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri
