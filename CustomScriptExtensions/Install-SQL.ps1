<#
    Install SQL Server unattended install as e.g. Azure Custom Script Extension
#>

param(
    [Parameter(Mandatory=$True,Position=1)]
    [string] $SAPassword,

    [Parameter(Mandatory=$False,Position=2)]
    [string] $SQLSYSADMINACCOUNT,
    
    [Parameter(Mandatory=$False,Position=3)]
    [bool] $InstallSQLServerManagementStudio,

    [Parameter(Mandatory=$False,Position=4)]
    [bool] $LogToTempDir
)

#this will be our temp folder - need it for sql download / logging
$tmpDir = "c:\temp\" 

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force}

if ($LogToTempDir)
{
    start-transcript "$tmpDir\InstallSQL.log"
}


#region get SQL bits
$downloadSQL = "http://download.microsoft.com/download/F/E/9/FE9397FA-BFAB-4ADD-8B97-91234BC774B2/SQLServer2016-x64-ENU.iso"
$downloadSSMS = "http://download.microsoft.com/download/E/D/3/ED3B06EC-E4B5-40B3-B861-996B710A540C/SSMS-Setup-ENU.exe"

    #region Download SQL Server Mgmt Studio in the background when not there
    if ($InstallSQLServerManagementStudio)
    {
        $SQLSSMSPath = "$tmpDir\$(split-path ($downloadSSMS) -Leaf)"
        if (!(Test-Path $SQLSSMSPath )) 
        {
            $bitsJob = start-bitstransfer "$downloadSSMS" "$tmpDir" -Priority High -RetryInterval 60 -Verbose -TransferType Download -Asynchronous
        }
     }
    #endregion
    #region Download SQL Server when not there and wait until finished
    $SQLPath = "$tmpDir\$(split-path ($downloadSQL) -Leaf)"
    if (!(Test-Path $SQLPath )) 
    {
        start-bitstransfer "$downloadSQL" "$tmpDir" -Priority High -RetryInterval 60 -Verbose -TransferType Download
    }
    #endregion
    
#endregion

#region install SQL Server
    #SQL setup Params...
    <#
    /ACTION="Install" /QUIET="True" /UpdateEnabled="True" /IACCEPTSQLSERVERLICENSETERMS="True" `    /SQMREPORTING="False" /FEATURES=SQLENGINE,SSMS,ADV_SSMS /INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server" `    /INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server" /INSTANCENAME="MSSQLSERVER" /INSTANCEID="MSSQLSERVER" `    /INSTANCEDIR="C:\Program Files\Microsoft SQL Server" `    /AGTSVCACCOUNT="NT AUTHORITY\SYSTEM" /AGTSVCSTARTUPTYPE="Automatic" `    /SQLSVCACCOUNT="NT AUTHORITY\SYSTEM" /SQLSVCSTARTUPTYPE="Automatic" `
    /BROWSERSVCSTARTUPTYPE="Automatic" /SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS" `
    /SECURITYMODE="SQL" /SAPWD="********" /SQLSYSADMINACCOUNTS="buildmycloud\Installer" "buildmycloud\SQL-Admins" `
    /INSTALLSQLDATADIR="D:\SQL Server" /SQLUSERDBDIR="E:\SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data" `
    /SQLUSERDBLOGDIR="F:\SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Logs" `
    /SQLTEMPDBDIR="G:\SQL Server\MSSQL13.MSSQLSERVER\MSSQL\TempDB" `    /SQLTEMPDBLOGDIR="G:\SQL Server\MSSQL13.MSSQLSERVER\MSSQL\TempDB" `    /SQLBACKUPDIR="C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data" `    /ERRORREPORTING="False" /TCPENABLED="1" /NPENABLED="0" /RSSVCACCOUNT="NT AUTHORITY\SYSTEM
    #>

#build parameterbased sql installation string
$SQLParams = @"
/ACTION="Install" /UpdateEnabled="True" /Quiet="True" /IACCEPTSQLSERVERLICENSETERMS="True" /SQMREPORTING="False" /FEATURES=SQL /INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server" /INSTANCENAME="MSSQLSERVER" /INSTANCEID="MSSQLSERVER" /INSTANCEDIR="C:\Program Files\Microsoft SQL Server" /AGTSVCACCOUNT="NT AUTHORITY\SYSTEM" /AGTSVCSTARTUPTYPE="Automatic" /SQLSVCACCOUNT="NT AUTHORITY\SYSTEM" /SQLSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Automatic" /SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS" /SECURITYMODE="SQL" /SAPWD="$SAPassword" {0} /ERRORREPORTING="False" /TCPENABLED="1" /NPENABLED="0" /RSSVCACCOUNT="NT AUTHORITY\SYSTEM"
"@ -f $(if ($SQLSYSADMINACCOUNT -ne "") {"/SQLSYSADMINACCOUNTS=""$SQLSYSADMINACCOUNT"""} else{""}) 

#mount SQL iso as drive
$mountResult = Mount-DiskImage -ImagePath $SQLPath -StorageType ISO -Access ReadOnly -Verbose -PassThru
$mountResult | Get-Volume

$driveLetter = ($mountResult | Get-Volume).DriveLetter

$SQLSetupEXE = "$($driveLetter):\setup.exe"

#install SQL
Start-Process -FilePath $SQLSetupEXE -ArgumentList $SQLParams -NoNewWindow -Wait

#when finished - dismount
Dismount-DiskImage -ImagePath $SQLPath

#endregion

#region install SQL Server Management Studio
if ($InstallSQLServerManagementStudio)
{
    #has SQL Server MGMT Studio already downloaded?
    do
    {
        sleep -Seconds 10
    }
    until ($bitsJob.Jobstate -eq "Transferred")
    
    $bitsjob | Resume-BitsTransfer
    
    #if yes - install
    Start-Process -FilePath $SQLSSMSPath -ArgumentList "/install /quiet" -NoNewWindow -Wait
}
#endregion

if ($LogToTempDir) {stop-transcript}
