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
$driveLetter = (Get-Partition | where {$_.DiskNumber -eq $diskNumber -and $_.Type -ne 'Reserved'}).DriveLetter
Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel $vDiskName

# Enable IIS
Add-WindowsFeature -Name Web-Common-Http,Web-Asp-Net,Web-Net-Ext,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Http-Logging,Web-Request-Monitor,Web-Basic-Auth,Web-Windows-Auth,Web-Filtering,Web-Performance,Web-Mgmt-Console,Web-Mgmt-Compat,WAS -IncludeAllSubFeature
Install-WindowsFeature -Name Web-Server, Web-CGI -IncludeManagementTools

# Install Cholocatey
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install PHP
choco install php -y

# Configure IIS to use PHP
# Find the exec and ini files
$phpDir = Get-ChildItem C:\Tools -filter "php*" -Directory | % { $_.fullname }
$php = $phpDir + '\php-cgi.exe'
$ini = $phpDir + '\php.ini'
# Adds a FastCGI process pool in IIS
$configPath = get-webconfiguration 'system.webServer/fastcgi/application' | where-object { $_.fullPath -eq $php }
if (!$configPath) {
    add-webconfiguration 'system.webserver/fastcgi' -value @{'fullPath' = $php }
}
# Create IIS handler mapping for handling PHP requests
$handlerName = "PHP"
$handler = get-webconfiguration 'system.webserver/handlers/add' | where-object { $_.Name -eq $handlerName }
if (!$handler) {
    add-webconfiguration 'system.webServer/handlers' -Value @{
        Name = $handlerName;
        Path = "*.php";
        Verb = "*";
        Modules = "FastCgiModule";
        scriptProcessor=$php;
        resourceType='Either' 
    }
}
# Configure the FastCGI Setting
# Set the max request environment variable for PHP
$configPath = "system.webServer/fastCgi/application[@fullPath='$php']/environmentVariables/environmentVariable"
$config = Get-WebConfiguration $configPath
if (!$config) {
    $configPath = "system.webServer/fastCgi/application[@fullPath='$php']/environmentVariables"
    Add-WebConfiguration $configPath -Value @{ 'Name' = 'PHP_FCGI_MAX_REQUESTS'; Value = 10050 }
}
# Configure the settings
# Available settings: 
#     instanceMaxRequests, monitorChangesTo, stderrMode, signalBeforeTerminateSeconds
#     activityTimeout, requestTimeout, queueLength, rapidFailsPerMinute, 
#     flushNamedPipe, protocol   
$configPath = "system.webServer/fastCgi/application[@fullPath='$php']"
Set-WebConfigurationProperty $configPath -Name instanceMaxRequests -Value 10000
Set-WebConfigurationProperty $configPath -Name monitorChangesTo -Value $ini
# Restart IIS to load new configs.
invoke-command -scriptblock {iisreset /restart }

# Download web site
$files = @()
$files += 'index.php'
$files += 'styles.css'
$files += 'favicon.ico'
$baseUrl = 'https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/'
$webDir = 'C:\inetpub\wwwroot\'
for ($i=0; $i -lt $files.Count; $i++) {
  $url = $baseUrl + $files[$i]
  $outputFile = $webDir + $files[$i]
  Invoke-WebRequest -Uri $url -OutFile $outputFile
}

# Restart IIS
invoke-command -scriptblock {iisreset}

# Install additional software
choco install curl -y --force