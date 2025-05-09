#!/bin/bash
# Azure Passwordless Workshop - Resource Deployment Tool
# This script deploys all required Azure resources for the passwordless authentication workshop

set -e

# Display script header
echo -e "\033[36m-----------------------------------------------------\033[0m"
echo -e "\033[36mAzure Passwordless Workshop - Resource Deployment Tool\033[0m"
echo -e "\033[36m-----------------------------------------------------\033[0m"
echo ""

# Check if the user is logged into Azure
ACCOUNT_INFO=$(az account show 2>/dev/null || echo '{"name": "", "id": ""}')
SUBSCRIPTION_NAME=$(echo $ACCOUNT_INFO | jq -r '.name')
SUBSCRIPTION_ID=$(echo $ACCOUNT_INFO | jq -r '.id')

if [ -z "$SUBSCRIPTION_ID" ] || [ "$SUBSCRIPTION_ID" == "null" ]; then
    echo -e "\033[33mYou are not logged into Azure. Please log in now...\033[0m"
    az login
    ACCOUNT_INFO=$(az account show)
    SUBSCRIPTION_NAME=$(echo $ACCOUNT_INFO | jq -r '.name')
    SUBSCRIPTION_ID=$(echo $ACCOUNT_INFO | jq -r '.id')
fi

echo -e "\033[32mConnected to subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)\033[0m"

# Prompt user for deployment information
read -p "Enter the resource group name (default: rg-passwordless-workshop): " resourceGroupName
resourceGroupName=${resourceGroupName:-"rg-passwordless-workshop"}

read -p "Enter the location (default: westeurope): " location
location=${location:-"westeurope"}

uniqueSuffix=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
echo -e "\033[33mGenerated unique suffix for resources: $uniqueSuffix\033[0m"

read -p "Enter the managed identity name (default: id-passwordless-workshop): " managedIdentityName
managedIdentityName=${managedIdentityName:-"id-passwordless-workshop"}

read -p "Enter the container registry name (default: crpasswordless$uniqueSuffix): " containerRegistryName
containerRegistryName=${containerRegistryName:-"crpasswordless$uniqueSuffix"}

read -p "Enter the SQL server name (default: sql-passwordless-$uniqueSuffix): " sqlServerName
sqlServerName=${sqlServerName:-"sql-passwordless-$uniqueSuffix"}

read -p "Enter the SQL database name (default: sqldb-passwordless-events): " sqlDatabaseName
sqlDatabaseName=${sqlDatabaseName:-"sqldb-passwordless-events"}

read -p "Enter the SQL administrator login (default: sqladmin): " sqlAdministratorLogin
sqlAdministratorLogin=${sqlAdministratorLogin:-"sqladmin"}

read -p "Enter the SQL administrator password: " -s sqlAdministratorLoginPassword
echo ""  # Add a line break after the password input

read -p "Enter the Service Bus namespace name (default: sb-passwordless-$uniqueSuffix): " serviceBusNamespaceName
serviceBusNamespaceName=${serviceBusNamespaceName:-"sb-passwordless-$uniqueSuffix"}

read -p "Enter the Redis cache name (default: redis-passwordless-$uniqueSuffix): " redisCacheName
redisCacheName=${redisCacheName:-"redis-passwordless-$uniqueSuffix"}

read -p "Enter the storage account name (default: stpasswordless$uniqueSuffix): " storageAccountName
storageAccountName=${storageAccountName:-"stpasswordless$uniqueSuffix"}

read -p "Enter the Key Vault name (default: kv-passwordless-$uniqueSuffix): " keyVaultName
keyVaultName=${keyVaultName:-"kv-passwordless-$uniqueSuffix"}

# New Container Apps parameters
read -p "Enter the Container Apps Environment name (default: env-passwordless-$uniqueSuffix): " containerAppsEnvironmentName
containerAppsEnvironmentName=${containerAppsEnvironmentName:-"env-passwordless-$uniqueSuffix"}

read -p "Enter the Container App name (default: app-passwordless-workshop): " containerAppName
containerAppName=${containerAppName:-"app-passwordless-workshop"}

read -p "Enter the container image name (default: docker.io/hello-world:latest): " containerImageName
containerImageName=${containerImageName:-"docker.io/hello-world:latest"}

# Check for resource name validity
if [ ${#storageAccountName} -gt 24 ]; then
    echo -e "\033[31mError: Storage account name must be less than 24 characters. Current length: ${#storageAccountName}\033[0m"
    exit 1
fi

# Create resource group
echo -e "\033[33mCreating resource group $resourceGroupName in $location...\033[0m"
az group create --name "$resourceGroupName" --location "$location"

# Validate bicep template
echo -e "\033[33mValidating bicep template...\033[0m"
az deployment sub validate \
    --name "validate-passwordless-workshop" \
    --location "$location" \
    --template-file "./infra/main.bicep" \
    --parameters \
        resourceGroupName="$resourceGroupName" \
        location="$location" \
        managedIdentityName="$managedIdentityName" \
        containerRegistryName="$containerRegistryName" \
        sqlServerName="$sqlServerName" \
        sqlDatabaseName="$sqlDatabaseName" \
        sqlAdministratorLogin="$sqlAdministratorLogin" \
        sqlAdministratorLoginPassword="$sqlAdministratorLoginPassword" \
        serviceBusNamespaceName="$serviceBusNamespaceName" \
        redisCacheName="$redisCacheName" \
        storageAccountName="$storageAccountName" \
        keyVaultName="$keyVaultName" \
        containerAppsEnvironmentName="$containerAppsEnvironmentName" \
        containerAppName="$containerAppName" \
        containerImageName="$containerImageName"

if [ $? -ne 0 ]; then
    echo -e "\033[31mBicep template validation failed. Please check the errors above.\033[0m"
    exit 1
fi

# Preview deployment (what-if)
echo -e "\033[33mPreviewing deployment changes (what-if)...\033[0m"
az deployment sub what-if \
    --name "preview-passwordless-workshop" \
    --location "$location" \
    --template-file "./infra/main.bicep" \
    --parameters \
        resourceGroupName="$resourceGroupName" \
        location="$location" \
        managedIdentityName="$managedIdentityName" \
        containerRegistryName="$containerRegistryName" \
        sqlServerName="$sqlServerName" \
        sqlDatabaseName="$sqlDatabaseName" \
        sqlAdministratorLogin="$sqlAdministratorLogin" \
        sqlAdministratorLoginPassword="$sqlAdministratorLoginPassword" \
        serviceBusNamespaceName="$serviceBusNamespaceName" \
        redisCacheName="$redisCacheName" \
        storageAccountName="$storageAccountName" \
        keyVaultName="$keyVaultName" \
        containerAppsEnvironmentName="$containerAppsEnvironmentName" \
        containerAppName="$containerAppName" \
        containerImageName="$containerImageName"

# Confirm deployment
read -p "Do you want to proceed with the deployment? (y/n): " confirmation
if [ "$confirmation" != "y" ]; then
    echo -e "\033[31mDeployment cancelled.\033[0m"
    exit 0
fi

# Deploy the bicep template
echo -e "\033[33mDeploying resources...\033[0m"
deploymentOutput=$(az deployment sub create \
    --name "deploy-passwordless-workshop" \
    --location "$location" \
    --template-file "./infra/main.bicep" \
    --parameters \
        resourceGroupName="$resourceGroupName" \
        location="$location" \
        managedIdentityName="$managedIdentityName" \
        containerRegistryName="$containerRegistryName" \
        sqlServerName="$sqlServerName" \
        sqlDatabaseName="$sqlDatabaseName" \
        sqlAdministratorLogin="$sqlAdministratorLogin" \
        sqlAdministratorLoginPassword="$sqlAdministratorLoginPassword" \
        serviceBusNamespaceName="$serviceBusNamespaceName" \
        redisCacheName="$redisCacheName" \
        storageAccountName="$storageAccountName" \
        keyVaultName="$keyVaultName" \
        containerAppsEnvironmentName="$containerAppsEnvironmentName" \
        containerAppName="$containerAppName" \
        containerImageName="$containerImageName")

if [ $? -ne 0 ]; then
    echo -e "\033[31mDeployment failed. Please check the errors above.\033[0m"
    exit 1
fi

# Show deployment summary
echo -e "\033[32mDeployment completed successfully!\033[0m"
echo ""
echo -e "\033[36mResource Information:\033[0m"
echo -e "\033[36m-------------------\033[0m"
echo "Resource Group: $resourceGroupName"
echo "Managed Identity: $managedIdentityName"
echo "Container Registry: $containerRegistryName"
echo "SQL Server: $sqlServerName"
echo "SQL Database: $sqlDatabaseName"
echo "Service Bus: $serviceBusNamespaceName"
echo "Redis Cache: $redisCacheName"
echo "Storage Account: $storageAccountName"
echo "Key Vault: $keyVaultName"
echo "Container Apps Environment: $containerAppsEnvironmentName"
echo "Container App: $containerAppName"

# Extract and display Container App URL if available
containerAppUrl=$(echo $deploymentOutput | jq -r '.properties.outputs.containerAppUrl.value // empty')
if [ ! -z "$containerAppUrl" ]; then
    echo "Container App URL: $containerAppUrl"
fi

echo ""
echo -e "\033[33mNext steps:\033[0m"
echo "1. Update your application configuration to use these resources"
echo "2. Grant your application access to the managed identity to enable passwordless access"
echo ""