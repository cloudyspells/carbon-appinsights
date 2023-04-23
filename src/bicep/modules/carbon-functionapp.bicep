targetScope = 'resourceGroup'

metadata Description = 'This template deploys a Function App that will schedule the Carbon Scheduler Function to run every 15 minutes.'

@description('Name for the Function App that will be  created')
param functionAppName string

@description('Name prefix for the Storage Account that will be  created')
param functionAppStorageAccountPrefix string

@description('Name for the App Service Plan that will be  created')
param functionAppServicePlanName string

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Storage Account SKU name')
param storageAccountSkuName string = 'Standard_LRS'

@description('Location for all resources.')
param location string

@description('The username for the WattTime API')
@secure()
param emToken string

@description('The name of the Azure Key Vault to store the ElectricityMaps API credentials')
param keyVaultName string

@description('Azure regions to get emissions for as JSON array of strings')
param emissionRegions string = '"westeurope","northeurope","norwayeast"'

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionAppStorageAccount.listKeys().keys[0].value}'

// Create an App Service Plan for hosting the function app
resource functionAppServicePlan 'Microsoft.Web/serverfarms@2019-08-01' = {
  name: functionAppServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  kind: 'functionapp'
  properties: {
  }
}

// Deploy storage account and container for the function app
resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: '${functionAppStorageAccountPrefix}${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageAccountSkuName
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
    accessTier: 'Hot'
  }
  resource blobService 'blobServices' = {
    name: 'default'
    resource container 'containers' = {
      name: 'content'
    }
  }
}

// Deploy an application insights instance for the function app
resource functionAppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: replace(functionAppName, 'func-', 'ai-')
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Deploy a log analytics workspace for the application insights instance
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: replace(functionAppName, 'func-', 'log-')
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Deploy the function app with the storage account and service plan and application settings for the WattTime API
resource funcApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    clientAffinityEnabled: false
    serverFarmId: functionAppServicePlan.id
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      netFrameworkVersion: 'v6.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '7.2'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'ContentStorageAccount'
          value: functionAppStorageAccount.name
        }
        {
          name: 'ContentContainer'
          value: functionAppStorageAccount::blobService::container.name
        }
        {
          name: 'emToken'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/emToken)'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: functionAppInsights.properties.InstrumentationKey
        }
        {
          name: 'REGIONS'
          value: '[${emissionRegions}]'
        }
      ]
    }
  }
}


resource function 'Microsoft.Web/sites/functions@2022-03-01' = {
  name: 'Timer20Mins'
  parent: funcApp
  properties: {
    config: {
      bindings: [
        {
          name: 'Timer'
          type: 'timerTrigger'
          direction: 'in'
          schedule: '0 */20 * * * *'
        }
      ]
    }
  }
}

// Deploy the Keyvault with an access policy for the function app managed identity
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: funcApp.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          certificates: [
            'get'
            'list'
          ]
        }
      }
    ]
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
}
  resource secretEmToken 'secrets' = {
    name: 'emToken'
    properties: {
      value: emToken
    }
  }
}

output functionAppManagedIdentityId string = funcApp.identity.principalId
output functionAppManagedIdentityTenantId string = funcApp.identity.tenantId
