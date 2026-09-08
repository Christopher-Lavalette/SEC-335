# SEC-335 Lab: Windows Local Privilege Escalation

This lab environment teaches students how to identify and exploit common Windows misconfigurations that lead to local privilege escalation.

## Directory Structure

```
unquoted-service-path/
├── benign-service/           # Legitimate Windows service (Go)
│   ├── main.go              # Service implementation using kardianos/service
│   ├── go.mod               # Go module definition
│   └── go.sum               # Dependency checksums
├── exploit-payload/          # Benign exploit payload (Go)
│   ├── main.go              # Payload implementation
│   ├── go.mod               # Go module definition
│   └── go.sum               # Dependency checksums
├── Setup-Lab.ps1            # Instructor script to configure vulnerabilities
├── Cleanup-Lab.ps1          # Instructor script to remove vulnerabilities
├── LAB-GUIDE.md             # Student lab instructions
└── README.md                # This file
```

## Quick Start

### For Instructors

1. **Build the binaries** (on a Go-enabled machine):
   ```powershell
   # Build legitimate service
   cd benign-service
   $env:GOOS = "windows"; $env:GOARCH = "amd64"
   go build -o "Vulnerable Service.exe" .
   
   # Build exploit payload
   cd ../exploit-payload
   go build -o "Program.exe" .
   ```

2. **Set up the lab** (run as Administrator on the lab VM):
   ```powershell
   .\Setup-Lab.ps1 -BenignServicePath "C:\Labs\benign-service\Vulnerable Service.exe" `
                   -ExploitPayloadPath "C:\Labs\exploit-payload\Program.exe" `
                   -LabUser "student1"
   ```

3. **Clean up after lab** (run as Administrator):
   ```powershell
   .\Cleanup-Lab.ps1
   ```

### For Students

1. Read `LAB-GUIDE.md` for detailed instructions
2. Use `Invoke-Privesc.ps1` to identify vulnerabilities
3. Exploit each vulnerability following the guide
4. Document your findings and remediation steps

## Vulnerabilities Included

| # | Vulnerability | Service/Location | Difficulty |
|---|---------------|------------------|------------|
| 1 | Unquoted Service Path | VulnSvc | Easy |
| 2 | AlwaysInstallElevated | HKLM + HKCU | Easy |
| 3 | Weak Service Permissions | WeakSvc | Medium |
| 4 | Weak Registry Permissions | RegSvc | Medium |
| 5 | DLL Hijacking | DLLHijackSvc | Medium |
| 6 | Missing Service Binary | MissingBinSvc | Easy |
| 7 | Writable PATH Directory | C:\Program Files\Common PATH | Easy |
| 8 | Startup Folder Permissions | All-users startup | Easy |
| 9 | Unattend.xml Credentials | C:\Windows\Panther | Easy |
| 10 | Scheduled Task | VulnScheduledTask | Medium |

## Go Service Features

Both Go binaries use [kardianos/service](https://github.com/kardianos/service) for proper Windows service integration:

- **Service Management**: Install, uninstall, start, stop via command-line arguments
- **Logging**: Writes execution logs to `service_execution.log` in the binary's directory
- **Heartbeat**: Legitimate service logs periodic heartbeats every 30 seconds
- **Marker Files**: Exploit payload creates `exploit_success.txt` to prove execution

### Service Commands

```powershell
# Install as Windows service
"Vulnerable Service.exe" install

# Start the service
"Vulnerable Service.exe" start

# Check status
"Vulnerable Service.exe" status

# Stop the service
"Vulnerable Service.exe" stop

# Uninstall
"Vulnerable Service.exe" uninstall
```

## Safety Notes

- **Isolated Environment Only**: Run these labs ONLY in isolated VMs
- **No Production Systems**: Never run on production or domain-joined systems
- **Clean Up**: Always run `Cleanup-Lab.ps1` when finished
- **Benign Payloads**: The exploit payloads only create marker files, no actual malicious activity

## Requirements

- Windows 10 VM (not domain-joined)
- Go 1.21+ (for building binaries)
- PowerShell 5.1+ (for setup/cleanup scripts)
- Administrator access (for setup/cleanup)
- Non-admin user account (for student exploitation)

## Resources

- [MITRE ATT&CK: Privilege Escalation](https://attack.mitre.org/tactics/TA0004/)
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings)
- [HackTricks](https://book.hacktricks.xyz/windows-hardening/windows-local-privilege-escalation)
