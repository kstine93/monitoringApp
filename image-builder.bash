#!/bin/bash

#---------------------
#----- OVERVIEW ------
#This code is for rapidly building and uploading new Docker images to Azure Container Registry
#See these instructions for pushing a local Docker image to an Azure Container Registry:
#https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli?tabs=azure-cli

# ARGUMENTS:
# $1 == path to local directory with Dockerfile
# $2 == desired name of produced image

# EXAMPLE USAGE:
# bash image-builder.bash ./local-dir/other_dir my-image-name:latest
# This will access the path './local-dir/other_dir' where the script expects to find a Dockerfile.
# It will then attempt to build this Dockerfile and name it "my-image-name".
#---------------------

#Ensuring we have 2 arguments provided:
hardexit () {
    echo >&2 "$@"
    exit 1
}
[ "$#" -eq 2 ] || hardexit "2 arguments required, $# provided - see script for documentation."

#Making the rest of the code exit in case of error:
set -e

#Building local variables
LOCALPATH=$1
IMAGENAME=$2
AZUREREGISTRY=my-registry
DOCKERTAG="$AZUREREGISTRY".azurecr.io/bi-monitoring/"$IMAGENAME"

#Building image
cd $LOCALPATH
docker build --no-cache --rm -t $IMAGENAME .

#Authenticating with Azure
az acr login --name $AZUREREGISTRY

#Tagging Docker image
docker tag $IMAGENAME $DOCKERTAG

#Pushing to Azure Container Registry
docker push $DOCKERTAG

#Cleaning up Docker images:
docker rmi $DOCKERTAG

#Uncomment this line to delete all dangling Docker images from your Docker environment:
# docker rmi $(docker images --filter "dangling=true" -q --no-trunc)