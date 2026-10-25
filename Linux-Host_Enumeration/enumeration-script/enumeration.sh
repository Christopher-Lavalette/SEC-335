#!/bin/bash

# Christopher Lavalette
# SEC-335
# Linux Host Enumeration
# Works with root or bthomas

mkdir -p script_outputs

# Check current user
if [ "$(id -u)" -eq 0 ]; then
    ROOT=true
    echo "Running as root"
else
    ROOT=false
    echo "Running as $(whoami)"
fi

echo "Starting Linux enumeration..."

# 01 - Current User, Groups, and Privileges
{ id; groups; sudo -n -l; } > script_outputs/01_identity.txt 2>&1

# 02 - Running Processes
ps auxww > script_outputs/02_processes.txt 2>&1

# 03 - Network Connections and Listening Ports
{ ss -tulpen; ss -tunap; } > script_outputs/03_sockets.txt 2>&1

# 04 - Running Services
{ systemctl list-units --type=service --all --no-pager; service --status-all; } > script_outputs/04_services.txt 2>&1

# 05 - Local User Accounts
getent passwd > script_outputs/05_users.txt 2>&1

# 06 - Local Groups
getent group > script_outputs/06_groups.txt 2>&1

# 07 - Sudo Group Members
{ getent group sudo; id tcarpenter; id rnovelli; id nkatz; } > script_outputs/07_sudo_members.txt 2>&1

# 08 - Network Configuration
{ ip -br address; ip route; cat /etc/resolv.conf; } > script_outputs/08_network.txt 2>&1

# 09 - Firewall Configuration
if [ "$ROOT" = true ]; then
    { cat /etc/default/ufw; cat /etc/ufw/ufw.conf; ufw status verbose; iptables -S; nft list ruleset; } > script_outputs/09_firewall.txt 2>&1
else
    { cat /etc/default/ufw; cat /etc/ufw/ufw.conf; } > script_outputs/09_firewall.txt 2>&1
fi

# 10 - ARP and Neighbor Table
ip neigh show > script_outputs/10_neighbors.txt 2>&1

# 11 - SMB Sessions
if [ "$ROOT" = true ]; then
    { smbstatus; cat /proc/fs/cifs/DebugData; } > script_outputs/11_smb.txt 2>&1
else
    { command -v smbstatus; cat /proc/fs/cifs/DebugData; } > script_outputs/11_smb.txt 2>&1
fi

# 12 - System Information
{ uname -a; hostnamectl; cat /etc/os-release; } > script_outputs/12_system.txt 2>&1

# 13 - Sudo Privileges
sudo -n -l > script_outputs/13_sudo_policy.txt 2>&1

# 14 - Logged-In Users and Login History
{ who; w; last -n 20; lastb -n 20; } > script_outputs/14_sessions.txt 2>&1

# 15 - Shell History
{ ls -la ~/.bash_history ~/.zsh_history; tail -n 30 ~/.bash_history; } > script_outputs/15_history.txt 2>&1

# 16 - Environment Variables
{ env; ps -eo pid,user,comm; } > script_outputs/16_environment.txt 2>&1

# 17 - SUID and SGID Files
find /usr /bin /sbin /opt -type f \( -perm -4000 -o -perm -2000 \) -print > script_outputs/17_suid_sgid.txt 2>&1

# 18 - File Capabilities
getcap -r /usr /bin /sbin /opt > script_outputs/18_capabilities.txt 2>&1

# 19 - Scheduled Tasks
{ ls -la /etc/cron*; crontab -l; systemctl list-timers --all --no-pager; } > script_outputs/19_scheduled_tasks.txt 2>&1

# 20 - Security Software and Monitoring Tools
{ ps auxww | grep -Ei 'auditd|falco|osquery|wazuh|clamd|apparmor|crowdstrike|sentinel|defender'; dpkg -l | grep -Ei 'auditd|falco|osquery|wazuh|clamav|apparmor'; } > script_outputs/20_security_agents.txt 2>&1

# 21 - Installed Software Packages
dpkg-query -W > script_outputs/21_packages.txt 2>&1

# 22 - Kernel Version and Build Information
{ uname -r; uname -v; cat /proc/version; } > script_outputs/22_kernel.txt 2>&1

# 23 - Mounted Filesystems and Disk Space
{ findmnt; df -h; mount; } > script_outputs/23_filesystems.txt 2>&1

# 24 - SSH Configuration and Permissions
{ ls -la ~/.ssh /etc/ssh; grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AuthorizedKeysFile)' /etc/ssh/sshd_config; } > script_outputs/24_ssh.txt 2>&1

# 25 - Password File Permissions
{ ls -l /etc/passwd /etc/shadow /etc/gshadow; test -r /etc/shadow && echo "shadow readable" || echo "shadow not readable"; } > script_outputs/25_password_store.txt 2>&1

# 26 - Authentication Events and Failed Logins
if [ "$ROOT" = true ]; then
    { tail -n 50 /var/log/auth.log; lastb -n 20; } > script_outputs/26_authentication.txt 2>&1
else
    { last -n 20; who; } > script_outputs/26_authentication.txt 2>&1
fi

# 27 - Containers and Runtime Permissions
if [ "$ROOT" = true ]; then
    { docker ps; podman ps; ls -l /var/run/docker.sock /run/containerd/containerd.sock; } > script_outputs/27_containers.txt 2>&1
else
    { command -v docker; command -v podman; ls -l /var/run/docker.sock /run/containerd/containerd.sock; } > script_outputs/27_containers.txt 2>&1
fi

# 28 - SELinux and AppArmor Status
if [ "$ROOT" = true ]; then
    { getenforce; aa-status; cat /sys/module/apparmor/parameters/enabled; } > script_outputs/28_mac_status.txt 2>&1
else
    { command -v getenforce; command -v aa-status; cat /sys/module/apparmor/parameters/enabled; } > script_outputs/28_mac_status.txt 2>&1
fi

# 29 - NFS and Network Shares
if [ "$ROOT" = true ]; then
    { exportfs -v; cat /etc/exports; findmnt -t nfs,nfs4,cifs; } > script_outputs/29_shares.txt 2>&1
else
    { cat /etc/exports; findmnt -t nfs,nfs4,cifs; } > script_outputs/29_shares.txt 2>&1
fi

# 30 - Hostname and Domain Information
{ hostname; hostname -f; dnsdomainname; realm list; } > script_outputs/30_domain.txt 2>&1

# 31 - World-Writable Files and Directories
find /etc /usr/local /opt /var -xdev -perm -0002 -print > script_outputs/31_world_writable.txt 2>&1

# 32 - Open Files and Deleted Files
{ lsof -nP; lsof +L1; } > script_outputs/32_open_files.txt 2>&1

echo "Enumeration complete."
echo "Results saved in script_outputs/"
echo "Number of output files:"
find script_outputs -maxdepth 1 -type f -name '[0-9][0-9]_*.txt' | wc -l
