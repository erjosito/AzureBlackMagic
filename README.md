# Azure Black Magic Training

## ARM Templates Cheat Sheet
rg="myapp"
url="https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/genericLinuxVM-templ.json"
location=centralus
password="mySuperSecretPassword1!"
password=$(az keyvault secret show --vault-name myAzureKeyvault -n mySecretName --query "value" -o tsv)
az group create -n $rg -l $location
az group deployment create -g $rg -n myDeployment --template-uri $url --parameters '{"adminUsername": {"value": "jose"}, "adminPassword": {"value": "$password"}}' 
