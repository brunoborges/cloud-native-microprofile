#!/bin/sh
RESOURCE_GROUP=microprofileResourceGroup
LOCATION=westus
ACR_NAME=microprofileRegistry
MP_SPEAKER=my-mp-speaker
MP_CONF=my-mp-conference

# Install Azure CLI
brew install azure-cli

# Login
az login

# Criar resource group
az group create -n $RESOURCE_GROUP -l $LOCATION

### AZURE CONTAINER REGISTRY

# Create a private container image registry
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

# Logins Docker CLI to private repo (allowing docker pull/push)
az acr login -g $RESOURCE_GROUP --name $ACR_NAME

# ACR Show
az acr show --name $ACR_NAME -g $RESOURCE_GROUP --query loginServer
az acr show --name $ACR_NAME -g $RESOURCE_GROUP --query loginServer --output table

# ACR Show Images
az acr repository list --name $ACR_NAME -g $RESOURCE_GROUP --output table

# ACR Show Credentials for docker CLI
az acr credential show --name $ACR_NAME -g $RESOURCE_GROUP --query "passwords[0].value" -o tsv > acr_password

### AZURE CONTAINER INSTANCES
# Create Container Instance for MicroProfile Speaker service
az container create -g $RESOURCE_GROUP --name $MP_SPEAKER \
   --image $ACR_NAME.azurecr.io/$(Build.Repository.Name)/microprofile-speaker:$(Build.BuildId) --cpu 1 --memory 1 \
   --registry-username $ACR_NAME --registry-password `cat acr_password` \
   --dns-name-label $MP_SPEAKER --ports 8080 9991

az container create -g $RESOURCE_GROUP --name $MP_CONF \
   --image $ACR_NAME.azurecr.io/$(Build.Repository.Name)/microprofile-conference:$(Build.BuildId) --cpu 1 --memory 1 \
   --registry-username $ACR_NAME --registry-password `cat acr_password` \
   --dns-name-label $MP_CONF --ports 8081 9991 \
   --environment-variables SPEAKER_SERVICE=http://$MP_SPEAKER.$LOCATION.azurecontainer.io:8080/speakers

# Container show
az container show -g $RESOURCE_GROUP --name $MP_CONF --query instanceView.state
az container show -g $RESOURCE_GROUP --name $MP_SPEAKER --query instanceView.state

# Container get IP
az container show -g $RESOURCE_GROUP --name $MP_CONF --query ipAddress.fqdn
az container show -g $RESOURCE_GROUP --name $MP_SPEAKER --query ipAddress.fqdn

# Container logs
az container logs -g $RESOURCE_GROUP --name $MP_CONF
az container logs -g $RESOURCE_GROUP --name $MP_SPEAKER

# Delete Speaker container
az container delete -g $RESOURCE_GROUP --name mp-speaker

# DELETE EVERYTHING
az group delete --name $RESOURCE_GROUP
