@description('The name of the Container Apps Environment')
param containerAppsEnvironmentName string

@description('The name of the Container App')
param containerAppName string

@description('The location for the Container App resources')
param location string

@description('The ID of the user-assigned managed identity')
param managedIdentityId string

@description('The Client ID of the user-assigned managed identity')
param managedIdentityClientId string

@description('The name of the container image to deploy')
param containerImageName string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('The name of the container registry')
param containerRegistryLoginServer string = ''

@description('The resource ID of the container registry')
param containerRegistryId string = ''

@description('The Key Vault URI where secrets are stored')
param keyVaultUri string

@description('Environment variables for the container')
param environmentVariables array = []

@description('Target port for the container')
param containerPort int = 8080

@description('Minimum replicas for the container app')
@minValue(0)
@maxValue(30)
param minReplicas int = 1

@description('Maximum replicas for the container app')
@minValue(1)
@maxValue(30)
param maxReplicas int = 3

var logAnalyticsWorkspaceName = 'log-${containerAppsEnvironmentName}'

// Create Log Analytics workspace for Container Apps Environment
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

// Create Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-06-01-preview' = {
  name: containerAppsEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

// Create Container App
resource containerApp 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: containerPort
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: !empty(containerRegistryLoginServer) && !empty(containerRegistryId) ? [
        {
          server: containerRegistryLoginServer
          identity: managedIdentityId
        }
      ] : []
      secrets: [
        {
          name: 'keyvault-endpoint'
          value: keyVaultUri
        }
      ]
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: containerImageName
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: concat(environmentVariables, [
              {
                name: 'AZURE_CLIENT_ID'
                value: managedIdentityClientId
              }
              {
                name: 'KEY_VAULT_URI'
                secretRef: 'keyvault-endpoint'
              }
            ])
          probes: [
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: containerPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: containerPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
}

// Output important information
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerAppId string = containerApp.id
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
