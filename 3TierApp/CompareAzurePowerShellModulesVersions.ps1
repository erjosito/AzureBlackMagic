<# 

    Compare your Azure PowerShell modules version vs. the available ones
    bfrank
#>

$installed = Get-InstalledModule -Name AzureRm*
$available = Find-Module -Name AzureRM*

"Installed ---> Availabe `t Module Name"
"--------------------------------------"

foreach ($item in $installed)
{
   "{1} ---> {2} `t {0}" -f $item.name,$item.Version,($available | where Name -eq $item.Name).Version 
}


#you might want to update - here is the command
#Install-Module AzureRM -AllowClobber