##################
#  Azure SQL DB  #
##################
$subscriptionName = "Microsoft Azure Internal Consumption"
$rg = "blackmagic"
$loc = "WestEurope"
$serverName = "server-$(Get-Random)"
$adminUsername = "myuser"
$adminPassword = (Get-AzureKeyVaultSecret –VaultName 'myKeyVault' -Name defaultPassword).SecretValueText | `
                  ConvertTo-SecureString -AsPlainText -Force
$myPublicIp = (Invoke-WebRequest ifconfig.me/ip).Content  # Either find out dynamically the client's public IP
$myPublicIp = "65.52.129.125"                             # Or hard code it
$startIp = $myPublicIp.Trim()
$endIp = $myPublicIp.Trim()
$fwRuleName = $(Get-Random).ToString()
$dbName = "mySampleDatabase"
$sku = "S0"

# Login
Add-AzureRmAccount
Select-AzureRmSubscription -Subscription $subscriptionName

# Create resource group, Azure SQL server (including firewall rules) and Azure SQL DB
New-AzureRmResourceGroup -Name $rg -Location $loc
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminUsername, $adminPassword
New-AzureRmSqlServer -ResourceGroupName $rg -Location $loc -ServerName $serverName -SqlAdministratorCredentials $creds
New-AzureRmSqlServerFirewallRule -ResourceGroupName $rg `
    -ServerName $serverName `
    -FirewallRuleName $fwRuleName -StartIpAddress $startIp -EndIpAddress $endIp
New-AzureRmSqlDatabase  -ResourceGroupName $rg `
    -ServerName $serverName `
    -DatabaseName $dbName `
    -RequestedServiceObjectiveName $sku

# For troubleshooting, you can get some information out of existing objects
$db = Get-AzureRmSqlDatabase -ResourceGroupName $rg -ServerName $serverName -DatabaseName $dbName
$server = Get-AzureRmSqlServer -ResourceGroupName $rg -ServerName $serverName
$rules = Get-AzureRmSqlServerFirewallRule -ResourceGroupName $rg -ServerName $servername

# Query DB over SQL to verify it is working
$serverFQDN = "$serverName.database.windows.net"
$adminPasswordClear = (Get-AzureKeyVaultSecret –VaultName 'myKeyVault' -Name defaultPassword).SecretValueText
$sqlQuery = "SELECT @@VERSION"
$SqlConnection.ConnectionString = "Server=tcp:$serverFQDN,1433; `
                                   Initial Catalog= $dbName; `
                                   Persist Security Info=False; `
                                   User ID = $adminUsername; `
                                   Password = $adminPasswordClear; `
                                   MultipleActiveResultSets=False; `
                                   Encrypt=True; `
                                   TrustServerCertificate=False; `
                                   Connection Timeout=30;"
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $SqlQuery
$SqlCmd.Connection = $SqlConnection
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $SqlCmd
$DataSet = New-Object System.Data.DataSet
$SqlAdapter.Fill($DataSet)
$DataSet.Tables[0].Rows[0].Column1

# Backup/Restore
# Put example bacpac in a storage container (only required if you dont have a bacpac publicly available)
$storageAccountName = "$(Get-Random)storage"
$url="https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Standard.bacpac"
$bacpacFilename="sample.bacpac"
$storageAccount = New-AzureRmStorageAccount -ResourceGroupName $rg -AccountName $storageAccountName -Location $loc -Type "Standard_LRS"
$storageAccountKey = $(Get-AzureRmStorageAccountKey -ResourceGroupName $rg -StorageAccountName $storageAccountName).Value[0]
$storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$storageContainerName = "bacpacs"
$storageContainer = New-AzureStorageContainer -Name $storageContainerName -Context $storageContext
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $bacpacFilename
Set-AzureStorageBlobContent -Container $storageContainerName -File $bacpacFilename -Context $storageContext

# Scale up to import, afterwards scale down to the original capacity
$origSku=$db.CurrentServiceObjectiveName
$tempSku="S3"
Set-AzureRmSqlDatabase -ResourceGroupName $rg -ServerName $serverName -DatabaseName $dbName -Edition "Standard" -RequestedServiceObjectiveName $tempSku

# Create import request
$importRequest = New-AzureRmSqlDatabaseImport -ResourceGroupName $rg `
    -ServerName $serverName `
    -DatabaseName $dbName `
    -DatabaseMaxSizeBytes "262144000" `
    -StorageKeyType "StorageAccessKey" `
    -StorageKey $storageAccountKey `
    -StorageUri "http://$storageAccountName.blob.core.windows.net/$storageContainerName/$bacpacFilename" `
    -Edition "Standard" `
    -ServiceObjectiveName $tempSku `
    -AdministratorLogin "$adminUsername" `
    -AdministratorLoginPassword $adminPassword

# Check import status and wait for the import to complete
$importStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
[Console]::Write("Importing")
while ($importStatus.Status -eq "InProgress")
{
    $importStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
    [Console]::Write(".")
    Start-Sleep -s 10
}
[Console]::WriteLine("")
$importStatus

# Scale down to the original service level after import is complete
Set-AzureRmSqlDatabase -ResourceGroupName $rg -ServerName $serverName -DatabaseName $dbName -Edition "Standard" -RequestedServiceObjectiveName $origSku

# Cleanup
Remove-AzureRmResourceGroup -ResourceGroupName $rg