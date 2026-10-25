#!/bin/bash

# Christopher Lavalette
# SEC-335 
# Linux Host Enumeration
# Save results in script_outputs


mkdir -p script_outputs

echo "Starting enumeration..."

# 01 - User information
id > script_outputs/01_identity.txt 2>&1
groups >> script_outputs/01_identity.txt 2>&1
sudo -n -l >> script_outputs/01_identity.txt 2>&1

# 02 - Running processes
ps aux > script_outputs/02_processes.txt 2>&1

# 03 - Network connections
ss -tulpen > script_outputs/03_sockets.txt 2>&1

# 04 - Services
systemctl list-units --type=service --all --no-pager > script_outputs/04_services.txt 2>&1

# 05 - Users
getent passwd > script_outputs/05_users.txt 2>&1

# 06 - Groups
getent group > script_outputs/06_groups.txt 2>&1

# 07 - Sudo group members
getent group sudo > script_outputs/07_sudo_members.txt 2>&1

# 08 - Network configuration
ip address > script_outputs/08_network.txt 2>&1
ip route >> script_outputs/08_network.txt 2>&1

# 09 - Firewall
ufw status verbose > script_outputs/09_firewall.txt 2>&1

# 10 - ARP table
ip neigh > script_outputs/10_neighbors.txt 2>&1

# 11 - SMB information
smbstatus > script_outputs/11_smb.txt 2>&1

# 12 - System information
uname -a > script_outputs/12_system.txt 2>&1
cat /etc/os-release >> script_outputs/12_system.txt 2>&1

# 13 - Sudo permissions
sudo -n -l > script_outputs/13_sudo_policy.txt 2>&1

# 14 - Login sessions
who > script_outputs/14_sessions.txt 2>&1
w >> script_outputs/14_sessions.txt 2>&1
last -n 20 >> script_outputs/14_sessions.txt 2>&1

# 15 - Shell history
history > script_outputs/15_history.txt 2>&1
tail -n 30 ~/.bash_history >> script_outputs/15_history.txt 2>&1

# 16 - Environment variables
env > script_outputs/16_environment.txt 2>&1

# 17 - SUID and SGID files
find /usr /bin /sbin /opt -type f -perm-4000-o-perm-2000 > script_outputs/17_suid_sgid.txt 2>&1

# 18 - Linux capabilities
getcap -r /usr /bin /sbin /opt > script_outputs/18_capabilities.txt 2>&1

# 19 - Scheduled tasks
ls -la /etc/cron* > script_outputs/19_scheduled_tasks.txt 2>&1
crontab -l >> script_outputs/19_scheduled_tasks.txt 2>&1

# 20 - Security software
ps aux | grep -Ei "auditd|falco|osquery|wazuh|clamav|apparmor" > script_outputs/20_security_agents.txt 2>&1

# 21 - Installed packages
dpkg-query -W > script_outputs/21_packages.txt 2>&1

# 22 - Kernel version
uname -r > script_outputs/22_kernel.txt 2>&1
cat /proc/version >> script_outputs/22_kernel.txt 2>&1

# 23 - Mounted filesystems
df -h > script_outputs/23_filesystems.txt 2>&1
mount >> script_outputs/23_filesystems.txt 2>&1

# 24 - SSH configuration
ls -la /etc/ssh > script_outputs/24_ssh.txt 2>&1

# 25 - Password file permissions
ls -l /etc/passwd /etc/shadow /etc/gshadow > script_outputs/25_password_store.txt 2>&1

# 26 - Authentication logs
tail -n 50 /var/log/auth.log > script_outputs/26_authentication.txt 2>&1

# 27 - Containers
docker ps > script_outputs/27_containers.txt 2>&1

# 28 - AppArmor status
aa-status > script_outputs/28_mac_status.txt 2>&1

# 29 - Network shares
cat /etc/exports > script_outputs/29_shares.txt 2>&1
findmnt -t nfs,nfs4,cifs >> script_outputs/29_shares.txt 2>&1

# 30 - Domain information
hostname -f > script_outputs/30_domain.txt 2>&1
dnsdomainname >> script_outputs/30_domain.txt 2>&1

# 31 - World-writable files
find /etc /usr/local /opt /var -xdev -perm -0002 > script_outputs/31_world_writable.txt 2>&1

# 32 - Open files
lsof -nP > script_outputs/32_open_files.txt 2>&1

echo "Enumeration complete."
echo "Results saved in script_outputs/"
echo "Number of output files:"
ls script_outputs/*.txt | wc -l


