@description('The name of the Redis Cache')
param redisCacheName string

@description('The location for the Redis Cache')
param location string

@description('The SKU family for the Redis Cache')
@allowed([
  'C' // Basic/Standard
  'P' // Premium
])
param skuFamily string = 'C'

@description('The SKU name for the Redis Cache')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('The capacity of the Redis Cache')
@allowed([
  0 // 250MB (Shared)
  1 // 1GB
  2 // 2.5GB
  3 // 6GB
  4 // 13GB
  5 // 26GB
  6 // 53GB
])
param capacity int = 1

resource redisCache 'Microsoft.Cache/redis@2022-06-01' = {
  name: redisCacheName
  location: location
  properties: {
    sku: {
      name: skuName
      family: skuFamily
      capacity: capacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

output redisCacheName string = redisCache.name
output redisCacheId string = redisCache.id
output redisCacheHostName string = redisCache.properties.hostName
