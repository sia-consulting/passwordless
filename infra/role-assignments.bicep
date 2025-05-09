@description('The principal ID of the managed identity')
param managedIdentityPrincipalId string

@description('The ID of the SQL Server')
param sqlServerId string

@description('The ID of the Storage Account')
param storageAccountId string

@description('The ID of the Service Bus namespace')
param serviceBusNamespaceId string

@description('The ID of the Container Registry')
param containerRegistryId string

// Role definition IDs (built-in Azure roles)
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var serviceBusDataOwnerRoleId = '090c5cfd-751d-490a-894a-3ce6f1109419'
var sqlDbContributorRoleId = '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountId
}

// Role assignments for Storage Account - Blob Data Contributor
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(storageAccountId, managedIdentityPrincipalId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusNamespaceId
}

// Role assignment for Service Bus namespace - Service Bus Data Owner
resource serviceBusRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(serviceBusNamespaceId, managedIdentityPrincipalId, serviceBusDataOwnerRoleId)
  scope: serviceBus
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataOwnerRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' existing = {
  name: sqlServerId
}

// Role assignment for SQL Server - SQL DB Contributor
resource sqlRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(sqlServerId, managedIdentityPrincipalId, sqlDbContributorRoleId)
  scope: sqlServer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sqlDbContributorRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: containerRegistryId
}

// Role assignment for Azure Container Registry - ACR Pull
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(containerRegistryId, managedIdentityPrincipalId, acrPullRoleId)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output storageRoleAssignmentId string = storageRoleAssignment.id
output serviceBusRoleAssignmentId string = serviceBusRoleAssignment.id
output sqlRoleAssignmentId string = sqlRoleAssignment.id
output acrRoleAssignmentId string = acrRoleAssignment.id
