#!/bin/bash

# Script to build and push Docker image to Azure Container Registry using Docker commands
# with fallback to az acr build if Docker is not installed

# Exit on error
set -e

# Default values
IMAGE_NAME=""
IMAGE_TAG=""
ACR_NAME=""

# Display help
function show_help {
  echo "Usage: $0 [-a <acr_name>] [-i <image_name>] [-t <image_tag>]"
  echo ""
  echo "Options:"
  echo "  -a    Azure Container Registry name"
  echo "  -i    Image name"
  echo "  -t    Image tag"
  echo "  -h    Show this help message"
  exit 1
}

# Parse arguments
while getopts "a:i:t:h" opt; do
  case $opt in
    a) ACR_NAME="$OPTARG";;
    i) IMAGE_NAME="$OPTARG";;
    t) IMAGE_TAG="$OPTARG";;
    h) show_help;;
    \?) echo "Invalid option -$OPTARG" >&2; show_help;;
  esac
done

# Function to check if Docker is installed
function check_docker_installed {
  if command -v docker &> /dev/null; then
    echo "Using Docker: $(docker --version)"
    return 0
  else
    echo "Docker not found. Will use 'az acr build' instead."
    return 1
  fi
}

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please install Azure CLI before running this script."
    echo "   Installation instructions: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in to Azure
if ! az account show &> /dev/null; then
    echo "You're not logged in to Azure. Please log in first."
    az login
    if [ $? -ne 0 ]; then
        echo "❌ Azure login failed. Exiting script."
        exit 1
    fi
fi

# Interactive prompts for missing parameters
if [ -z "$ACR_NAME" ]; then
    # List available ACRs for user to choose from
    echo "Fetching available Azure Container Registries..."
    REGISTRIES=$(az acr list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" -o json)
    REG_COUNT=$(echo $REGISTRIES | jq '. | length')
    
    if [ "$REG_COUNT" -eq "0" ]; then
        echo "❌ No Azure Container Registries found in your subscription."
        echo "   Please create an Azure Container Registry before running this script."
        exit 1
    else
        echo "Available Azure Container Registries:"
        index=0
        while read -r reg_name rg location; do
            echo "[$index] $reg_name (Resource Group: $rg, Location: $location)"
            ((index++))
        done < <(echo $REGISTRIES | jq -r '.[] | "\(.Name) \(.ResourceGroup) \(.Location)"')
        
        read -p "Enter the number of the ACR to use: " SELECTION
        if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -lt "$REG_COUNT" ]; then
            ACR_NAME=$(echo $REGISTRIES | jq -r ".[$SELECTION].Name")
        else
            echo "❌ Invalid selection. Exiting script."
            exit 1
        fi
    fi
fi

if [ -z "$IMAGE_NAME" ]; then
    read -p "Enter image name [default: passwordless-workshop]: " IMAGE_NAME
    if [ -z "$IMAGE_NAME" ]; then
        IMAGE_NAME="passwordless-workshop"
    fi
fi

if [ -z "$IMAGE_TAG" ]; then
    read -p "Enter image tag [default: latest]: " IMAGE_TAG
    if [ -z "$IMAGE_TAG" ]; then
        IMAGE_TAG="latest"
    fi
fi

# Variables
FULL_IMAGE_NAME="$ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG"
SRC_PATH="src"
API_PATH="src/PasswordlessWorkshop.Api"
DOCKERFILE_PATH="$API_PATH/Dockerfile"

echo "🔨 Building Docker image: $FULL_IMAGE_NAME"
echo "Context path: $SRC_PATH"
echo "Dockerfile path: $DOCKERFILE_PATH"

# Check if ACR exists
if ! az acr show --name "$ACR_NAME" &> /dev/null; then
    echo "❌ Container Registry '$ACR_NAME' does not exist. Please check the name and try again."
    exit 1
fi

# Login to ACR
echo "🔑 Logging in to Azure Container Registry: $ACR_NAME"
az acr login --name "$ACR_NAME" || { echo "❌ Failed to log in to Container Registry. Please ensure you have proper permissions."; exit 1; }

# Check if Docker is installed
if check_docker_installed; then
    # Use Docker to build and push
    echo "🏗️ Building Docker image using local Docker..."
    docker build -t "$FULL_IMAGE_NAME" -f "$DOCKERFILE_PATH" "$SRC_PATH" || { echo "❌ Failed to build Docker image."; exit 1; }
    
    echo "📤 Pushing Docker image to ACR..."
    docker push "$FULL_IMAGE_NAME" || { echo "❌ Failed to push Docker image to ACR."; exit 1; }
else
    # Use Azure CLI to build and push
    echo "🏗️ Building and pushing Docker image using 'az acr build'..."
    az acr build --registry "$ACR_NAME" --image "$IMAGE_NAME:$IMAGE_TAG" --file "$DOCKERFILE_PATH" "$SRC_PATH" || { echo "❌ Failed to build and push Docker image."; exit 1; }
fi

echo "✅ Successfully built and pushed Docker image: $FULL_IMAGE_NAME"