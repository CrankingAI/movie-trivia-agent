// ---------------------------------------------------------------------------
// foundry.bicep — Azure AI Services (Foundry) with gpt-5.4 model deployment
// ---------------------------------------------------------------------------

@description('Environment name (e.g. dev, staging, prod).')
param environmentName string

@description('Azure region for all resources.')
param location string

// ---------------------------------------------------------------------------
// Naming
// ---------------------------------------------------------------------------
var aiServicesName = 'ai-movie-trivia-agent-${environmentName}'

// ---------------------------------------------------------------------------
// Azure AI Services account
// ---------------------------------------------------------------------------
resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: aiServicesName
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// gpt-5.4 model deployment
// ---------------------------------------------------------------------------
resource gpt54Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: 'gpt-5.4'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.4'
      version: '2026-03-05'
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Azure AI Services endpoint URL.')
output foundryEndpoint string = aiServices.properties.endpoint

@secure()
@description('Azure AI Services primary key.')
output foundryKey string = aiServices.listKeys().key1

@description('Azure AI Services resource name.')
output aiServicesName string = aiServices.name

@description('Model deployment name.')
output modelDeploymentName string = gpt54Deployment.name
