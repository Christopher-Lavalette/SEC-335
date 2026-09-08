#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SEC-335 Lab Cleanup: Remove all privilege escalation vulnerabilities
.DESCRIPTION
    Removes all artifacts created by Setup-Lab.ps1 using the saved manifest.
    Run this script when the lab is complete to restore the system to a clean state.
.EXAMPLE
    .\Cleanup-Lab.ps1
.NOTES
    Author: SEC-335 Course
    Purpose: Clean up educational lab environment
#>

[CmdletBinding()]
param()

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  SEC-335 Lab Cleanup" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Load manifest
$manifestPath = "C:\SEC335-Lab-Manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Error "Lab manifest not found: $manifestPath"
    Write-Error "Cannot clean up without knowing what was created."
    exit 1
}

$artifacts = Get-Content $manifestPath | ConvertFrom-Json

Write-Host "[*] Loading lab manifest from: $manifestPath" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# Remove Scheduled Tasks
# ============================================================
Write-Host "[1/6] Removing scheduled tasks..." -ForegroundColor Green
foreach ($task in $artifacts.ScheduledTasks) {
    $existingTask = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false
        Write-Host "    Removed scheduled task: $task" -ForegroundColor Gray
    } else {
        Write-Host "    Scheduled task not found (already removed?): $task" -ForegroundColor DarkGray
    }
}

# ============================================================
# Remove Services
# ============================================================
Write-Host "[2/6] Removing services..." -ForegroundColor Green
foreach ($svc in $artifacts.Services) {
    $existingSvc = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($existingSvc) {
        # Stop the service if running
        if ($existingSvc.Status -eq 'Running') {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }
        # Delete the service
        sc.exe delete $svc | Out-Null
        Write-Host "    Removed service: $svc" -ForegroundColor Gray
    } else {
        Write-Host "    Service not found (already removed?): $svc" -ForegroundColor DarkGray
    }
}

# ============================================================
# Remove Registry Keys
# ============================================================
Write-Host "[3/6] Removing registry keys..." -ForegroundColor Green
foreach ($regKey in $artifacts.RegistryKeys) {
    if (Test-Path $regKey) {
        # Remove specific values we set
        Remove-ItemProperty -Path $regKey -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
        
        # Remove the key if it's empty (only had our lab values)
        $properties = Get-ItemProperty -Path $regKey -ErrorAction SilentlyContinue
        $ourProperties = $properties.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }
        if ($ourProperties.Count -eq 0) {
            Remove-Item -Path $regKey -Force -ErrorAction SilentlyContinue
        }
        Write-Host "    Cleaned registry key: $regKey" -ForegroundColor Gray
    } else {
        Write-Host "    Registry key not found (already removed?): $regKey" -ForegroundColor DarkGray
    }
}

# ============================================================
# Remove Files
# ============================================================
Write-Host "[4/6] Removing files..." -ForegroundColor Green
foreach ($file in $artifacts.Files) {
    if (Test-Path $file) {
        Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        Write-Host "    Removed file: $file" -ForegroundColor Gray
    } else {
        Write-Host "    File not found (already removed?): $file" -ForegroundColor DarkGray
    }
}

# ============================================================
# Remove Directories
# ============================================================
Write-Host "[5/6] Removing directories..." -ForegroundColor Green
foreach ($dir in $artifacts.Directories) {
    if (Test-Path $dir) {
        # Check if directory is empty (or only contains our lab files)
        $contents = Get-ChildItem -Path $dir -Force -ErrorAction SilentlyContinue
        if ($contents.Count -eq 0) {
            Remove-Item -Path $dir -Force -ErrorAction SilentlyContinue
            Write-Host "    Removed directory: $dir" -ForegroundColor Gray
        } else {
            Write-Host "    Directory not empty, skipping: $dir" -ForegroundColor DarkGray
            Write-Host "      Contents: $($contents.Name -join ', ')" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "    Directory not found (already removed?): $dir" -ForegroundColor DarkGray
    }
}

# ============================================================
# Clean up PATH
# ============================================================
Write-Host "[6/6] Cleaning up PATH..." -ForegroundColor Green

$pathDir = "C:\Program Files\Common PATH"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -like "*$pathDir*") {
    $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $pathDir }) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "    Removed '$pathDir' from system PATH" -ForegroundColor Gray
}

# ============================================================
# Remove manifest
# ============================================================
Write-Host ""
Write-Host "[*] Removing lab manifest..." -ForegroundColor Yellow
Remove-Item -Path $manifestPath -Force -ErrorAction SilentlyContinue
Write-Host "    Removed: $manifestPath" -ForegroundColor Gray

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Lab Cleanup Complete!" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "All lab artifacts have been removed." -ForegroundColor White
Write-Host ""
Write-Host "Recommended next steps:" -ForegroundColor White
Write-Host "  1. Restart the system to ensure all services are fully unloaded" -ForegroundColor Gray
Write-Host "  2. Run the detection script to verify no vulnerabilities remain:" -ForegroundColor Gray
Write-Host "     .\Invoke-Privesc.ps1 -Groups 'Users,Everyone,Authenticated Users' -Whoami" -ForegroundColor Gray
Write-Host ""
