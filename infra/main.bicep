targetScope = 'subscription'

@description('The name of the resource group')
param resourceGroupName string = 'rg-passwordless-workshop'

@description('The location for the resources')
param location string = 'westeurope'

@description('The name for the managed identity')
param managedIdentityName string = 'id-passwordless-workshop'

@description('The name for the container registry')
param containerRegistryName string = 'crpasswordlessworkshop${uniqueString(subscription().id)}'

@description('The name for the SQL Server')
param sqlServerName string = 'sql-passwordless-workshop-${uniqueString(subscription().id)}'

@description('The name for the SQL Database')
param sqlDatabaseName string = 'sqldb-passwordless-events'

@description('The administrator login username for the SQL server')
param sqlAdministratorLogin string = 'sqladmin'

@description('The administrator login password for the SQL server')
@secure()
param sqlAdministratorLoginPassword string

@description('The name for the Service Bus namespace')
param serviceBusNamespaceName string = 'sb-passwordless-workshop-${uniqueString(subscription().id)}'

@description('The name for the Redis Cache')
param redisCacheName string = 'redis-passwordless-${uniqueString(subscription().id)}'

@description('The name for the Storage Account')
param storageAccountName string = 'stpasswordless${uniqueString(subscription().id)}'

@description('The name for the Key Vault')
param keyVaultName string = 'kv-passwordless-${uniqueString(subscription().id)}'

@description('The name for the Container Apps Environment')
param containerAppsEnvironmentName string = 'env-passwordless-${uniqueString(subscription().id)}'

@description('The name for the Container App')
param containerAppName string = 'app-passwordless-workshop'

@description('The name of the container image to deploy')
param containerImageName string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// Create resource group
module resourceGroup 'resource-group.bicep' = {
  name: 'resourceGroupDeployment'
  params: {
    resourceGroupName: resourceGroupName
    location: location
  }
}

// Create managed identity
module managedIdentity 'managed-identity.bicep' = {
  name: 'managedIdentityDeployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    managedIdentityName: managedIdentityName
    location: location
  }
}

// Create container registry
module containerRegistry 'container-registry.bicep' = {
  name: 'containerRegistryDeployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    containerRegistryName: containerRegistryName
    location: location
  }
  dependsOn: [
    managedIdentity
  ]
}

// Create SQL Server and Database
module sqlServer 'sql-server.bicep' = {
  name: 'sqlServerDeployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    location: location
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
  }
  dependsOn: [
    managedIdentity
  ]
}

// Create Service Bus
module serviceBus 'service-bus.bicep' = {
  name: 'serviceBusDeployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    location: location
  }
  dependsOn: [
    managedIdentity
  ]
}

// Create Storage Account
module storage 'storage-account.bicep' = {
  name: 'storageDeployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    storageAccountName: storageAccountName
    location: location
  }
  dependsOn: [
    managedIdentity
  ]
}

// Get connection strings
var sqlConnectionString = 'Server=${sqlServer.outputs.sqlServerFqdn};Database=${sqlDatabaseName};Authentication=Active Directory Default;TrustServerCertificate=True'
var serviceBusConnectionString = 'Endpoint=${serviceBus.outputs.serviceBusEndpoint};Authentication=ManagedIdentity'
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage}'

// Create Key Vault and store connection strings
module keyVault 'key-vault.bicep' = {
  name: 'keyVaultDeployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    keyVaultName: keyVaultName
    location: location
    managedIdentityPrincipalId: managedIdentity.outputs.managedIdentityPrincipalId
    sqlConnectionString: sqlConnectionString
    serviceBusConnectionString: serviceBusConnectionString
    storageConnectionString: storageConnectionString
  }
  dependsOn: [
    sqlServer
    serviceBus
    storage
  ]
}

// Create Container Apps with managed identity
module containerApps 'container-apps.bicep' = {
  name: 'containerAppsDeployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerAppName: containerAppName
    location: location
    managedIdentityId: managedIdentity.outputs.managedIdentityId
    managedIdentityClientId: managedIdentity.outputs.managedIdentityClientId
    containerImageName: containerImageName
    containerRegistryLoginServer: containerRegistry.outputs.containerRegistryLoginServer
    containerRegistryId: containerRegistry.outputs.containerRegistryId
    keyVaultUri: keyVault.outputs.keyVaultUri
    environmentVariables: [
      {
        name: 'AZURE_SQL_SERVER'
        value: sqlServer.outputs.sqlServerFqdn
      }
      {
        name: 'AZURE_SQL_DATABASE'
        value: sqlDatabaseName
      }
      {
        name: 'AZURE_SERVICEBUS_NAMESPACE'
        value: serviceBus.outputs.serviceBusNamespaceName
      }
      {
        name: 'AZURE_SERVICEBUS_QUEUE'
        value: serviceBus.outputs.serviceBusQueueName
      }
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccountName
      }
      {
        name: 'AZURE_STORAGE_CONTAINER'
        value: storage.outputs.containerName
      }
    ]
  }
  dependsOn: [
    keyVault
  ]
}

// Outputs
output resourceGroupName string = resourceGroup.outputs.resourceGroupName
output managedIdentityId string = managedIdentity.outputs.managedIdentityId
output managedIdentityClientId string = managedIdentity.outputs.managedIdentityClientId
output sqlServerName string = sqlServer.outputs.sqlServerName
output sqlDatabaseName string = sqlServer.outputs.sqlDatabaseName
output serviceBusNamespaceName string = serviceBus.outputs.serviceBusNamespaceName
output serviceBusQueueName string = serviceBus.outputs.serviceBusQueueName
output storageAccountName string = storage.outputs.storageAccountName
output blobEndpoint string = storage.outputs.blobEndpoint
output containerName string = storage.outputs.containerName
output keyVaultName string = keyVault.outputs.keyVaultName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output containerAppUrl string = containerApps.outputs.containerAppUrl
