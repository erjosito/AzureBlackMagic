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

#Do Domain install
$SecurePassword = ConvertTo-SecureString "$Password" -AsPlainText -Force
Install-ADDSForest -DomainName "$DomainName" -ForestMode Default -DomainMode Default -InstallDns:$true -SafeModeAdministratorPassword $SecurePassword -CreateDnsDelegation:$false -NoRebootOnCompletion:$true -Force:$true

if ($writeLog) {stop-transcript}