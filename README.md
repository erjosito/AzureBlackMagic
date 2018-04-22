# Single-VM Deployments

This repo has mulitple examples about how to automatically deploy Windows and Linux VMs following different frameworks. The goal is showing working examples for each of those, so that they can be used as basis to build your own solution.

The first category of examples show how to deploy single VMs over ARM templates, Azure CLI, Powershell and Terraform. These examples are easily extensible to build single-Tier, multi-VM deployments, or even multi-tier/VM deployments, since the concepts are identical.

Note that in most of the cases no passwords are hard-coded, but they are read out of an Azure Key Vault.

## ARM Template for Ubuntu/Centos VM

This template deploys a Centos or Ubuntu VM (configured via ARM template parameters) in an availability set with a load balancer in front, and over a Custom Script Extension the following actions are executed:

* All data disks are grouped into a RAID0 and mounted
* Changes are reboot-persistent
* httpd and php are installed
* A web page is downloaded

Before deploying the template you need to create a resource group:

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

## Azure CLI for Centos VM

These commands deploy a Centos VM in an availability set, and over a Custom Script Extension the following actions are executed:

* All data disks are grouped into a RAID0 and mounted
* Changes are reboot-persistent
* httpd and php are installed
* A web page is downloaded

As usual, the first step is to create a resource group:

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

## PowerShell for Windows VM

These commands deploy a Windows VM in an availability set, and over a Custom Script Extension the following actions are executed:

* All data disks are joined into a virtual disk, partitioned and mounted to a drive
* IIS role is activated
* Chocolatey is installed
* PHP is installed over Chocolatey
* IIS is configured to use PHP
* A web page is downloaded

The first step is to define some variables, including credentials retrieved from a key vault:

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

## Terraform

In order to deploy the terraform configuration, you need to download [this file](https://github.com/erjosito/AzureBlackMagic/blob/master/terraform/linuxvm/linuxvm.tf) to a system with Terraform installed. The recommendation is using Azure Cloud Shell, since Terraform is already pre-installed and you do not need to modify the configuration files with your Azure credentials:

```
mdkir terraformtest
cd terraformtest
wget https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/terraform/linuxvm/linuxvm.tf
terraform init
terraform plan
terraform apply
```


# Multi-Tier Deployments

The scripts in the [Custom Script Extensions folder](https://github.com/erjosito/AzureBlackMagic/tree/master/CustomScriptExtensions) show some deployment examples for typical components of a multi-tier application, including:

* Domain Controller (including join scripts for the members)
* IIS role activation
* SQL Server on IaaS VM installation (see the next section for Azure SQL DB)


# PaaS: Azure SQL DB

[This powershell script](https://github.com/erjosito/AzureBlackMagic/blob/master/azureSQLdb.ps1) shows different commands that can be used to perform the following actions:

* Create a new Azure SQL Database (including the Azure SQL Server instance) in Azure
* Import an existing bacpac file into the SQL database, including a scale-up before the import operation and a scale-down afterwards
* Delete the Azure SQL DB Database