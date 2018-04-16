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
avset="myavset"
az vm availability-set create -g $rg -n $avset
az vm create -g $rg -n $vmname --image centos --availability-set $avset\
             --admin-username $username --admin-password $password --authentication-type password\
             --data-disk-sizes-gb $datadisks --os-disk-size 32 --size Standard_DS1_v2 \
             --vnet-name $vmname-vnet --vnet-address-prefix $vnetprefix --subnet default --subnet-address-prefix $subnetprefix \
             --public-ip-address $vmname-pip --nsg $vmname-nsg
```

Add a custom script extension to the VM (note that creating the VM with the --custom-data parameter would be a more compact way, but you need to have the file locally):

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

## CLI Cheat Sheet

Define some variables, including credentials retrieved from a key vault:

```
$resGrp = 'mytestw2016'
$loc = 'westeurope' 
$vnetName = 'mynew-vnet'
$vnetPrefix = '10.0.0.0/16'
$subnetName = 'mysubnet'
$subnetPrefix = '10.0.1.0/24'
$vmsize='Standard_A0'
$vmName = 'myw2016-01'
$nsgName = $vmName + '-nsg'
$pipName = $vmName + '-pip'
$avSetName = $vmName + '-avset'
$adminUserName = "jose"
#$adminPassword = "mySuperSecretPassword" | ConvertTo-SecureString -AsPlainText -Force
$adminPassword = (Get-AzureKeyVaultSecret –VaultName 'myKeyVault' -Name myPassword).SecretValueText | `
                  ConvertTo-SecureString -AsPlainText -Force
$adminCred = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)
```

Create a Windows VM:

```
New-AzureRmVm `
    -ResourceGroupName $resGrp `
    -Name $vmName `
    -ImageName Win2016Datacenter `
    -Location $loc `
    -VirtualNetworkName $vnetName `
    -AddressPrefix $vnetPrefix `
    -SubnetName $subnetName `
    -subnetaddressprefix $subnetPrefix `
    -SecurityGroupName $nsgName `
    -OpenPorts 80,3389 `
    -PublicIpAddressName $pipName `
    -Credential $adminCred
```

Add data disks:

```
$dataDiskSize = 127
$dataDiskNumber = 3
$vm = get-azurermvm -ResourceGroupName $resGrp -Name $vmName
for ($i=1; $i -le $dataDiskNumber; $i++) {
  $diskName = $vmname + '-disk' + $i
  Add-AzureRmVMDataDisk -VM $vm -Name $diskName -DiskSizeInGB $dataDiskSize -Caching ReadWrite -CreateOption Empty -Lun $i
}
Update-AzureRmVM -ResourceGroupName $resGrp -VM $vm
```

Add custom script extension:

```
$baseUrl = 'https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/'
$script = 'windowsConfig.ps1'
$scriptUrl = $baseUrl + $script
set-azurermvmcustomscriptextension -resourcegroupname $resGrp `
                                   -VMName $vmName `
                                   -Location $loc `
                                   -FileUri $scriptUrl `
                                   -Run $script `
                                   -Name DemoScriptExtension
```
