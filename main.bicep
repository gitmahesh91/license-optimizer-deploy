// =====================================================================
// License Optimizer — Azure Functions deployment
// Creates: Storage Account, Log Analytics, Application Insights,
//          Consumption (Y1) Windows plan, Function App (.NET 8 isolated, v4)
// Code:    Runs from the published package URL (WEBSITE_RUN_FROM_PACKAGE)
// =====================================================================

@description('Azure region for all resources, e.g. centralindia. If reusing an existing plan, this must match that plan\'s region.')
param location string = resourceGroup().location

@description('Short prefix used to build resource names (lowercase letters/numbers, 3-11 chars).')
@minLength(3)
@maxLength(11)
param namePrefix string = 'licopt'

@description('Your Microsoft Entra tenant ID (Directory ID).')
param tenantId string

@description('Client ID (Application ID) of your app registration.')
param clientId string

@description('Client secret value of your app registration.')
@secure()
param clientSecret string

@description('Your Dataverse environment URL, e.g. https://yourorg.crm8.dynamics.com')
param dataverseUrl string

@description('Microsoft Graph base URL. Keep the default unless told otherwise.')
param graphBaseUrl string = 'https://graph.microsoft.com'

@description('Time zone used by the timer-triggered functions.')
param websiteTimeZone string = 'India Standard Time'

@description('URL of the published function code package. Keep the default.')
param packageUrl string = 'https://github.com/gitmahesh91/license-optimizer-deploy/releases/download/v1.0.0/LicenseOptimizerFunctions.zip'

@description('Optional. Name of an existing Consumption plan in this resource group to reuse. Leave empty to create a new plan.')
param existingPlanName string = ''

// ---------- Names (unique per resource group, so customers never collide) ----------
var suffix = uniqueString(resourceGroup().id)
var functionAppName = '${namePrefix}-func-${suffix}'
var planName = '${namePrefix}-plan-${suffix}'
var appInsightsName = '${namePrefix}-ai-${suffix}'
var workspaceName = '${namePrefix}-law-${suffix}'
var storageName = take(toLower(replace('${namePrefix}st${suffix}', '-', '')), 24)
var contentShareName = toLower(functionAppName)

// ---------- Storage (required by the Functions runtime) ----------
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

var storageConnection = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'

// ---------- Monitoring ----------
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
  }
}

// ---------- Hosting plan: reuse existing, or create Consumption (Y1), Windows ----------
var useExistingPlan = !empty(existingPlanName)

resource existingPlan 'Microsoft.Web/serverfarms@2023-12-01' existing = if (useExistingPlan) {
  name: existingPlanName
}

resource newPlan 'Microsoft.Web/serverfarms@2023-12-01' = if (!useExistingPlan) {
  name: planName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: false // false = Windows
  }
}

// If reusing a plan, the 'location' parameter must match that plan's region
var planId = useExistingPlan ? existingPlan.id : newPlan.id

// ---------- Function App ----------
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: planId
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        // Runtime
        { name: 'AzureWebJobsStorage', value: storageConnection }
        { name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING', value: storageConnection }
        { name: 'WEBSITE_CONTENTSHARE', value: contentShareName }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet-isolated' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: packageUrl }
        { name: 'WEBSITE_TIME_ZONE', value: websiteTimeZone }
        // License Optimizer settings (read by the functions)
        { name: 'TENANT_ID', value: tenantId }
        { name: 'CLIENT_ID', value: clientId }
        { name: 'CLIENT_SECRET', value: clientSecret }
        { name: 'DATAVERSE_URL', value: dataverseUrl }
        { name: 'GraphBaseUrl', value: graphBaseUrl }
      ]
    }
  }
}

// ---------- Outputs (copy these into the Dataverse Config record) ----------
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output resourceGroupName string = resourceGroup().name
