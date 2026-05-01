@description('The environment name (dev, staging, prod)')
param environmentName string

@description('The location for all resources')
param location string = 'uksouth'

@description('The date and time the resource was created')
param createdOn string = utcNow('dd/MM/yyyy')

var purpose = 'andytest'
var createdBy = 'Github_Azure_Dev_Integration'

var functionAppName = 'func-${purpose}-online-${environmentName}'
var storageAccountName = 'stg${purpose}${environmentName}'
var appServicePlanName = 'plan-${purpose}-${environmentName}'

// Add a variable for common tags
var tags = {
  Environment: environmentName
  Application: 'Andy Test'
  Purpose: purpose
  CreatedOn: createdOn
  CreatedBy: createdBy
  ManagedBy: 'Bicep'
}

// Storage Account
 resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
   name: storageAccountName
   location: location
   tags: tags
   sku: {
     name: 'Standard_GRS'  // Geo-redundant storage
   }
   kind: 'StorageV2'
   properties: {
     accessTier: 'Cool'    // Cool access tier
     minimumTlsVersion: 'TLS1_2'
     supportsHttpsTrafficOnly: true
     allowBlobPublicAccess: false     // Keep it private
     publicNetworkAccess: 'Enabled'   // Allow network access but not public blob access
   }
 }

// Private container
resource formUploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'form-uploads'
  properties: {
    publicAccess: 'None'  // Private access only
  }
}

// Add blob service resource
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'Y1'    // Consumption plan
    tier: 'Dynamic'
  }
  kind: 'linux'   // Linux platform
  properties: {
    reserved: true // Required for Linux
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true        // Required for Linux
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      minTlsVersion: '1.2'
      http20Enabled: true
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('func-andytest-online-${environmentName}')
        }
        {
          name: 'AZURE_FUNCTIONS_ENVIRONMENT'
          value: environmentName
        }
      ]
      cors: {
        allowedOrigins: [
          'http://localhost:3000'
        ]
        supportCredentials: false
      }
    }
  }
}
