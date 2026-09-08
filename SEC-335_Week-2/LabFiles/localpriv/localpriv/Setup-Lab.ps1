#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SEC-335 Lab Setup: Windows Local Privilege Escalation Vulnerabilities
.DESCRIPTION
    Configures a Windows 10 host with intentional misconfigurations for student learning.
    These vulnerabilities are for EDUCATIONAL PURPOSES ONLY in a controlled lab environment.
    
    Vulnerabilities configured:
    1. Unquoted Service Path
    2. AlwaysInstallElevated
    3. Weak Service Permissions (modifiable BINARY_PATH_NAME)
    4. Weak Service Registry Permissions (modifiable ImagePath)
    5. DLL Hijacking Opportunities
    6. Missing Service Binary
    7. Writable PATH Directories
    8. Startup Folder Permissions
    9. Unattend.xml with Credentials
    10. Scheduled Task Misconfiguration

.PARAMETER BenignServicePath
    Path to the compiled benign service binary (Vulnerable Service.exe)
.PARAMETER ExploitPayloadPath
    Path to the compiled exploit payload binary (Program.exe)
.PARAMETER LabUser
    The non-admin lab user account to configure vulnerabilities for
.EXAMPLE
    .\Setup-Lab.ps1 -BenignServicePath "C:\Labs\benign\Vulnerable Service.exe" -ExploitPayloadPath "C:\Labs\exploit\Program.exe" -LabUser "student1"
.NOTES
    Author: SEC-335 Course
    Purpose: Educational lab environment for privilege escalation training
    WARNING: Run ONLY in isolated lab VMs. NEVER on production systems.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BenignServicePath = ".\benign-service\Vulnerable Service.exe",

    [Parameter(Mandatory = $false)]
    [string]$ExploitPayloadPath = ".\exploit-payload\Program.exe",

    [Parameter(Mandatory = $false)]
    [string]$LabUser = $null
)

# If LabUser not provided, try to detect current non-admin user or use default
if (-not $LabUser) {
    # Try to find a non-admin user (common lab setup)
    $LabUser = Read-Host -Prompt "Enter the lab user name (e.g., champuser, student1)"
}

# Safety check - ensure we're not running on a domain controller or production system
$osInfo = Get-WmiObject Win32_OperatingSystem
if ($osInfo.ProductType -ne 1) {
    Write-Warning "This script is designed for Windows 10 workstations only."
    Write-Warning "Server and domain controller installations are not supported."
    exit 1
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  SEC-335 Lab Setup: Privilege Escalation" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Verify binaries exist
if (-not (Test-Path $BenignServicePath)) {
    Write-Error "Benign service binary not found: $BenignServicePath"
    exit 1
}
if (-not (Test-Path $ExploitPayloadPath)) {
    Write-Error "Exploit payload binary not found: $ExploitPayloadPath"
    exit 1
}

# Verify lab user exists
$labUserObj = Get-LocalUser -Name $LabUser -ErrorAction SilentlyContinue
if (-not $labUserObj) {
    Write-Error "Lab user '$LabUser' does not exist. Create the user first."
    exit 1
}

Write-Host "[*] Configuring vulnerabilities for user: $LabUser" -ForegroundColor Yellow
Write-Host ""

# Track what we create for cleanup
$labArtifacts = @{
    Services = @()
    RegistryKeys = @()
    Directories = @()
    Files = @()
    ScheduledTasks = @()
}

# ============================================================
# VULNERABILITY 1: Unquoted Service Path
# ============================================================
Write-Host "[1/10] Creating unquoted service path vulnerability..." -ForegroundColor Green

$serviceDir = "C:\Program Files\Vulnerable Service"
$serviceBin = "$serviceDir\Vulnerable Service.exe"

# Create directory and copy binary
New-Item -Path $serviceDir -ItemType Directory -Force | Out-Null
Copy-Item -Path $BenignServicePath -Destination $serviceBin -Force
$labArtifacts.Directories += $serviceDir
$labArtifacts.Files += $serviceBin

# Create service with unquoted path (the vulnerability!)
# The path C:\Program Files\Vulnerable Service\Vulnerable Service.exe
# will be parsed as: C:\Program.exe, then C:\Program Files\Vulnerable.exe, etc.
# Note: The Go binary can also self-install with: "Vulnerable Service.exe" install
New-Service -Name "VulnSvc" `
    -BinaryPathName "C:\Program Files\Vulnerable Service\Vulnerable Service.exe" `
    -DisplayName "Vulnerable Service (Lab)" `
    -Description "SEC-335 Lab: Service with unquoted path" `
    -StartupType Manual | Out-Null

$acl = Get-Acl "C:\Program Files\Vulnerable Service"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($LabUser,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path "C:\Program Files\Vulnerable Service" -AclObject $acl

$labArtifacts.Services += "VulnSvc"
Write-Host "    Created service 'VulnSvc' with unquoted path" -ForegroundColor Gray
Write-Host "    Path: C:\Program Files\Vulnerable Service\Vulnerable Service.exe" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 2: AlwaysInstallElevated
# ============================================================
Write-Host "[2/10] Configuring AlwaysInstallElevated..." -ForegroundColor Green

# HKLM setting
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
    -Name "AlwaysInstallElevated" -Value 1 -Type DWord
$labArtifacts.RegistryKeys += "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"

# HKCU setting
New-Item -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
    -Name "AlwaysInstallElevated" -Value 1 -Type DWord
$labArtifacts.RegistryKeys += "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer"

Write-Host "    Set AlwaysInstallElevated = 1 in both HKLM and HKCU" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 3: Weak Service Permissions
# ============================================================
Write-Host "[3/10] Creating service with weak permissions..." -ForegroundColor Green

$weakSvcDir = "C:\Program Files\Weak Service"
$weakSvcBin = "$weakSvcDir\weakservice.exe"

New-Item -Path $weakSvcDir -ItemType Directory -Force | Out-Null
Copy-Item -Path $BenignServicePath -Destination $weakSvcBin -Force
$labArtifacts.Directories += $weakSvcDir
$labArtifacts.Files += $weakSvcBin

New-Service -Name "WeakSvc" `
    -BinaryPathName "`"$weakSvcBin`"" `
    -DisplayName "Weak Permission Service (Lab)" `
    -Description "SEC-335 Lab: Service with weak DACL" `
    -StartupType Manual | Out-Null

$labArtifacts.Services += "WeakSvc"

# Grant the lab user permission to change the service config
# This uses sc.exe to modify the service SDDL
# The SDDL below grants the lab user SERVICE_CHANGE_CONFIG
$labUserSID = (New-Object System.Security.Principal.NTAccount($LabUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
$sddl = (sc.exe sdshow WeakSvc) | Where-Object { $_ -match "^D:" }
$newACE = "(A;;CCLCSWRPWPDTLOCRSD;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;RPWP;;;${labUserSID})"
$newSddl = "D:${newACE}"
sc.exe sdset WeakSvc $newSddl | Out-Null
$acl = Get-Acl "C:\Program Files\Weak Service"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $LabUser,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path "C:\Program Files\Weak Service" -AclObject $acl

Write-Host "    Created service 'WeakSvc' with weak permissions" -ForegroundColor Gray
Write-Host "    User '$LabUser' can modify service configuration" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 4: Weak Service Registry Permissions
# ============================================================
Write-Host "[4/10] Creating service with weak registry permissions..." -ForegroundColor Green

$regSvcDir = "C:\Program Files\Registry Service"
$regSvcBin = "$regSvcDir\regservice.exe"

New-Item -Path $regSvcDir -ItemType Directory -Force | Out-Null
Copy-Item -Path $BenignServicePath -Destination $regSvcBin -Force
$labArtifacts.Directories += $regSvcDir
$labArtifacts.Files += $regSvcBin

New-Service -Name "RegSvc" `
    -BinaryPathName "`"$regSvcBin`"" `
    -DisplayName "Registry Weak Service (Lab)" `
    -Description "SEC-335 Lab: Service with weak registry ACL" `
    -StartupType Manual | Out-Null

$labArtifacts.Services += "RegSvc"

# Grant the lab user write access to the service registry key
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\RegSvc"
$acl = Get-Acl $regPath
$rule = New-Object System.Security.AccessControl.RegistryAccessRule(
    $LabUser,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $regPath -AclObject $acl

Write-Host "    Created service 'RegSvc' with weak registry permissions" -ForegroundColor Gray
Write-Host "    User '$LabUser' can modify ImagePath in registry" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 5: DLL Hijacking Opportunity
# ============================================================
Write-Host "[5/10] Creating DLL hijacking opportunity..." -ForegroundColor Green

$hijackDir = "C:\Program Files\DLL Hijack App"
$hijackBin = "$hijackDir\hijackapp.exe"

New-Item -Path $hijackDir -ItemType Directory -Force | Out-Null
Copy-Item -Path $BenignServicePath -Destination $hijackBin -Force
$labArtifacts.Directories += $hijackDir
$labArtifacts.Files += $hijackBin

# Create a service that loads DLLs from this directory
New-Service -Name "DLLHijackSvc" `
    -BinaryPathName "`"$hijackBin`"" `
    -DisplayName "DLL Hijack Service (Lab)" `
    -Description "SEC-335 Lab: Service vulnerable to DLL hijacking" `
    -StartupType Manual | Out-Null

$labArtifacts.Services += "DLLHijackSvc"

# Grant the lab user write access to the directory (so they can place DLLs)
$acl = Get-Acl $hijackDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($LabUser,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path $hijackDir -AclObject $acl

Write-Host "    Created service 'DLLHijackSvc' with writable directory" -ForegroundColor Gray
Write-Host "    User '$LabUser' can place malicious DLLs in: $hijackDir" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 6: Missing Service Binary
# ============================================================
Write-Host "[6/10] Creating service with missing binary..." -ForegroundColor Green

# Create a service pointing to a non-existent binary
New-Service -Name "MissingBinSvc" `
    -BinaryPathName "C:\Program Files\Missing App\missing.exe" `
    -DisplayName "Missing Binary Service (Lab)" `
    -Description "SEC-335 Lab: Service with missing binary" `
    -StartupType Manual | Out-Null

$labArtifacts.Services += "MissingBinSvc"

# Create the directory but NOT the binary, and make it writable
$missingDir = "C:\Program Files\Missing App"
New-Item -Path $missingDir -ItemType Directory -Force | Out-Null
$labArtifacts.Directories += $missingDir

$acl = Get-Acl $missingDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $LabUser,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $missingDir -AclObject $acl

Write-Host "    Created service 'MissingBinSvc' pointing to non-existent binary" -ForegroundColor Gray
Write-Host "    User '$LabUser' can place a binary in: $missingDir" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 7: Writable PATH Directory
# ============================================================
Write-Host "[7/10] Creating writable PATH directory..." -ForegroundColor Green

$pathDir = "C:\Program Files\Common PATH"
New-Item -Path $pathDir -ItemType Directory -Force | Out-Null
$labArtifacts.Directories += $pathDir

# Grant write access to the lab user
$acl = Get-Acl $pathDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $LabUser,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $pathDir -AclObject $acl

# Add to system PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$pathDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$pathDir", "Machine")
}

Write-Host "    Added writable directory to system PATH: $pathDir" -ForegroundColor Gray
Write-Host "    User '$LabUser' can place malicious binaries that execute before legitimate ones" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 8: Startup Folder Permissions
# ============================================================
Write-Host "[8/10] Configuring startup folder permissions..." -ForegroundColor Green

$startupDir = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

# Grant write access to the lab user
$acl = Get-Acl $startupDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $LabUser,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $startupDir -AclObject $acl

Write-Host "    Granted '$LabUser' write access to all-users startup folder" -ForegroundColor Gray
Write-Host "    User can place executables that run at login for all users" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 9: Unattend.xml with Credentials
# ============================================================
Write-Host "[9/10] Creating unattend.xml with credentials..." -ForegroundColor Green

$unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <UserData>
                <ProductKey>
                    <WillShowUI>Never</WillShowUI>
                    <Key>XXXXX-XXXXX-XXXXX-XXXXX-XXXXX</Key>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
                <FullName>Lab User</FullName>
                <Organization>SEC-335 Lab</Organization>
            </UserData>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <AutoLogon>
                <Password>
                    <Value>P@ssw0rd123!</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <Username>Administrator</Username>
            </AutoLogon>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <UserAccounts>
                <AdministratorPassword>
                    <Value>SuperSecretAdmin2024!</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
    </settings>
</unattend>
"@

$unattendPath = "C:\Windows\Panther\Unattend\Unattended.xml"
$unattendDir = Split-Path $unattendPath
if (-not (Test-Path $unattendDir)) {
    New-Item -Path $unattendDir -ItemType Directory -Force | Out-Null
}
$unattendXml | Out-File -FilePath $unattendPath -Encoding UTF8
$labArtifacts.Files += $unattendPath

Write-Host "    Created unattend.xml with plaintext credentials" -ForegroundColor Gray
Write-Host "    Location: $unattendPath" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 10: Scheduled Task Misconfiguration
# ============================================================
Write-Host "[10/10] Creating vulnerable scheduled task..." -ForegroundColor Green

$schedTaskDir = "C:\Program Files\Scheduled Task"
$schedTaskBin = "$schedTaskDir\taskrunner.exe"

New-Item -Path $schedTaskDir -ItemType Directory -Force | Out-Null
Copy-Item -Path $BenignServicePath -Destination $schedTaskBin -Force
$labArtifacts.Directories += $schedTaskDir
$labArtifacts.Files += $schedTaskBin

# Create scheduled task with unquoted path
$action = New-ScheduledTaskAction -Execute "C:\Program Files\Scheduled Task\taskrunner.exe"
$trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "VulnScheduledTask" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "SEC-335 Lab: Scheduled task with unquoted path" | Out-Null

$labArtifacts.ScheduledTasks += "VulnScheduledTask"

# Grant write access to the directory
$acl = Get-Acl $schedTaskDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $LabUser,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $schedTaskDir -AclObject $acl

Write-Host "    Created scheduled task 'VulnScheduledTask' with unquoted path" -ForegroundColor Gray
Write-Host "    User '$LabUser' can place malicious binary in: $schedTaskDir" -ForegroundColor Gray

# ============================================================
# Save artifact manifest for cleanup
# ============================================================
Write-Host ""
Write-Host "[*] Saving lab artifact manifest..." -ForegroundColor Yellow

$manifestPath = "C:\SEC335-Lab-Manifest.json"
$labArtifacts | ConvertTo-Json | Out-File -FilePath $manifestPath -Encoding UTF8

Write-Host "    Manifest saved to: $manifestPath" -ForegroundColor Gray

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Lab Setup Complete!" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vulnerabilities configured:" -ForegroundColor White
Write-Host "  [1] Unquoted Service Path - VulnSvc" -ForegroundColor Yellow
Write-Host "  [2] AlwaysInstallElevated - HKLM + HKCU" -ForegroundColor Yellow
Write-Host "  [3] Weak Service Permissions - WeakSvc" -ForegroundColor Yellow
Write-Host "  [4] Weak Registry Permissions - RegSvc" -ForegroundColor Yellow
Write-Host "  [5] DLL Hijacking - DLLHijackSvc" -ForegroundColor Yellow
Write-Host "  [6] Missing Service Binary - MissingBinSvc" -ForegroundColor Yellow
Write-Host "  [7] Writable PATH Directory" -ForegroundColor Yellow
Write-Host "  [8] Startup Folder Permissions" -ForegroundColor Yellow
Write-Host "  [9] Unattend.xml with Credentials" -ForegroundColor Yellow
Write-Host "  [10] Scheduled Task - VulnScheduledTask" -ForegroundColor Yellow
Write-Host ""
Write-Host "Lab user: $LabUser" -ForegroundColor White
Write-Host ""
Write-Host "To verify vulnerabilities, run the detection script as ${LabUser}:" -ForegroundColor White
Write-Host "  .\Invoke-Privesc.ps1 -Groups 'Users,Everyone,Authenticated Users' -Whoami" -ForegroundColor Gray
Write-Host ""
Write-Host "To clean up, run:" -ForegroundColor White
Write-Host "  .\Cleanup-Lab.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT: Run Cleanup-Lab.ps1 when the lab is complete!" -ForegroundColor Red
