# Create RAID0
$storagePoolName = 'DataLUN'
$storsageSubsystemId = (Get-StorageSubSystem)[0].uniqueID
$vDiskName = 'DataStore01'
New-StoragePool -FriendlyName $storagePoolName `
                -StorageSubSystemUniqueId $storsageSubsystemId `
                -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
New-VirtualDisk -FriendlyName $vDiskName `
                -StoragePoolFriendlyName $storagePoolName -useMaximumSize `
                -ResiliencySettingName Simple                     
$diskNumber = (Get-VirtualDisk -FriendlyName $vDiskName | Get-Disk).Number
Initialize-Disk -Number $diskNumber
New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter
$driveLetter = (Get-Partition | where {$_.DiskNumber -EQ $diskNumber -and $_.Type -ne 'Reserved'}).DriveLetter
Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel $vDiskName

# Enable IIS
Add-WindowsFeature -Name Web-Common-Http,Web-Asp-Net,Web-Net-Ext,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Http-Logging,Web-Request-Monitor,Web-Basic-Auth,Web-Windows-Auth,Web-Filtering,Web-Performance,Web-Mgmt-Console,Web-Mgmt-Compat,WAS -IncludeAllSubFeature
Install-WindowsFeature -Name Web-Server, Web-CGI -IncludeManagementTools

# Install Cholocatey
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install PHP
choco install php -y

# Download web site
$files = @()
$files += 'index.php'
$files += 'styles.css'
$files += 'favicon.ico'
$baseUrl = 'https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/'
$webDir = 'C:\inetpub\wwwroot\'
for ($i=0; $i -lt $urls.Count; $i++) {
  $url = $baseUrl + $files[$i]
  $outputFile = $webDir + $files[$i]
  Invoke-WebRequest -Uri $url -OutFile $outputFile
}

# Restart IIS
invoke-command -scriptblock {iisreset}

# Install additional software
choco install curl -y --force