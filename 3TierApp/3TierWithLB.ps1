<#######################################
this script should create
Windows VMs for an 3-tier application

by bfrank

see e.g. https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/virtual-machines-windows/n-tier
########################################>

#region Variable Section
    $ConfigPrefix = "MUC"
    $TierPrefix = @("$($ConfigPrefix)WebTier","$($ConfigPrefix)BizTier", "$($ConfigPrefix)DataTier","$($ConfigPrefix)AD","$($ConfigPrefix)JumpHost")
    $TopLevelRG = $($ConfigPrefix+"RG")   # "MUCRG"
    $VNETAddressPrefix = "10.0.0.0/16"
    $TierSubnets =@("10.0.0.0/24","10.0.1.0/24","10.0.2.0/24","10.0.100.0/24","10.0.253.0/24" )
    $VMName             = "iaas-vm"
    $VMSize             = "Standard_DS1_V2" 
    $ResourceGroupName  = "BMDemo" 
    $StorageAccountName = "BMDemosa" 
    $StorageAccountType = "Standard_LRS" 
    $LocalAdminUsername = "bfrank" 
    $LocalAdminPassword = "LetMeInNow1!" 
    $Location = "NorthEurope"
    $LBDomainNameLabel = "bfrankwebapp"
    $OSDiskCaching = "ReadOnly"
    $backendNIC1IP = "10.0.0.6"
    $backendNIC2IP = "10.0.0.7"
    $ADNICIP = "10.0.100.4"
    $DomainName = "Buildmycloud.local"
#endregion 

#Login to Azure Subscription
$subscription = Get-AzureRmSubscription -ErrorAction SilentlyContinue
if (!($subscription))
{
    Login-AzureRmAccount
}

#Create a Top Level Resource Group for Configuration
New-AzureRmResourceGroup -Name $TopLevelRG -Location $Location

#region create a large VNET for our configuration
    #Subnet
    $subnets = @()
    for ($i = 0; $i -lt $TierPrefix.Count; $i++)
    { 
       $subnets += New-AzureRmVirtualNetworkSubnetConfig -Name $($TierPrefix[$i]+"SNet") -AddressPrefix $TierSubnets[$i]
    }

    #VNet
    $VNet = New-AzureRmVirtualNetwork -Name $($ConfigPrefix+"VNET") -AddressPrefix $VNETAddressPrefix -Subnet $subnets -ResourceGroupName $TopLevelRG -Location $Location -DnsServer $ADNICIP

#endregion        

#region add a new Resource Group + Availability Set for each tier
for ($i = 0; $i -lt $TierPrefix.Count; $i++)
{ 
    $RGName = $TierPrefix[$i]+"RG"
    $AvailabilitySetName = $TierPrefix[$i]+"AVSet"
    New-AzureRmResourceGroup -Name $RGName -Location $Location
    New-AzureRmAvailabilitySet -Location $Location -Name $AvailabilitySetName -ResourceGroupName $RGName -Sku aligned -PlatformFaultDomainCount 1 -PlatformUpdateDomainCount 1
}
#endregion

   #region Create Web Tier LB - PubIP
    $i=0
    $RGName = $TierPrefix[$i]+"RG"
    $publicIP = New-AzureRmPublicIpAddress -Name "$($TierPrefix[$i])LBPIP" -ResourceGroupName $RGName -Location $Location -AllocationMethod Static -DomainNameLabel $LBDomainNameLabel
    $LBFrontendPIpName = "$($TierPrefix[$i])LBPFEIPConfig"
    $frontendIP = New-AzureRmLoadBalancerFrontendIpConfig -Name $LBFrontendPIpName -PublicIpAddress $publicIP 
    $beaddresspool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "$($TierPrefix[$i])LBBEPool"
    $inboundNATRule1= New-AzureRmLoadBalancerInboundNatRuleConfig -Name RDP1 -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3441 -BackendPort 3389 
    $inboundNATRule2= New-AzureRmLoadBalancerInboundNatRuleConfig -Name RDP2 -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3442 -BackendPort 3389

     #http probe
     #$healthProbe = New-AzureRmLoadBalancerProbeConfig -Name HealthProbe -RequestPath 'HealthProbe.aspx' -Protocol http -Port 80 -IntervalInSeconds 15 -ProbeCount 2
     #TCP probe
     $healthProbe = New-AzureRmLoadBalancerProbeConfig -Name HealthProbe -Protocol Tcp -Port 80 -IntervalInSeconds 15 -ProbeCount 2

     #Create a load balancer rule
     $lbrule = New-AzureRmLoadBalancerRuleConfig -Name HTTP -FrontendIpConfiguration $frontendIP -BackendAddressPool  $beAddressPool -Probe $healthProbe -Protocol Tcp -FrontendPort 80 -BackendPort 80 

     #create the load balancer
     $NRPLB = New-AzureRmLoadBalancer -ResourceGroupName $RGName -Name "$($TierPrefix[$i])LB" -Location $Location -FrontendIpConfiguration $frontendIP -InboundNatRule $inboundNATRule1,$inboundNatRule2 -LoadBalancingRule $lbrule -BackendAddressPool $beAddressPool -Probe $healthProbe 
    #endregion

#Important: VMs for LB need to be in same Availability Set - this has been created before see above....
# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/tutorial-availability-sets

    #region create a Network Security Group ("Firewall Rule") for Frontend Webservers
        $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig `
        -Name "$($TierPrefix[$i])-RDPRule" `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 100 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 3389 `
        -Access Allow

        $nsgRuleHTTP = New-AzureRmNetworkSecurityRuleConfig `
        -Name "$($TierPrefix[$i])-HTTP" `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 101 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 80 `
        -Access Allow

         $nsgRuleHTTPS = New-AzureRmNetworkSecurityRuleConfig `
        -Name "$($TierPrefix[$i])-HTTPS" `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 102 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 443 `
        -Access Allow

        $nsgWeb = New-AzureRmNetworkSecurityGroup `
        -Location $Location `
        -Name $($TierPrefix[$i]+"-NSG") `
        -ResourceGroupName $RGName `
        -SecurityRules $nsgRuleRDP,$nsgRuleHTTP,$nsgRuleHTTPS
    #endregion

    #region Create VM Web1
    $i = 0    #this is the web tier.
    $VMName = "$($TierPrefix[$i])VM1"

    $RGName = $TierPrefix[$i]+"RG"
    $AvailabilitySetName = $TierPrefix[$i]+"AVSet"
    $AvailabilitySet = Get-AzureRmAvailabilitySet -Name $AvailabilitySetName -ResourceGroupName $RGName

    $VM = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id

    #Get Backend subnet and attach it to a NIC
    $VnetName = $($ConfigPrefix+"VNET")
    $SnetName = $($TierPrefix[$i]+"SNet")
    $vnet = Get-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName $TopLevelRG
    $backendSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SnetName -VirtualNetwork $vnet

    #create a nic and associate it with the firtst NAT rule and the backend address pool
    $backendnic1= New-AzureRmNetworkInterface -ResourceGroupName $RGName -Name $($TierPrefix[$i]+"LB-NIC1-BE") -Location $Location -PrivateIpAddress $backendNIC1IP -Subnet $backendSubnet -LoadBalancerBackendAddressPool $nrplb.BackendAddressPools[0] -LoadBalancerInboundNatRule $nrplb.InboundNatRules[0] -NetworkSecurityGroup $nsgWeb

    #attach nic to VM config
    $VM = Add-AzureRmVMNetworkInterface -VM $VM -NetworkInterface $backendnic1
    $SecureLocalAdminPassword = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $SecureLocalAdminPassword) 
    $VM = Set-AzureRmVMOperatingSystem -VM $VM -Windows -ComputerName $VMName -Credential $Credentials 
    
    #VM Image Selection
    $VMImageSKU = Get-AzureRmVMImageSku -Location $Location -PublisherName MicrosoftWindowsServer -Offer WindowsServer | Out-GridView -PassThru -Title "Select Your SKU"
    $VMImage = Get-AzureRmVMImage `
     -Location $Location `
          -PublisherName MicrosoftWindowsServer `
          -Offer WindowsServer `
          -Skus $VMImageSKU.Skus `
          | Sort-Object Version -Descending `     | Select-Object -First 1 
    $VM = Set-AzureRmVMSourceImage -VM $VM -PublisherName $VMImage.PublisherName -Offer $VMImage.Offer -Skus $VMIMage.Skus -Version $VMImage.Version
    
    #Disable Boot Diagnostics for VM
    $VM =  Set-AzureRmVMBootDiagnostics -VM $VM -Disable
    
    #attach Boot / OS Disk
    $VM = Set-AzureRmVMOSDisk -VM $VM -Name "$($VMName)OSDisk" -DiskSizeInGB 128 -CreateOption FromImage -Caching $OSDiskCaching
    
    #attach a data disk
    $storageType = 'PremiumLRS'
    $dataDisk1Name = $VMName + 'DataDisk1'
    
    $diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Empty -DiskSizeGB 128
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDisk1Name -Disk $diskConfig -ResourceGroupName $RGName
    
    $VM = Add-AzureRmVMDataDisk -VM $VM -Name $dataDisk1Name -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1 -Caching ReadOnly
    
    #create VM
    New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VM -AsJob
#endregion 
    #region Create VM Web2
    $i = 0    #this is the web tier.
    $VMName = "$($TierPrefix[$i])VM2"

    $RGName = $TierPrefix[$i]+"RG"
    $AvailabilitySetName = $TierPrefix[$i]+"AVSet"
    $AvailabilitySet = Get-AzureRmAvailabilitySet -Name $AvailabilitySetName -ResourceGroupName $RGName

    $VM = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id

    #Get Backend subnet and attach it to a NIC
    $VnetName = $($ConfigPrefix+"VNET")
    $SnetName = $($TierPrefix[$i]+"SNet")
    $vnet = Get-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName $TopLevelRG
    $backendSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SnetName -VirtualNetwork $vnet

    #create a nic and associate it with the firtst NAT rule and the backend address pool
    $backendnic2= New-AzureRmNetworkInterface -ResourceGroupName $RGName -Name $($TierPrefix[$i]+"LB-NIC2-BE") -Location $Location -PrivateIpAddress $backendNIC2IP -Subnet $backendSubnet -LoadBalancerBackendAddressPool $nrplb.BackendAddressPools[0] -LoadBalancerInboundNatRule $nrplb.InboundNatRules[1] -NetworkSecurityGroup $nsgWeb

    #attach nic to VM config
    $VM = Add-AzureRmVMNetworkInterface -VM $VM -NetworkInterface $backendnic2
    $SecureLocalAdminPassword = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $SecureLocalAdminPassword) 
    $VM = Set-AzureRmVMOperatingSystem -VM $VM -Windows -ComputerName $VMName -Credential $Credentials 
    
    #VM Image Selection
    $VMImageSKU = Get-AzureRmVMImageSku -Location $Location -PublisherName MicrosoftWindowsServer -Offer WindowsServer | Out-GridView -PassThru -Title "Select Your SKU"
    $VMImage = Get-AzureRmVMImage `
     -Location $Location `
          -PublisherName MicrosoftWindowsServer `
          -Offer WindowsServer `
          -Skus $VMImageSKU.Skus `
          | Sort-Object Version -Descending `     | Select-Object -First 1 
    $VM = Set-AzureRmVMSourceImage -VM $VM -PublisherName $VMImage.PublisherName -Offer $VMImage.Offer -Skus $VMIMage.Skus -Version $VMImage.Version
    
    #Disable Boot Diagnostics for VM
    $VM =  Set-AzureRmVMBootDiagnostics -VM $VM -Disable
    
    #attach Boot / OS Disk
    $VM = Set-AzureRmVMOSDisk -VM $VM -Name "$($VMName)OSDisk" -DiskSizeInGB 128 -CreateOption FromImage -Caching $OSDiskCaching
    
    #attach a data disk
    $storageType = 'PremiumLRS'
    $dataDisk1Name = $VMName + 'DataDisk1'
    
    $diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Empty -DiskSizeGB 128
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDisk1Name -Disk $diskConfig -ResourceGroupName $RGName
    
    $VM = Add-AzureRmVMDataDisk -VM $VM -Name $dataDisk1Name -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1 -Caching ReadOnly
    
    #create VM
    New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VM -AsJob
#endregion 

#region Add the web server network interfaces to the load balancer
    $i = 0
    $RGName = $TierPrefix[$i]+"RG"
    #get LB from Azure
    $lb= get-azurermloadbalancer -Name "$($TierPrefix[$i])LB" -ResourceGroupName $RGName

    #get backend config
    $backend=Get-AzureRmLoadBalancerBackendAddressPoolConfig -name "$($TierPrefix[$i])LBBEPool" -LoadBalancer $lb

    #get the nic that was created earlier
    #$nic =get-azurermnetworkinterface -name lb-nic1-be -resourcegroupname $RGName
    #$nic2=get-azurermnetworkinterface -name lb-nic2-be -resourcegroupname $RGName

    #change the backend config on the nic
    $backendnic1.IpConfigurations[0].LoadBalancerBackendAddressPools=$backend
    $backendnic2.IpConfigurations[0].LoadBalancerBackendAddressPools=$backend

    #save the nic config
    Set-AzureRmNetworkInterface -NetworkInterface $backendnic1
    Set-AzureRmNetworkInterface -NetworkInterface $backendnic2
#endregion

#region BizTier VM
    $i = 1
    $RGName = $TierPrefix[$i]+"RG"

    #region Network Security Group (aka "Firewall Rule")
        $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig `
        -Name $($TierPrefix[$i]+"NSGRule") `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 1000 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 3389 `
        -Access Allow

        $nsg = New-AzureRmNetworkSecurityGroup `
        -Location $Location `
        -Name $($TierPrefix[$i]+"NSG") `
        -ResourceGroupName $RGName `
        -SecurityRules $nsgRuleRDP
    #endregion

    #Create a new VM Config with Availabilityset
    $VMName = "$($TierPrefix[$i])VM"
    $AvailabilitySetName = $TierPrefix[$i]+"AVSet"
    $AvailabilitySet = Get-AzureRmAvailabilitySet -Name $AvailabilitySetName -ResourceGroupName $RGName
    $VMConfig = New-AzureRMVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id

    #NIC - requires Subnet,StaticIP,Location
    $NIC = New-AzureRmNetworkInterface -Name "$($VMName)NIC" -ResourceGroupName $RGName -SubnetId $VNet.Subnets[$i].id -Location $Location -PrivateIpAddress "10.0.1.4" -NetworkSecurityGroupId $nsg.Id
        
    #Attach VNIC to VMConfig
    $VM = Add-AzureRmVMNetworkInterface -VM $VMConfig -Id $NIC.Id 

    #create Admin credential for Win OS
    $SecureLocalAdminPassword = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $SecureLocalAdminPassword) 
    $VM = Set-AzureRmVMOperatingSystem -VM $VM -Windows -ComputerName $VMName -Credential $Credentials 
    
    
    #Select and set VM Image
    $VMImageSKU = Get-AzureRmVMImageSku -Location $Location -PublisherName MicrosoftWindowsServer -Offer WindowsServer | Out-GridView -PassThru -Title "Select Your SKU"
    $VMImage = Get-AzureRmVMImage `
         -Location $Location `
         -PublisherName MicrosoftWindowsServer `
         -Offer WindowsServer `
         -Skus $VMImageSKU.Skus `
         | Sort-Object Version -Descending `     | Select-Object -First 1 


    $VM = Set-AzureRmVMSourceImage -VM $VM -PublisherName $VMImage.PublisherName -Offer $VMImage.Offer -Skus $VMIMage.Skus -Version $VMImage.Version

    #Disable Boot Diagnostics for VM
    $VM =  Set-AzureRmVMBootDiagnostics -VM $VM -Disable

    #attach Boot / OS Disk
    $VM = Set-AzureRmVMOSDisk -VM $VM -Name "$($VMName)OSDisk" -DiskSizeInGB 128 -CreateOption FromImage -Caching $OSDiskCaching

    #create VM
    New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VM -AsJob
#endregion 

#region DomainController VM
    $i = 3
    $RGName = $TierPrefix[$i]+"RG"

    #region Network Security Group (aka "Firewall Rule")
        $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig `
        -Name $($TierPrefix[$i]+"NSGRule") `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 1000 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 3389 `
        -Access Allow

        $nsgRuleAD = New-AzureRmNetworkSecurityRuleConfig `
        -Name $($TierPrefix[$i]+"NSGRule") `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 1000 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 445 `
        -Access Allow

        $nsg = New-AzureRmNetworkSecurityGroup `
        -Location $Location `
        -Name $($TierPrefix[$i]+"NSG") `
        -ResourceGroupName $RGName `
        -SecurityRules $nsgRuleRDP
    #endregion

   
    #NIC - requires Subnet,PubIP,Location
    $VMName = "$($TierPrefix[$i])VM"
    $AvailabilitySetName = $TierPrefix[$i]+"AVSet"
    $AvailabilitySet = Get-AzureRmAvailabilitySet -Name $AvailabilitySetName -ResourceGroupName $RGName
    $VMConfig = New-AzureRMVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id

    $NIC = New-AzureRmNetworkInterface -Name "$($VMName)NIC" -ResourceGroupName $RGName -SubnetId $VNet.Subnets[$i].id -Location $Location -PrivateIpAddress $ADNICIP -NetworkSecurityGroupId $nsg.Id
        
    #Attach VNIC to VMConfig
    $VM = Add-AzureRmVMNetworkInterface -VM $VMConfig -Id $NIC.Id 


    #create Admin credential for Win OS
    $SecureLocalAdminPassword = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $SecureLocalAdminPassword) 
    $VM = Set-AzureRmVMOperatingSystem -VM $VM -Windows -ComputerName $VMName -Credential $Credentials 
    
    
    #Select and set VM Image
    $VMImageSKU = Get-AzureRmVMImageSku -Location $Location -PublisherName MicrosoftWindowsServer -Offer WindowsServer | Out-GridView -PassThru -Title "Select Your SKU"
    $VMImage = Get-AzureRmVMImage `
         -Location $Location `
         -PublisherName MicrosoftWindowsServer `
         -Offer WindowsServer `
         -Skus $VMImageSKU.Skus `
         | Sort-Object Version -Descending `     | Select-Object -First 1 


    $VM = Set-AzureRmVMSourceImage -VM $VM -PublisherName $VMImage.PublisherName -Offer $VMImage.Offer -Skus $VMIMage.Skus -Version $VMImage.Version

    #Disable Boot Diagnostics for VM
    $VM =  Set-AzureRmVMBootDiagnostics -VM $VM -Disable

    #attach Boot / OS Disk
    $VM = Set-AzureRmVMOSDisk -VM $VM -Name "$($VMName)OSDisk" -DiskSizeInGB 128 -CreateOption FromImage -Caching $OSDiskCaching

    #attach a data disk
    $storageType = 'PremiumLRS'
    $dataDisk1Name = $VMName + 'DataDisk1'

    $diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Empty -DiskSizeGB 128
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDisk1Name -Disk $diskConfig -ResourceGroupName $RGName

    #$VM = Get-AzureRmVM -Name $VMName -ResourceGroupName $RGName
    $VM = Add-AzureRmVMDataDisk -VM $VM -Name $dataDisk1Name -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1
    #Update-AzureRmVM -VM $VM -ResourceGroupName $RGName    #update when machine is already created.

    #create VM
    New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VM -AsJob

#endregion

#region DataTier VM
    $i = 2
    $RGName = $TierPrefix[$i]+"RG"

    #region Network Security Group (aka "Firewall Rule")
        $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig `
        -Name $($TierPrefix[$i]+"NSGRule") `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 1000 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 3389 `
        -Access Allow

        $nsg = New-AzureRmNetworkSecurityGroup `
        -Location $Location `
        -Name $($TierPrefix[$i]+"NSG") `
        -ResourceGroupName $RGName `
        -SecurityRules $nsgRuleRDP
    #endregion

   
    #NIC - requires Subnet,PubIP,Location
    $VMName = "$($TierPrefix[$i])VM"
    $AvailabilitySetName = $TierPrefix[$i]+"AVSet"
    $AvailabilitySet = Get-AzureRmAvailabilitySet -Name $AvailabilitySetName -ResourceGroupName $RGName
    $VMConfig = New-AzureRMVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id

    $NIC = New-AzureRmNetworkInterface -Name "$($VMName)NIC" -ResourceGroupName $RGName -SubnetId $VNet.Subnets[$i].id -Location $Location -PrivateIpAddress "10.0.2.4" -NetworkSecurityGroupId $nsg.Id
        
    #Attach VNIC to VMConfig
    $VM = Add-AzureRmVMNetworkInterface -VM $VMConfig -Id $NIC.Id 
    
    #create Admin credential for Win OS
    $SecureLocalAdminPassword = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $SecureLocalAdminPassword) 
    $VM = Set-AzureRmVMOperatingSystem -VM $VM -Windows -ComputerName $VMName -Credential $Credentials 
    
    
    #Select and set VM Image
    $VMImageSKU = Get-AzureRmVMImageSku -Location $Location -PublisherName MicrosoftSQLServer -Offer SQL2017-WS2016 | Out-GridView -PassThru -Title "Select Your SKU"
    $VMImage = Get-AzureRmVMImage `
         -Location $Location `
         -PublisherName MicrosoftSQLServer `
         -Offer SQL2017-WS2016 `
         -Skus $VMImageSKU.Skus `
         | Sort-Object Version -Descending `     | Select-Object -First 1 


    $VM = Set-AzureRmVMSourceImage -VM $VM -PublisherName $VMImage.PublisherName -Offer $VMImage.Offer -Skus $VMIMage.Skus -Version $VMImage.Version

    #Disable Boot Diagnostics for VM
    $VM =  Set-AzureRmVMBootDiagnostics -VM $VM -Disable

    #attach Boot / OS Disk
    $VM = Set-AzureRmVMOSDisk -VM $VM -Name "$($VMName)OSDisk" -DiskSizeInGB 128 -CreateOption FromImage -Caching $OSDiskCaching


    #attach a data disk
    $storageType = 'PremiumLRS'
    $dataDisk1Name = $VMName + 'DataDisk1'

    $diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Empty -DiskSizeGB 128
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDisk1Name -Disk $diskConfig -ResourceGroupName $RGName

    #$VM = Get-AzureRmVM -Name $VMName -ResourceGroupName $RGName
    $VM = Add-AzureRmVMDataDisk -VM $VM -Name $dataDisk1Name -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1
    #Update-AzureRmVM -VM $VM -ResourceGroupName $RGName    #update when machine is already created.

    #create VM
    New-AzureRmVM -ResourceGroupName $RGName -Location $Location -VM $VM 
    
    #install SQL IaaS Agent -> will enable to configure SQL via the Azure portal
    Set-AzureRmVMSqlServerExtension -ResourceGroupName $RGName -VMName $VMName -Name "SQLIaaSExtension" -Version "1.2"




#endregion 

#region Custom Script Extension
        #create storageaccount
        #container 
        #upload script extension 
<#        $StorageAccountName = "bfrankCustomScriptSA".ToLower()
        $ContainerName = "CustomScriptsContainer".ToLower()
        $ScriptsToUpload = @("C:\work\work\1_Daten & Wissensspeicher\1.1_PowerShell\Azure\Black Magic\Install-IIS.ps1","C:\work\work\1_Daten & Wissensspeicher\1.1_PowerShell\Azure\Black Magic\Install-Domain.ps1","C:\work\work\1_Daten & Wissensspeicher\1.1_PowerShell\Azure\Black Magic\Join-Domain.ps1")
        
        #ScriptExtension besser auf GitHub ablegen....
        #region Create a new storage account.
        New-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $TopLevelRG -SkuName Standard_LRS -Location $Location -Kind BlobStorage -AccessTier Cool 
        #endregion
        
        #region Create a Script Container
        Set-AzureRmCurrentStorageAccount -Name $StorageAccountName -ResourceGroupName $TopLevelRG
        New-AzureStorageContainer -Name $ContainerName -Permission Blob
        #endregion
        
        #region upload script extension script to container
        foreach ($ScriptToUpload in $ScriptsToUpload)
        {
           $ScriptsContainer = Set-AzureStorageBlobContent -Container $ContainerName -File $ScriptToUpload 
        }
        
        #endregion
#>

        #attach scriptextension to vm and make sure you have the name of the file behind -Run   
        $i = 0    #this is the web tier.
        $RGName = $TierPrefix[$i]+"RG"
        $VMName = "$($TierPrefix[$i])VM1"
        $myURL = "https://raw.githubusercontent.com/bernhardfrank/AzureBlackMagic/master/CustomScriptExtensions/Install-IIS.ps1"
        Set-AzureRmVMCustomScriptExtension -ResourceGroupName $RGName -VMName $VMName -Location $Location -FileUri $myURL -Run "$(Split-Path -Leaf -Path $myURL)" -Name DemoScriptExtension -Argument "true"

        $VMName = "$($TierPrefix[$i])VM2"
        Set-AzureRmVMCustomScriptExtension -ResourceGroupName $RGName -VMName $VMName -Location $Location -FileUri $myURL -Run "$(Split-Path -Leaf -Path $myURL)" -Name DemoScriptExtension 

        $i = 3 # DC Tier
        $RGName = $TierPrefix[$i]+"RG"
        $VMName = "$($TierPrefix[$i])VM"
        $myURL = "https://raw.githubusercontent.com/bernhardfrank/AzureBlackMagic/master/CustomScriptExtensions/Install-Domain.ps1"
        Set-AzureRmVMCustomScriptExtension -ResourceGroupName $RGName -VMName $VMName -Location $Location -FileUri $myURL -Run "$(Split-Path -Leaf -Path $myURL)" -Name DemoScriptExtension -Argument "$DomainName $LocalAdminPassword true"

        #restart DC after DC Promo
        Get-AzureRmVM -Name $VMName -ResourceGroupName $RGName | Restart-AzureRmVM 

        #check: domain controller up and running?
        sleep -Seconds 50
        
        #do the domain join of the Backend servers
        $i = 2    #this is the web tier.
        $RGName = $TierPrefix[$i]+"RG"
        $myURL = "https://raw.githubusercontent.com/bernhardfrank/AzureBlackMagic/master/CustomScriptExtensions/Join-Domain.ps1"
        $VMName = "$($TierPrefix[$i])VM"
        Set-AzureRmVMCustomScriptExtension -ResourceGroupName $RGName -VMName $VMName -Location $Location -FileUri $myURL -Run "$(Split-Path -Leaf -Path $myURL)" -Name DemoScriptExtension -Argument "$DomainName $LocalAdminUsername $LocalAdminPassword true"

        #restart VM after Domain Join
        Get-AzureRmVM -Name $VMName -ResourceGroupName $RGName | Restart-AzureRmVM 

        #Note: install SQL - is already done. Through the image selection and Set-AzureRmVMSqlServerExtension

#endregion

<#region cleanup
    for ($i = 0; $i -lt $TierPrefix.count; $i++)
    { 
        $RGName = $TierPrefix[$i]+"RG"
        Remove-AzureRmResourceGroup -name $RGName -Force -AsJob
    }
    Remove-AzureRmResourceGroup -Name $TopLevelRG -Force -AsJob
#endregion

#>