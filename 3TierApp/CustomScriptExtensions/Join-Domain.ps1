<#
    Join Domain.
#>

param(
    [Parameter(Mandatory=$True,Position=1)]
    [string] $DomainName,

    [Parameter(Mandatory=$True,Position=2)]
    [string] $UserName,

    [Parameter(Mandatory=$True,Position=3)]
    [string] $Password,

    [Parameter(Mandatory=$False,Position=4)]
    [string] $ComputerName,
    
    [Parameter(Mandatory=$False,Position=5)]
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
    start-transcript "$tmpDir\Join-Domain.log"
}

#we need to find the AD for Domain join - so lets add the DNS server that knows the domain to join to.
#on prem you would do this 
#$InterfaceAlias =  (Get-NetAdapter | Get-NetIPAddress | where Addressfamily -eq "IPv4").InterfaceAlias
#Set-DnsClientServerAddress -InterfaceAlias "$InterfaceAlias" -ServerAddresses $DNSIP

#For AD in Azure VMs you would set the DNS Server on the VNET 
#New-AzureRmVirtualNetwork -Name ... -DnsServer $ADNICIP

$pwd = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$DomainName\$UserName", $pwd

if ($ComputerName)
{
    #rename computer while joining to domain.
    Add-Computer -ComputerName localhost -DomainName $DomainName -Credential $credential -NewName $ComputerName
}
else
{
    #keep old computername
    Add-Computer -ComputerName localhost -DomainName $DomainName -Credential $credential #-OUPath "OU=Servers,OU=CloudFabric,DC=buildmycloud,DC=de"
}

write-output "don't forget to reboot."

if ($writeLog) {stop-transcript}