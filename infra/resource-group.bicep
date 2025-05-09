targetScope = 'subscription'

@description('The name of the resource group to create')
param resourceGroupName string

@description('The location for the resource group')
param location string = 'westeurope'

@description('Tags for the resource group')
param tags object = {
  environment: 'workshop'
  purpose: 'passwordless-demo'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
output rg resource = resourceGroup
