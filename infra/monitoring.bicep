// ---------------------------------------------------------------------------
// monitoring.bicep — Log Analytics workspace + Application Insights
// ---------------------------------------------------------------------------

@description('Environment name (e.g. dev, staging, prod).')
param environmentName string

@description('Azure region for all resources.')
param location string

// ---------------------------------------------------------------------------
// Naming
// ---------------------------------------------------------------------------
var logAnalyticsName = 'log-movie-trivia-agent-${environmentName}'
var appInsightsName  = 'appi-movie-trivia-agent-${environmentName}'

// ---------------------------------------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ---------------------------------------------------------------------------
// Application Insights (workspace-based)
// ---------------------------------------------------------------------------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Application Insights connection string.')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Application Insights instrumentation key.')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Log Analytics workspace ID.')
output logAnalyticsWorkspaceId string = logAnalytics.id
