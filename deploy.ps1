#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Azure resources for the passwordless workshop using Bicep templates.
.DESCRIPTION
    This script deploys all required Azure resources for the passwordless authentication workshop
    including resource group, managed identity, SQL server, Redis, Service Bus, Storage Account, 
    Key Vault, Container Registry, and Container Apps with proper RBAC assignments.
.EXAMPLE
    ./deploy.ps1
#>

# Display script header
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
Write-Host "Azure Passwordless Workshop - Resource Deployment Tool" -ForegroundColor Cyan
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Check if the user is logged into Azure using az cli
$accountInfo = $null
try {
    $accountInfo = (az account show | ConvertFrom-Json)
}
catch {
    Write-Host "You are not logged into Azure. Please log in now..." -ForegroundColor Yellow
    az login
    $accountInfo = (az account show | ConvertFrom-Json)
}

Write-Host "Connected to subscription: $($accountInfo.name) ($($accountInfo.id))" -ForegroundColor Green

# Prompt user for deployment information
$resourceGroupName = Read-Host -Prompt "Enter the resource group name (default: rg-passwordless-workshop)"
if ([string]::IsNullOrEmpty($resourceGroupName)) {
    $resourceGroupName = "rg-passwordless-workshop"
}

$location = Read-Host -Prompt "Enter the location (default: westeurope)"
if ([string]::IsNullOrEmpty($location)) {
    $location = "westeurope"
}

$uniqueSuffix = -join ((48..57) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
Write-Host "Generated unique suffix for resources: $uniqueSuffix" -ForegroundColor Yellow

$managedIdentityName = Read-Host -Prompt "Enter the managed identity name (default: id-passwordless-workshop)"
if ([string]::IsNullOrEmpty($managedIdentityName)) {
    $managedIdentityName = "id-passwordless-workshop"
}

$containerRegistryName = Read-Host -Prompt "Enter the container registry name (default: crpasswordless$uniqueSuffix)"
if ([string]::IsNullOrEmpty($containerRegistryName)) {
    $containerRegistryName = "crpasswordless$uniqueSuffix"
}

$sqlServerName = Read-Host -Prompt "Enter the SQL server name (default: sql-passwordless-$uniqueSuffix)"
if ([string]::IsNullOrEmpty($sqlServerName)) {
    $sqlServerName = "sql-passwordless-$uniqueSuffix"
}

$sqlDatabaseName = Read-Host -Prompt "Enter the SQL database name (default: sqldb-passwordless-events)"
if ([string]::IsNullOrEmpty($sqlDatabaseName)) {
    $sqlDatabaseName = "sqldb-passwordless-events"
}

$sqlAdministratorLogin = Read-Host -Prompt "Enter the SQL administrator login (default: sqladmin)"
if ([string]::IsNullOrEmpty($sqlAdministratorLogin)) {
    $sqlAdministratorLogin = "sqladmin"
}

# Using Azure CLI to prompt for password securely
$sqlAdministratorLoginPassword = Read-Host -Prompt "Enter the SQL administrator password" -AsSecureString
$sqlAdminPasswordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlAdministratorLoginPassword))

$serviceBusNamespaceName = Read-Host -Prompt "Enter the Service Bus namespace name (default: sb-passwordless-$uniqueSuffix)"
if ([string]::IsNullOrEmpty($serviceBusNamespaceName)) {
    $serviceBusNamespaceName = "sb-passwordless-$uniqueSuffix"
}

$redisCacheName = Read-Host -Prompt "Enter the Redis cache name (default: redis-passwordless-$uniqueSuffix)"
if ([string]::IsNullOrEmpty($redisCacheName)) {
    $redisCacheName = "redis-passwordless-$uniqueSuffix"
}

$storageAccountName = Read-Host -Prompt "Enter the storage account name (default: stpasswordless$uniqueSuffix)"
if ([string]::IsNullOrEmpty($storageAccountName)) {
    $storageAccountName = "stpasswordless$uniqueSuffix"
}

$keyVaultName = Read-Host -Prompt "Enter the Key Vault name (default: kv-passwordless-$uniqueSuffix)"
if ([string]::IsNullOrEmpty($keyVaultName)) {
    $keyVaultName = "kv-passwordless-$uniqueSuffix"
}

# New Container Apps parameters
$containerAppsEnvironmentName = Read-Host -Prompt "Enter the Container Apps Environment name (default: env-passwordless-$uniqueSuffix)"
if ([string]::IsNullOrEmpty($containerAppsEnvironmentName)) {
    $containerAppsEnvironmentName = "env-passwordless-$uniqueSuffix"
}

$containerAppName = Read-Host -Prompt "Enter the Container App name (default: app-passwordless-workshop)"
if ([string]::IsNullOrEmpty($containerAppName)) {
    $containerAppName = "app-passwordless-workshop"
}

$containerImageName = Read-Host -Prompt "Enter the container image name (default: docker.io/hello-world:latest)"
if ([string]::IsNullOrEmpty($containerImageName)) {
    $containerImageName = "docker.io/hello-world:latest"
}

# Check for resource name validity
if ($storageAccountName.Length -gt 24) {
    Write-Host "Error: Storage account name must be less than 24 characters. Current length: $($storageAccountName.Length)" -ForegroundColor Red
    exit 1
}

# Create resource group
Write-Host "Creating resource group $resourceGroupName in $location..." -ForegroundColor Yellow
az group create --name $resourceGroupName --location $location

# Validate bicep template
Write-Host "Validating bicep template..." -ForegroundColor Yellow
$validationResult = az deployment sub validate `
    --name "validate-passwordless-workshop" `
    --location $location `
    --template-file ./infra/main.bicep `
    --parameters `
    resourceGroupName=$resourceGroupName `
    location=$location `
    managedIdentityName=$managedIdentityName `
    containerRegistryName=$containerRegistryName `
    sqlServerName=$sqlServerName `
    sqlDatabaseName=$sqlDatabaseName `
    sqlAdministratorLogin=$sqlAdministratorLogin `
    sqlAdministratorLoginPassword=$sqlAdminPasswordPlainText `
    serviceBusNamespaceName=$serviceBusNamespaceName `
    redisCacheName=$redisCacheName `
    storageAccountName=$storageAccountName `
    keyVaultName=$keyVaultName `
    containerAppsEnvironmentName=$containerAppsEnvironmentName `
    containerAppName=$containerAppName `
    containerImageName=$containerImageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "Bicep template validation failed. Please check the errors above." -ForegroundColor Red
    exit 1
}

# Preview deployment (what-if)
Write-Host "Previewing deployment changes (what-if)..." -ForegroundColor Yellow
az deployment sub what-if `
    --name "preview-passwordless-workshop" `
    --location $location `
    --template-file ./infra/main.bicep `
    --parameters `
    resourceGroupName=$resourceGroupName `
    location=$location `
    managedIdentityName=$managedIdentityName `
    containerRegistryName=$containerRegistryName `
    sqlServerName=$sqlServerName `
    sqlDatabaseName=$sqlDatabaseName `
    sqlAdministratorLogin=$sqlAdministratorLogin `
    sqlAdministratorLoginPassword=$sqlAdminPasswordPlainText `
    serviceBusNamespaceName=$serviceBusNamespaceName `
    redisCacheName=$redisCacheName `
    storageAccountName=$storageAccountName `
    keyVaultName=$keyVaultName `
    containerAppsEnvironmentName=$containerAppsEnvironmentName `
    containerAppName=$containerAppName `
    containerImageName=$containerImageName

# Confirm deployment
$confirmation = Read-Host -Prompt "Do you want to proceed with the deployment? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "Deployment cancelled." -ForegroundColor Red
    exit 0
}

# Deploy the bicep template
Write-Host "Deploying resources..." -ForegroundColor Yellow
$deploymentOutput = az deployment sub create `
    --name "deploy-passwordless-workshop" `
    --location $location `
    --template-file ./infra/main.bicep `
    --parameters `
    resourceGroupName=$resourceGroupName `
    location=$location `
    managedIdentityName=$managedIdentityName `
    containerRegistryName=$containerRegistryName `
    sqlServerName=$sqlServerName `
    sqlDatabaseName=$sqlDatabaseName `
    sqlAdministratorLogin=$sqlAdministratorLogin `
    sqlAdministratorLoginPassword=$sqlAdminPasswordPlainText `
    serviceBusNamespaceName=$serviceBusNamespaceName `
    redisCacheName=$redisCacheName `
    storageAccountName=$storageAccountName `
    keyVaultName=$keyVaultName `
    containerAppsEnvironmentName=$containerAppsEnvironmentName `
    containerAppName=$containerAppName `
    containerImageName=$containerImageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "Deployment failed. Please check the errors above." -ForegroundColor Red
    exit 1
}

# Show deployment summary
$deployment = $deploymentOutput | ConvertFrom-Json
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Resource Information:" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroupName" 
Write-Host "Managed Identity: $managedIdentityName"
Write-Host "Container Registry: $containerRegistryName"
Write-Host "SQL Server: $sqlServerName"
Write-Host "SQL Database: $sqlDatabaseName"
Write-Host "Service Bus: $serviceBusNamespaceName"
Write-Host "Redis Cache: $redisCacheName"
Write-Host "Storage Account: $storageAccountName"
Write-Host "Key Vault: $keyVaultName"
Write-Host "Container Apps Environment: $containerAppsEnvironmentName"
Write-Host "Container App: $containerAppName"
if ($deployment.properties.outputs.containerAppUrl) {
    Write-Host "Container App URL: $($deployment.properties.outputs.containerAppUrl.value)"
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Update your application configuration to use these resources"
Write-Host "2. Grant your application access to the managed identity to enable passwordless access"
Write-Host ""