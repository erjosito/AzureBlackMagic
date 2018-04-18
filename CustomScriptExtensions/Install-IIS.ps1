<# 
    Install IIS with common features.
#>


#install IIS features 
$features = @("Web-Server",
"Web-WebServer",
"Web-Common-Http",
"Web-Default-Doc",
"Web-Dir-Browsing",
"Web-Http-Errors",
"Web-Static-Content",
"Web-Http-Redirect",
"Web-Health",
"Web-Http-Logging",
"Web-Custom-Logging",
"Web-Log-Libraries",
"Web-Request-Monitor",
"Web-Http-Tracing",
"Web-Performance",
"Web-Stat-Compression",
"Web-Dyn-Compression",
"Web-Security",
"Web-Filtering",
"Web-Basic-Auth",
"Web-IP-Security",
"Web-Url-Auth",
"Web-Windows-Auth",
"Web-App-Dev",
"Web-Net-Ext45",
"Web-Asp-Net45",
"Web-ISAPI-Ext",
"Web-ISAPI-Filter",
"Web-Mgmt-Tools",
"Web-Mgmt-Console",
"Web-Scripting-Tools",
"NET-Framework-45-Features",
"NET-Framework-45-Core",
"NET-Framework-45-ASPNET",
"NET-WCF-Services45",
"NET-WCF-TCP-PortSharing45")
Install-WindowsFeature -Name $features -Verbose




