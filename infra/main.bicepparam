using './main.bicep'

param location = 'eastus'
param appServicePlanName = 'asp-helloworld'
param webAppName = 'hello-world-app'
param appServicePlanSku = 'S1'
param dotnetVersion = '8.0'
param logAnalyticsWorkspaceName = 'log-helloworld'
param appInsightsName = 'appi-helloworld'
// storageAccountName uses default value from main.bicep with uniqueString
param keyVaultName = 'kv-helloworld-001'
param secretValue = 'MySecretValue123!'
