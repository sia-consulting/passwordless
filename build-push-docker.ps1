#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $false)]
    [string]$acrName,

    [Parameter(Mandatory = $false)]
    [string]$imageName,
    
    [Parameter(Mandatory = $false)]
    [string]$imageTag
)

# Script to build and push Docker image to Azure Container Registry
$ErrorActionPreference = "Stop"

# Function to check if user is logged in to Azure
function Test-AzureLoggedIn {
    try {
        $account = az account show | ConvertFrom-Json
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if Docker is installed
function Test-DockerInstalled {
    try {
        $dockerVersion = docker --version
        Write-Host "Using Docker: $dockerVersion" -ForegroundColor Cyan
        return $true
    }
    catch {
        Write-Host "Docker not found. Will use 'az acr build' instead." -ForegroundColor Yellow
        return $false
    }
}

# Check if Azure CLI is installed
try {
    $azVersion = az version | ConvertFrom-Json
    Write-Host "Using Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Azure CLI not found. Please install Azure CLI before running this script." -ForegroundColor Red
    Write-Host "   Installation instructions: https://docs.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Red
    exit 1
}

# Check if user is logged in to Azure
if (-not (Test-AzureLoggedIn)) {
    Write-Host "You're not logged in to Azure. Please log in first." -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Azure login failed. Exiting script." -ForegroundColor Red
        exit 1
    }
}

# Interactive prompts for missing parameters
if (-not $acrName) {
    # List available ACRs for user to choose from
    Write-Host "Fetching available Azure Container Registries..." -ForegroundColor Cyan
    $registries = az acr list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" -o json | ConvertFrom-Json
    
    if ($registries.Count -eq 0) {
        Write-Host "❌ No Azure Container Registries found in your subscription." -ForegroundColor Red
        Write-Host "   Please create an Azure Container Registry before running this script." -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "Available Azure Container Registries:" -ForegroundColor Green
        for ($i = 0; $i -lt $registries.Count; $i++) {
            Write-Host "[$i] $($registries[$i].Name) (Resource Group: $($registries[$i].ResourceGroup), Location: $($registries[$i].Location))"
        }
        
        $selection = Read-Host "Enter the number of the ACR to use"
        if ($selection -match "^\d+$" -and [int]$selection -ge 0 -and [int]$selection -lt $registries.Count) {
            $acrName = $registries[[int]$selection].Name
        }
        else {
            Write-Host "❌ Invalid selection. Exiting script." -ForegroundColor Red
            exit 1
        }
    }
}

if (-not $imageName) {
    $imageName = Read-Host "Enter image name [default: passwordless-workshop]"
    if (-not $imageName) {
        $imageName = "passwordless-workshop"
    }
}

if (-not $imageTag) {
    $imageTag = Read-Host "Enter image tag [default: latest]"
    if (-not $imageTag) {
        $imageTag = "latest"
    }
}

# Variables
$fullImageName = "$acrName.azurecr.io/$imageName`:$imageTag"
$srcPath = "src"
$apiPath = "src/PasswordlessWorkshop.Api"
$dockerfilePath = "$apiPath/Dockerfile"

Write-Host "🔨 Building Docker image: $fullImageName" -ForegroundColor Cyan
Write-Host "Context path: $srcPath"
Write-Host "Dockerfile path: $dockerfilePath"

try {
    # Check if ACR exists
    $acrExists = az acr show --name $acrName --query "name" -o tsv 2>$null
    if (-not $acrExists) {
        throw "Container Registry '$acrName' does not exist. Please check the name and try again."
    }
    
    # Login to ACR
    Write-Host "🔑 Logging in to Azure Container Registry: $acrName" -ForegroundColor Cyan
    az acr login --name $acrName
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to log in to Container Registry. Please ensure you have proper permissions."
    }
    
    # Check if Docker is installed
    $dockerInstalled = Test-DockerInstalled
    
    if ($dockerInstalled) {
        # Use Docker to build and push
        Write-Host "🏗️ Building Docker image using local Docker..." -ForegroundColor Cyan
        docker build -t $fullImageName -f $dockerfilePath $srcPath
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build Docker image."
        }
        
        Write-Host "📤 Pushing Docker image to ACR..." -ForegroundColor Cyan
        docker push $fullImageName
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push Docker image to ACR."
        }
    }
    else {
        # Use Azure CLI to build and push
        Write-Host "🏗️ Building and pushing Docker image using 'az acr build'..." -ForegroundColor Cyan
        az acr build --registry $acrName --image "$imageName`:$imageTag" --file $dockerfilePath $srcPath
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build and push Docker image using 'az acr build'."
        }
    }

    Write-Host "✅ Successfully built and pushed Docker image: $fullImageName" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}