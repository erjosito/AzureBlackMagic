# Variables
subscriptionId=e7da9914-9b05-4891-893c-546cb7b0422e 
rgName=blackmagictest
location=centralus

# Login and select subscription
az login
az account set -s $subscriptionId

# Create resource group
az group create -n $rgName -l $location

# Create Linux VM
az vm create -g $rgname