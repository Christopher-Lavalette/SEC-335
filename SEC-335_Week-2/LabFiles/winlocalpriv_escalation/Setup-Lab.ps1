<#
.SYNOPSIS
    SEC-335 Lab Setup: Windows Local Privilege Escalation Vulnerabilities
.DESCRIPTION
    Configures a Windows 10 host with intentional misconfigurations for student learning.
    These vulnerabilities are for EDUCATIONAL PURPOSES ONLY in a controlled lab environment.
    
    All vulnerable directories and registry keys are writable by any user (Users and Everyone groups),
    so any non-admin account can exploit them.
    
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
    The non-admin lab user account to verify exists (for testing)
.EXAMPLE
    .\Setup-Lab.ps1 -LabUser "champuser"
.EXAMPLE
    .\Setup-Lab.ps1 -BenignServicePath "C:\Labs\benign\Vulnerable Service.exe" -ExploitPayloadPath "C:\Labs\exploit\Program.exe" -LabUser "student1"
.NOTES
    Author: SEC-335 Course
    Purpose: Educational lab environment for learning windows privilege escalation
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

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "ERROR: This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To run this script:" -ForegroundColor Yellow
    Write-Host "  1. Right-click PowerShell and select 'Run as administrator'" -ForegroundColor Yellow
    Write-Host "  2. Then run: .\Setup-Lab.ps1 -LabUser '$LabUser'" -ForegroundColor Yellow
    Write-Host ""
    exit 1
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
Write-Host "[*] Note: All vulnerable directories are writable by ANY user (Users and Everyone groups)" -ForegroundColor Yellow
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

# Grant write access to the directory for ANY user using icacls
icacls $serviceDir /grant "BUILTIN\Users:(OI)(CI)F" /T /Q | Out-Null
icacls $serviceDir /grant "Everyone:(OI)(CI)F" /T /Q | Out-Null

# Create service with unquoted path (the vulnerability!)
# The path C:\Program Files\Vulnerable Service\Vulnerable Service.exe
# will be parsed as: C:\Program.exe, then C:\Program Files\Vulnerable.exe, etc.
New-Service -Name "VulnSvc" `
    -BinaryPathName "C:\Program Files\Vulnerable Service\Vulnerable Service.exe" `
    -DisplayName "Vulnerable Service (Lab)" `
    -Description "SEC-335 Lab: Service with unquoted path" `
    -StartupType Manual | Out-Null

$labArtifacts.Services += "VulnSvc"
Write-Host "    Created service 'VulnSvc' with unquoted path" -ForegroundColor Gray
Write-Host "    Path: C:\Program Files\Vulnerable Service\Vulnerable Service.exe" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 2: AlwaysInstallElevated
# ============================================================
Write-Host "[2/10] Configuring AlwaysInstallElevated..." -ForegroundColor Green

# HKLM setting (applies to all users)
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
    -Name "AlwaysInstallElevated" -Value 1 -Type DWord -Force
$labArtifacts.RegistryKeys += "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"

# HKCU setting via logon script (applies to ALL users who log in)
# Create a logon script that sets HKCU\...\AlwaysInstallElevated for the current user
$logonScript = @"
@echo off
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer" /v AlwaysInstallElevated /t REG_DWORD /d 1 /f
"@

# Save the logon script to a location accessible by all users
$logonScriptPath = "C:\Windows\SEC335_SetAlwaysInstallElevated.bat"
$logonScript | Out-File -FilePath $logonScriptPath -Encoding ASCII -Force

# Add the script to all-users startup folder to run at login
$startupFolder = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
Copy-Item -Path $logonScriptPath -Destination "$startupFolder\SEC335_InstallElevated.bat" -Force

Write-Host "    Set AlwaysInstallElevated = 1 in HKLM (all users)" -ForegroundColor Gray
Write-Host "    Created logon script to set HKCU for ALL users at login" -ForegroundColor Gray
Write-Host "    Logon script: $logonScriptPath" -ForegroundColor Gray

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

# Grant write access to the directory for ANY user using icacls
icacls $weakSvcDir /grant "BUILTIN\Users:(OI)(CI)F" /T /Q | Out-Null
icacls $weakSvcDir /grant "Everyone:(OI)(CI)F" /T /Q | Out-Null

New-Service -Name "WeakSvc" `
    -BinaryPathName "`"$weakSvcBin`"" `
    -DisplayName "Weak Permission Service (Lab)" `
    -Description "SEC-335 Lab: Service with weak DACL" `
    -StartupType Manual | Out-Null

$labArtifacts.Services += "WeakSvc"

# Grant permission to change the service config for ANY user
# This uses sc.exe to modify the service SDDL
# The SDDL below grants Users and Everyone SERVICE_CHANGE_CONFIG
$sddl = (sc.exe sdshow WeakSvc) | Where-Object { $_ -match "^D:" }
# S-1-5-32-545 = BUILTIN\Users, S-1-1-0 = Everyone
$newACE = "(A;;CCLCSWRPWPDTLOCRSD;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;RPWP;;;BU)(A;;RPWP;;;WD)"
$newSddl = "D:${newACE}"
sc.exe sdset WeakSvc $newSddl | Out-Null

Write-Host "    Created service 'WeakSvc' with weak permissions" -ForegroundColor Gray
Write-Host "    Any user can modify service configuration" -ForegroundColor Gray

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

# Grant write access to the directory for ANY user using icacls
icacls $regSvcDir /grant "BUILTIN\Users:(OI)(CI)F" /T /Q | Out-Null
icacls $regSvcDir /grant "Everyone:(OI)(CI)F" /T /Q | Out-Null

New-Service -Name "RegSvc" `
    -BinaryPathName "`"$regSvcBin`"" `
    -DisplayName "Registry Weak Service (Lab)" `
    -Description "SEC-335 Lab: Service with weak registry ACL" `
    -StartupType Manual | Out-Null

$labArtifacts.Services += "RegSvc"

# Grant write access to the service registry key for ANY user
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\RegSvc"
$acl = Get-Acl $regPath
$ruleUsers = New-Object System.Security.AccessControl.RegistryAccessRule("BUILTIN\Users", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($ruleUsers)
$ruleEveryone = New-Object System.Security.AccessControl.RegistryAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($ruleEveryone)
Set-Acl -Path $regPath -AclObject $acl

Write-Host "    Created service 'RegSvc' with weak registry permissions" -ForegroundColor Gray
Write-Host "    Any user can modify ImagePath in registry" -ForegroundColor Gray

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

# Grant write access to the directory for ANY user using icacls
icacls $hijackDir /grant "BUILTIN\Users:(OI)(CI)F" /T /Q | Out-Null
icacls $hijackDir /grant "Everyone:(OI)(CI)F" /T /Q | Out-Null

# Create a service that loads DLLs from this directory
New-Service -Name "DLLHijackSvc" `
    -BinaryPathName "`"$hijackBin`"" `
    -DisplayName "DLL Hijack Service (Lab)" `
    -Description "SEC-335 Lab: Service vulnerable to DLL hijacking" `
    -StartupType Manual | Out-Null

$labArtifacts.Services += "DLLHijackSvc"

Write-Host "    Created service 'DLLHijackSvc' with writable directory" -ForegroundColor Gray
Write-Host "    Any user can place malicious DLLs in: $hijackDir" -ForegroundColor Gray

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

# Grant write access for ANY user using icacls
icacls $missingDir /grant "BUILTIN\Users:(OI)(CI)F" /T /Q | Out-Null
icacls $missingDir /grant "Everyone:(OI)(CI)F" /T /Q | Out-Null

Write-Host "    Created service 'MissingBinSvc' pointing to non-existent binary" -ForegroundColor Gray
Write-Host "    Any user can place a binary in: $missingDir" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 7: Writable PATH Directory
# ============================================================
Write-Host "[7/10] Creating writable PATH directory..." -ForegroundColor Green

$pathDir = "C:\Program Files\Common PATH"
New-Item -Path $pathDir -ItemType Directory -Force | Out-Null
$labArtifacts.Directories += $pathDir

# Grant write access to the directory for ANY user using icacls
icacls $pathDir /grant "BUILTIN\Users:(OI)(CI)F" /T /Q | Out-Null
icacls $pathDir /grant "Everyone:(OI)(CI)F" /T /Q | Out-Null

# Add to system PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$pathDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$pathDir", "Machine")
}

Write-Host "    Added writable directory to system PATH: $pathDir" -ForegroundColor Gray
Write-Host "    Any user can place malicious binaries that execute before legitimate ones" -ForegroundColor Gray

# ============================================================
# VULNERABILITY 8: Startup Folder Permissions
# ============================================================
Write-Host "[8/10] Configuring startup folder permissions..." -ForegroundColor Green

$startupDir = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

# Grant write access to the startup folder for ANY user using icacls
icacls $startupDir /grant "BUILTIN\Users:(OI)(CI)W" /T /Q | Out-Null
icacls $startupDir /grant "Everyone:(OI)(CI)W" /T /Q | Out-Null

Write-Host "    Granted 'Users' write access to all-users startup folder" -ForegroundColor Gray
Write-Host "    Any user can place executables that run at login for all users" -ForegroundColor Gray

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

# Grant write access to the directory for ANY user using icacls
icacls $schedTaskDir /grant "BUILTIN\Users:(OI)(CI)F" /T /Q | Out-Null
icacls $schedTaskDir /grant "Everyone:(OI)(CI)F" /T /Q | Out-Null

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

Write-Host "    Created scheduled task 'VulnScheduledTask' with unquoted path" -ForegroundColor Gray
Write-Host "    Any user can place malicious binary in: $schedTaskDir" -ForegroundColor Gray

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
