param(
    [Parameter(Mandatory=$True,Position=1)]
    [string] $DomainName,

    [Parameter(Mandatory=$True,Position=2)]
    [string] $Password,

    [Parameter(Mandatory=$false,Position=3)]
    [bool] $LogToTempDir

)

if ($LogToTempDir)
{
    if (!(Test-Path "c:\temp")) { mkdir c:\temp -force}
    start-transcript c:\temp\InstallDomain.log
}

#To install AD we need PS support for AD first
Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
Import-Module ActiveDirectory

#Do Domain install
$SecurePassword = ConvertTo-SecureString "$Password" -AsPlainText -Force
Install-ADDSForest -DomainName "$DomainName" -ForestMode Default -DomainMode Default -InstallDns:$true -SafeModeAdministratorPassword $SecurePassword -CreateDnsDelegation:$false -NoRebootOnCompletion:$true -Force:$true

if ($LogToTempDir) {stop-transcript}