@description('The name of the Key Vault')
param keyVaultName string

@description('The location for the Key Vault')
param location string

@description('User assigned managed identity principal ID to grant access to Key Vault')
param managedIdentityPrincipalId string

@description('SQL Server connection string')
@secure()
param sqlConnectionString string

@description('Service Bus connection string')
@secure()
param serviceBusConnectionString string

@description('Storage Account connection string')
@secure()
param storageConnectionString string

var secretsOfficerRoleId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User role ID

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Enabled'
  }
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(keyVault.id, managedIdentityPrincipalId, secretsOfficerRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsOfficerRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SqlConnectionString'
  properties: {
    value: sqlConnectionString
  }
}

resource serviceBusConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'ServiceBusConnectionString'
  properties: {
    value: serviceBusConnectionString
  }
}

resource storageConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'StorageConnectionString'
  properties: {
    value: storageConnectionString
  }
}

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
