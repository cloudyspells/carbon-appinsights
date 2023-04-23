targetScope = 'subscription'

metadata Description = 'This template deploys the carbon-appsights function app.'

@description('The name project to deploy. Is used in name convention for all resources.')
param projectName string = 'carbon-appsights'

@description('The environment to deploy. Is used in name convention for all resources.')
param environment string = 'dev'

@description('The location for the Carbon control Function App.')
param location string = 'westeurope'

@description('Azure regions to get emissions for as JSON array of strings')
param emissionRegions string = '["westeurope","northeurope","norwayeast"]'

@description('The ElectricityMaps API key.')
@secure()
param emToken string

var regionShortNames = {
  westeurope: 'weu'
  northeurope: 'neu'
  norwayeast: 'noe'
  francecentral: 'frc'
}
var funcAppNameConvention = '${regionShortNames[location]}-${projectName}-${environment}'
var functionAppName = 'func-${funcAppNameConvention}'
var functionAppServicePlanName = 'plan-${funcAppNameConvention}'
var functionAppResourceGroupName = 'rg-${funcAppNameConvention}-funcapp'
var functionAppStorageAccountPrefix = 'sacloudy'
var keyVaultName = 'kv-${funcAppNameConvention}'

// deploy the global function app resource group
resource rgFunctionApp 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: functionAppResourceGroupName
  location: location
  tags: {
    environment: environment
    projectName: projectName
  }
}

// deploy the global function app
module functionApp 'modules/carbon-functionapp.bicep' = {
  name: 'deploy-functionApp'
  scope: rgFunctionApp
  params: {
    functionAppName: functionAppName
    functionAppServicePlanName: functionAppServicePlanName
    functionAppStorageAccountPrefix: functionAppStorageAccountPrefix
    keyVaultName: keyVaultName
    location: location
    emToken: emToken
    emissionRegions: emissionRegions
  }
}

// Assign the function app managed identity contributor role to the global resource group
resource functionAppRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(functionAppName, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: functionApp.outputs.functionAppManagedIdentityId
    principalType: 'ServicePrincipal'
  }
}

output functionAppManagedIdentityId string = functionApp.outputs.functionAppManagedIdentityId
output functionAppResourceGroup string = rgFunctionApp.name
output functionAppName string = functionAppName
