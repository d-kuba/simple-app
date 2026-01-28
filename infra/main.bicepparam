using './main.bicep'

param location = 'eastus'
param appServicePlanName = 'asp-helloworld'
param webAppName = 'hello-world-app'
param appServicePlanSku = 'B1'
param dotnetVersion = '8.0'
param logAnalyticsWorkspaceName = 'log-helloworld'
param appInsightsName = 'appi-helloworld'
