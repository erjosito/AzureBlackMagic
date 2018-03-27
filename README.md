# Azure Black Magic Training

## ARM Templates Cheat Sheet

Create a resource group:

```
rg="myapp"
location=centralus
az group create -n $rg -l $location
```

Create a virtual machine:

```
url="https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/genericLinuxVM-templ.json"
username=john
password=$(az keyvault secret show --vault-name myAzureKeyvault -n mySecretName --query "value" -o tsv)
az group deployment create -g $rg -n myDeployment --template-uri $url --parameters "{'adminUsername': {'value': '$username'}, 'adminPassword': {'value': '$password'}}"
```

## CLI Cheat Sheet

Create a resource group:

```
rg="myapp2"
location=centralus
az group create -n $rg -l $location
```

Create a virtual machine:

```
username="john"
password=$(az keyvault secret show --vault-name myAzureKeyvault -n mySecretName --query "value" -o tsv)
vmname="vm02"
datadisks="127 127 127"
vnetprefix="10.0.0.0/16"
subnetprefix="10.0.1.0/24"
az vm create -g $rg -n $vmname --image centos \
             --admin-username $username --admin-password $password --authentication-type password\
             --data-disk-sizes-gb $datadisks --os-disk-size 32 --size Standard_DS1_v2 \
             --vnet-name $vmname-vnet --vnet-address-prefix $vnetprefix --subnet default --subnet-address-prefix $subnetprefix \
             --public-ip-address $vmname-pip --nsg $vmname-nsg
```

Add a custom script extension to the VM:

```
scripturl="https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/centosConfig.sh"
scriptcmd="chmod 666 ./centosConfig.sh && /bin/sh ./centosConfig.sh"
az vm extension set \
  --resource-group $rg \
  --vm-name $vmname \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --settings "{'fileUris': ['$scripturl'],'commandToExecute': '$scriptcmd'}"
```
