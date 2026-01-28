# Hello World .NET App with Azure Deployment

This is a simple .NET 8 hello world web application that can be deployed to Azure App Service using Bicep and Azure Pipelines.

## Project Structure

```
├── Program.cs                  # Main application entry point
├── HelloWorldApp.csproj        # .NET project file
├── infra/
│   ├── main.bicep             # Bicep infrastructure template
│   └── main.bicepparam        # Bicep parameters file
├── azure-pipelines.yml        # Azure Pipelines CI/CD configuration
└── README.md                  # This file
```

## Application

The application is a minimal ASP.NET Core web app that returns "Hello World!" on the root endpoint.

## Infrastructure

The Bicep template creates the following Azure resources:
- **App Service Plan** (Linux, B1 SKU)
- **App Service** (.NET 8.0 runtime)

### Features:
- HTTPS-only access
- Always On enabled
- FTPS disabled for security
- TLS 1.2 minimum
- HTTP/2 enabled

## Prerequisites

- [.NET 8.0 SDK](https://dotnet.microsoft.com/download)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- Azure subscription
- Azure DevOps account (for pipelines)

## Local Development

### Run the application locally:

```powershell
dotnet run
```

The application will be available at `http://localhost:5000`

### Test the application:

```powershell
Invoke-WebRequest -Uri http://localhost:5000 | Select-Object -ExpandProperty Content
# Output: Hello World!
```

## Manual Deployment

### 1. Login to Azure

```powershell
az login
```

### 2. Create a resource group

```powershell
az group create --name rg-helloworld --location eastus
```

### 3. Deploy the infrastructure

```powershell
az deployment group create --resource-group rg-helloworld --template-file infra/main.bicep --parameters infra/main.bicepparam
```

### 4. Build and publish the application

```powershell
dotnet publish HelloWorldApp.csproj -c Release -o ./publish
```

### 5. Deploy to App Service

```powershell
# Get the web app name from deployment outputs
$webAppName = az deployment group show `
  --resource-group rg-helloworld `
  --name main `
  --query properties.outputs.webAppName.value `
  --output tsv

# Create a zip file of the published app
Compress-Archive -Path ./publish/* -DestinationPath ./app.zip -Force

# Deploy using Azure CLI
az webapp deployment source config-zip `
  --resource-group rg-helloworld `
  --name $webAppName `
  --src app.zip
```

## CI/CD with Azure Pipelines

### Setup Instructions:

1. **Create a Service Connection in Azure DevOps:**
   - Go to Project Settings > Service connections
   - Create a new Azure Resource Manager service connection
   - Select your subscription and resource group
   - Name it (e.g., "AzureServiceConnection")

2. **Update the pipeline variables:**
   - Edit `azure-pipelines.yml`
   - Update `azureSubscription` with your service connection name
   - Adjust `resourceGroupName` and `location` if needed

3. **Create the pipeline in Azure DevOps:**
   - Go to Pipelines > New pipeline
   - Select "Azure Repos Git" or your repository source
   - Choose "Existing Azure Pipelines YAML file"
   - Select `/azure-pipelines.yml`
   - Run the pipeline

### Pipeline Stages:

1. **Build**: Compiles and publishes the .NET application
2. **DeployInfra**: Deploys Azure infrastructure using Bicep
3. **DeployApp**: Deploys the application to Azure App Service

## Environment Variables

The application uses the following environment variables:
- `ASPNETCORE_ENVIRONMENT`: Set to "Production" by default

## Customization

### Change the SKU:

Edit [infra/main.bicepparam](infra/main.bicepparam):
```bicep
param appServicePlanSku = 'F1'  // Free tier
param appServicePlanSku = 'B1'  // Basic tier (default)
param appServicePlanSku = 'S1'  // Standard tier
```

### Change the .NET version:

Edit [infra/main.bicepparam](infra/main.bicepparam):
```bicep
param dotnetVersion = '8.0'  // .NET 8 (default)
param dotnetVersion = '7.0'  // .NET 7
```

### Modify the app name:

Edit [infra/main.bicepparam](infra/main.bicepparam):
```bicep
param webAppName = 'my-custom-app-name-${uniqueString(resourceGroup().id)}'
```

## Clean Up

To delete all resources:

```powershell
az group delete --name rg-helloworld --yes --no-wait
```

## Troubleshooting

### View application logs:

```powershell
az webapp log tail --name $webAppName --resource-group rg-helloworld
```

### Access the application:

After deployment, get the URL:

```powershell
$hostname = az webapp show `
  --name $webAppName `
  --resource-group rg-helloworld `
  --query defaultHostName `
  --output tsv
Write-Host "https://$hostname"
```

Then visit: `https://<hostname>`

## License

MIT