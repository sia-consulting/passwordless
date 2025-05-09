@description('The name of the Service Bus namespace')
param serviceBusNamespaceName string

@description('The location for the Service Bus namespace')
param location string

@description('The SKU of the Service Bus namespace')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('The name of the Service Bus queue')
param queueName string = 'notifications'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: skuName
    tier: skuName
  }
  properties: {
    disableLocalAuth: false
    zoneRedundant: false
    minimumTlsVersion: '1.2'
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  parent: serviceBusNamespace
  name: queueName
  properties: {
    lockDuration: 'PT1M' // 1 minute
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D' // 14 days
    deadLetteringOnMessageExpiration: true
    duplicateDetectionHistoryTimeWindow: 'PT10M' // 10 minutes
    maxDeliveryCount: 10
    enableBatchedOperations: true
    enablePartitioning: false
  }
}

output serviceBusNamespaceName string = serviceBusNamespace.name
output serviceBusNamespaceId string = serviceBusNamespace.id
output serviceBusQueueName string = serviceBusQueue.name
output serviceBusQueueId string = serviceBusQueue.id
output serviceBusEndpoint string = serviceBusNamespace.properties.serviceBusEndpoint
