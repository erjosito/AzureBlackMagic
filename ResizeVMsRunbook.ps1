<#

    This is the Azure Automation Sample Runbook.
    Add logic to resize vms - will be triggered from AA based on Schedule....

    #see http://sanganakauthority.blogspot.in/2017/05/run-login-azurermaccount-to-login.html
    #see also https://aka.ms/azure-resizevm

#>

param(
    [Parameter(Mandatory=$true)]
    [STRING]$RGName
)

function GetSmallerVmSize ($AzureVMSizes, $oldSize)
{
    #less memory and less cores available?
    $targetSizes = $AzureVMSizes | where {$_.MemoryInMB -lt $oldSize.MemoryInMB -and $_.NumberOfCores -lt $oldSize.NumberOfCores} | Sort-Object NumberOfCores,MemoryInMB -Descending
    
    #no? -> less memory and equal cores available?
    if ($targetSizes -eq $null)
    {
        $targetSizes = $AzureVMSizes | where {$_.MemoryInMB -lt $oldSize.MemoryInMB -and $_.NumberOfCores -le $oldSize.NumberOfCores} | Sort-Object NumberOfCores,MemoryInMB -Descending
    
        #no? -> promo available?
        if ($targetSizes -eq $null)
        {
            $targetSizes = $AzureVMSizes | where {$_.MemoryInMB -le $oldSize.MemoryInMB -and $_.NumberOfCores -le $oldSize.NumberOfCores -and $_.Name -like "*Promo*"} | Sort-Object NumberOfCores,MemoryInMB -Descending
            #still nothing? 
            if ($targetSizes -eq $null) {return $oldSize}
        }
    }
    
    #select first one in the list # assuming to be the closest one to match. # need to check the price?
    $targetSize = $targetSizes | Select-Object -First 1  
    
    return $targetSize
}

Write-Output "Resizing all VMs in $RGName"

#Loginto Azure subscription - Get Execution Context.
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
    "Logging in to Azure..."
    $account = Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
} 
Write-Output $account

#Get all VMs in RG - and create as is hashtable
$VMs = Get-AzureRmVM -ResourceGroupName $RGName
$hashTable = [hashtable]::new()

Write-Output "Current VMs and sizings:"
foreach ($VM in $VMs)
{
    "{0} : {1}" -f $VM.Name,$VM.HardwareProfile.VmSize
    $hashTable.Add($VM.Name,$VM.HardwareProfile.VmSize)
}

#suggest downsized VM types
$newHashTable = [hashtable]::new()

foreach ($item in $hashTable.GetEnumerator())
{

    #get all useful sizes in location
    #Danger!!! - below line gets all available Sizes in a location - however if it is not available on the executing host -> VMs need to be deallocated first 
    #$AzureVMSizes = Get-AzureRmVMSize -Location $azureLocation
    #therefore we want to choose from a list of possiblities that result only in a reboot of the VMs - much simpler :-)
    $AzureVMSizes = Get-AzureRmVMSize -ResourceGroupName $RGName -VMName $item.Key

    $oldSize = $AzureVMSizes | where {$_.Name -eq ($item.Value)}
    $newSize = GetSmallerVmSize $AzureVMSizes $oldSize
    #add to toDoList only when size changes
    if ($newSize -ne $oldSize)
    {
        $newHashTable.Add($item.Key,$newSize.Name)
    }
}

Write-Output "ToDo VM resizings in $RGName :" 
$newHashTable


foreach ($item in $newHashTable.GetEnumerator())
{
    $AzureVM = Get-AzureRmVM -Name $item.Key -ResourceGroupName $RGName
    $AzureVM.HardwareProfile.VmSize = $item.Value
    Update-AzureRmVM -VM $AzureVM -ResourceGroupName $RGName -verbose #-AsJob   #will result in resize and reboot. asjob: run in background - return immediately / i.e. continue without waiting for action to finish.
}

#cleanup
$AzureVMSizes = $null
$hashTable = $null
$newHashTable = $null