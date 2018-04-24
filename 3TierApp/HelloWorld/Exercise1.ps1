Install-Module AzureRM -AllowClobber



# Variables
$RG = "BlackMagicRG"
$Location = "NorthEurope"
$StorageAccountName = "SampleStorageAccountName".ToLower()    #SA's don't like capital chars

Login-AzureRmAccount

New-AzureRmResourceGroup -Name $RG -Location $Location

#Storage Account
New-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $RG -SkuName Standard_RAGRS -Location $Location -Kind BlobStorage -AccessTier Hot 


#Subnet
$subnets = @()
$subnets += New-AzureRmVirtualNetworkSubnetConfig -Name "SubNet1" -AddressPrefix "10.0.1.0/24"
$subnets += New-AzureRmVirtualNetworkSubnetConfig -Name "SubNet2" -AddressPrefix "10.0.2.0/24"

#Vnet
$VNet = New-AzureRmVirtualNetwork -Name "VNET" -AddressPrefix "10.0.0.0/16" -Subnet $subnets -ResourceGroupName $RG -Location $Location



#VNet was created before - how to add a new subnet?
$VNET = Get-AzureRmVirtualNetwork -Name "VNET" -ResourceGroupName $RG

$newSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "newSubnet" -AddressPrefix "10.0.3.0/24"

$VNet.Subnets.Add($newSubnet)                              # update my vnet
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet            # "commit" changes to Azure


#cleanup
#Remove-AzureRmResourceGroup -ResourceGroupName $RG -Force