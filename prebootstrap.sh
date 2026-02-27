#!/usr/bin/env bash
set -e

RG_NAME=$1
SA_NAME=$2
CONTAINER_NAME=$3
LOCATION=${4:-eastus}

# Create Resource Group if not exists
if ! az group show -n "$RG_NAME" >/dev/null 2>&1; then
  echo "Creating Resource Group $RG_NAME"
  az group create -n "$RG_NAME" -l "$LOCATION" >/dev/null
fi

# Find Storage Account in any resource group
EXISTING_RG=$(az storage account list --query "[?name=='$SA_NAME'].resourceGroup" -o tsv 2>/dev/null)

if [ -n "$EXISTING_RG" ]; then
  echo "Storage Account $SA_NAME found in resource group: $EXISTING_RG"
  if [ "$EXISTING_RG" != "$RG_NAME" ]; then
    echo "WARNING: Storage account exists in different resource group ($EXISTING_RG) than expected ($RG_NAME)"
    echo "Using existing resource group: $EXISTING_RG"
    RG_NAME="$EXISTING_RG"
  fi
else
  echo "Storage Account $SA_NAME not found, attempting to create in resource group $RG_NAME..."
  if az storage account create -n "$SA_NAME" -g "$RG_NAME" -l "$LOCATION" \
    --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false >/dev/null 2>&1; then
    echo "Successfully created Storage Account $SA_NAME"
  else
    echo "Failed to create Storage Account $SA_NAME - name may be globally taken"
    exit 1
  fi
fi

# Get Account Key
ACCOUNT_KEY=$(az storage account keys list -n "$SA_NAME" -g "$RG_NAME" --query '[0].value' -o tsv)

# Create Container if not exists
if ! az storage container show -n "$CONTAINER_NAME" --account-name "$SA_NAME" --account-key "$ACCOUNT_KEY" >/dev/null 2>&1; then
  echo "Creating Container $CONTAINER_NAME"
  az storage container create -n "$CONTAINER_NAME" --account-name "$SA_NAME" --account-key "$ACCOUNT_KEY" >/dev/null
fi

echo "Backend ready: rg=$RG_NAME sa=$SA_NAME container=$CONTAINER_NAME"