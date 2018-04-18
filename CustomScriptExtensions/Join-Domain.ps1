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

    [Parameter(Mandatory=$True,Position=4)]
    [string] $DNSIP,

    [Parameter(Mandatory=$False,Position=5)]
    [string] $ComputerName   

)


#we need to find the AD for Domain join - so lets add the DNS server that knows the domain to join to.
$InterfaceAlias =  (Get-NetAdapter | Get-NetIPAddress | where Addressfamily -eq "IPv4").InterfaceAlias
Set-DnsClientServerAddress -InterfaceAlias "$InterfaceAlias" -ServerAddresses $DNSIP

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

#don't forget to reboot to take effect.
