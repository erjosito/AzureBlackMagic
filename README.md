# Azure Black Magic Training

## ARM Templates Cheat Sheet
rg="myapp"
url="https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/genericLinuxVM-templ.json"
location=centralus
parameters='{"adminUsername": {"value": "jose"}, "adminPassword": {"value": "Microsoft123!"}}'
az group create -n $rg -l $location
az group deployment create -g $rg -n myDeployment --template-uri $url --parameters $parameters 
