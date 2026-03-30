// ---------------------------------------------------------------------------
// main.bicep — Orchestrator for movie-trivia-agent infrastructure
// ---------------------------------------------------------------------------
targetScope = 'subscription'

@description('Environment name used for resource naming.')
@allowed(['dev', 'staging', 'prod'])
param environmentName string = 'dev'

@description('Azure region for all resources.')
param location string = 'eastus2'

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-movie-trivia-agent-${environmentName}'
  location: location
}

// ---------------------------------------------------------------------------
// Monitoring — Log Analytics + Application Insights
// ---------------------------------------------------------------------------
module monitoring 'monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
  }
}

// ---------------------------------------------------------------------------
// Storage — Blob container + Queue
// ---------------------------------------------------------------------------
module storage 'storage.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
  }
}

// ---------------------------------------------------------------------------
// Foundry — Azure AI Services + gpt-5.4 deployment
// ---------------------------------------------------------------------------
module foundry 'foundry.bicep' = {
  name: 'foundry'
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
  }
}

// ---------------------------------------------------------------------------
// Function App — .NET 10 isolated worker
// ---------------------------------------------------------------------------
module functionApp 'functionApp.bicep' = {
  name: 'functionApp'
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
    storageConnectionString: storage.outputs.storageConnectionString
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    foundryEndpoint: foundry.outputs.foundryEndpoint
    foundryKey: foundry.outputs.foundryKey
    foundryModelId: foundry.outputs.modelDeploymentName
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Resource group name.')
output resourceGroupName string = resourceGroup.name

@description('Function App hostname.')
output functionAppHostname string = functionApp.outputs.functionAppHostname

@description('Azure AI Services endpoint.')
output foundryEndpoint string = foundry.outputs.foundryEndpoint

@description('Storage account name.')
output storageAccountName string = storage.outputs.storageAccountName
