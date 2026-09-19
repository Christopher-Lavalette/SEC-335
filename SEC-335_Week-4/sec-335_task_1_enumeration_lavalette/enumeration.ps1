
# SEC335 - Data Staging and Exfiltration - Christopher Lavalette
# Task 1 - Enumeration
# Run with the command: "powershell -ExecutionPolicy Bypass -File C:\temp\enumeration.ps1"

$Out = "C:\temp"

New-Item -ItemType Directory -Path $Out -Force | Out-Null

# 1. Current user, groups, and privileges
whoami /all > "$Out\01-whoami.txt"

# 2. Running processes
tasklist /v > "$Out\02-tasklist.txt"

# 3. Network connections and listening ports
netstat -ano > "$Out\03-netstat.txt"

# 4. Running services
Get-Service | Format-Table -AutoSize | Out-File "$Out\04-services.txt"

# 5. Local user accounts
net user > "$Out\05-users.txt"

# 6. Local groups
net localgroup > "$Out\06-groups.txt"

# 7. Administrators group members
net localgroup Administrators > "$Out\07-admins.txt"

# 8. Network configuration
ipconfig /all > "$Out\08-ipconfig.txt"

# 9. Firewall configuration
netsh advfirewall show allprofiles > "$Out\09-firewall.txt"

# 10. ARP table
arp -a > "$Out\10-arp.txt"

# 11. SMB sessions
net session > "$Out\11-smb-sessions.txt" 2>&1

# 12. System information
systeminfo > "$Out\12-systeminfo.txt"

Write-Host "Enumeration complete!"
Write-Host "Results have been saved to 'C:\temp'"
