param(
    [Parameter(Mandatory=$True,Position=1)]
    [string] $DomainName,

    [Parameter(Mandatory=$True,Position=2)]
    [string] $Password,

    [Parameter(Mandatory=$False,Position=3)]
    [string] $LogToTempDir
)

#this will be our temp folder logging
$tmpDir = "c:\temp\" 

try
{
    $writeLog = [bool]::Parse($LogToTempDir)
}
catch
{
    $writeLog=$false
}

if ($writeLog)
{
    if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force}
    start-transcript "$tmpDir\Install-Domain.log"
}

#To install AD we need PS support for AD first
Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
Import-Module ActiveDirectory


#Do we find Data disks (raw by default) in this VM? 
$RawDisks = Get-Disk | where PartitionStyle -eq "RAW"

$driveLetters = ("f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")

$i = 0
foreach ($RawDisk in $RawDisks)
{
    $currentDriveLetter = $driveLetters[$i]

    New-Volume -DiskNumber $RawDisk.Number -FriendlyName "Data$i" -FileSystem NTFS -DriveLetter $currentDriveLetter
    $i++
}

#Do Domain install
#on prem you could install AD database to OS disk - AD in Azure VM this is not recommended!
#https://docs.microsoft.com/en-us/previous-versions/orphan-topics/azure.100/jj156090(v=azure.100)
#To Do: for Active Directory database storage You need to change default storage location from C:\ 
#Store the database, logs, and SYSVOL on the either same data disk or separate data disks e.g.
#-DatabasePath "e:\NTDS" -SysvolPath "e:\SYSVOL" -LogPath "e:\Logs"
#Set the Host Cache Preference setting on the Azure data disk for NONE. This prevents issues with write caching for AD DS operations.

$SecurePassword = ConvertTo-SecureString "$Password" -AsPlainText -Force

#Do we have Data Disk? 
$DataDisk0 = Get-Volume -FileSystemLabel "Data0" -ErrorAction SilentlyContinue

switch ($DataDisk0 -ne $null)
{
    'True'      #Active Directory database storage on first Data Disk 
    {
        $drive = "$($DataDisk0.DriveLetter):"
        Install-ADDSForest -DomainName "$DomainName" -DatabasePath "$drive\NTDS" -SysvolPath "$drive\SYSVOL" -LogPath "$drive\Logs" -ForestMode Default -DomainMode Default -InstallDns:$true -SafeModeAdministratorPassword $SecurePassword -CreateDnsDelegation:$false -NoRebootOnCompletion:$true -Force:$true
    }
    
    #nope - not recommended 
    Default 
    {
        Install-ADDSForest -DomainName "$DomainName" -ForestMode Default -DomainMode Default -InstallDns:$true -SafeModeAdministratorPassword $SecurePassword -CreateDnsDelegation:$false -NoRebootOnCompletion:$true -Force:$true
    }
}


#add some DNS forwarders to our DNS server to enable external name resolution
Add-DnsServerForwarder -IPAddress 8.8.8.8
Add-DnsServerForwarder -IPAddress 208.67.222.222

if ($writeLog) {stop-transcript}
