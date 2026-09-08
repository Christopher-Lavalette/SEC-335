Task 2:

Bypass Method
The lab creates ten intentionally vulnerable Windows configurations that can allow local privilege escalation. The general bypass method is to identify a privileged process or service that executes a file, DLL, registry value, or startup program that can be controlled by a lower-privileged user. By controlling that resource and causing the privileged process to execute it, the payload can run with elevated privileges.

The lab was configured using:
.\Setup-Lab.ps1 -BenignServicePath "./benign-service/benign-service.exe" -ExploitPayloadPath "exploit-payload/exploit-payload.exe" -LabUser "champuser"


The Ten Vulnerabilities:

1. Unquoted Service Path - VulnSvc

The service uses the path:
C:\Program Files\Vulnerable Service\Vulnerable Service.exe

Because the path contains spaces and is not enclosed in quotation marks, Windows can incorrectly interpret the executable path. If a lower-privileged user can place an executable in a location checked during path resolution, that executable may be executed with the service's privileges.

Fix: Enclose the complete executable path in quotation marks and restrict write permissions on the service directories.


2. AlwaysInstallElevated

The lab sets AlwaysInstallElevated to 1 in the HKLM policy and creates a logon script that sets it for HKCU.

When AlwaysInstallElevated is enabled in both locations, Windows Installer can install MSI packages with elevated privileges. A non-administrator may therefore be able to execute an MSI package with SYSTEM-level privileges.

Fix: Disable AlwaysInstallElevated in both HKLM and HKCU.



3. Weak Service Permissions - WeakSvc

The lab creates WeakSvc with permissions that allow any user to modify the service configuration.

If the service runs with elevated privileges, a lower-privileged user who can modify its configuration can redirect the service to execute a different program.

Fix: Restrict service configuration permissions to administrators and other trusted accounts.


4. Weak Service Registry Permissions - RegSvc

The lab creates RegSvc with weak registry permissions that allow any user to modify its ImagePath value.

The ImagePath determines which executable the service launches. Modifying it can redirect the privileged service to a user-controlled executable.

Fix: Restrict write access to the service's registry key under:

HKLM\SYSTEM\CurrentControlSet\Services\


5. DLL Hijacking - DLLHijackSvc


The lab creates a service that uses a writable directory:

C:\Program Files\DLL Hijack App

A lower-privileged user can place a malicious DLL in a directory searched by the privileged application. If the application loads that DLL, its code executes with the application's privileges.

Fix: Prevent ordinary users from writing to privileged application directories and use secure DLL loading practices.


6. Missing Service Binary - MissingBinSvc

The lab creates a service pointing to a binary that does not exist:

C:\Program Files\Missing App

The directory is writable by users, allowing the expected executable to be supplied.

If the service starts using that executable, the supplied program executes with the service account's privileges.

Fix: Ensure service binaries exist in protected directories and prevent ordinary users from modifying those directories.


7. Writable PATH Directory

The lab adds this writable directory to the system PATH:

C:\Program Files\Common PATH

A lower-privileged user can place an executable in the directory. If a privileged process searches for an executable without using an absolute path, the attacker-controlled executable may be selected.

Fix: Remove unnecessary writable directories from the system PATH and ensure PATH directories are writable only by trusted users.


8. Writable All-Users Startup Folder

The lab grants Users write access to the all-users Startup folder.

A user can place an executable or shortcut there. It will execute when users log in, potentially providing execution in a more privileged context depending on the account performing the login.

Fix: Remove write permissions for ordinary users from the all-users Startup folder and regularly audit its contents.


9. Credentials in Unattended.xml

The lab creates:

C:\Windows\Panther\Unattended\Unattended.xml

with credentials.

Unattended Windows installation files can contain account credentials. If a privileged account's credentials are exposed, they can potentially be used to authenticate as that account.

Fix: Do not store plaintext administrative credentials in accessible unattended files. Remove temporary answer files after deployment and restrict access to deployment configuration files.


10. Unquoted Scheduled Task Path - VulnScheduledTask

The lab creates a scheduled task with an unquoted executable path and places it in:

C:\Program Files\Scheduled Task

If the task executes with elevated privileges and the path is ambiguous, a lower-privileged user may be able to exploit executable path resolution.

Fix: Quote executable paths containing spaces, restrict write permissions on task directories, and configure scheduled tasks to run with the minimum privileges required.


11. Resources

Microsoft - Service Configuration: https://learn.microsoft.com/en-us/windows/win32/services/service-configuration

Microsoft - Service Security and Access Rights: https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights

Microsoft - Machine Policies / AlwaysInstallElevated: https://learn.microsoft.com/en-us/windows/win32/msi/machine-policies

Microsoft - Dynamic-Link Library Security: https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-security

Microsoft - Task Scheduler: https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-2-0-examples

Microsoft Sysinternals Autoruns: https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns

Microsoft - Unattended Windows Setup: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/update-windows-settings-and-scripts-create-your-own-answer-file-sxs


Fix Summary

1. Unquoted service paths should be enclosed in quotation marks.

2. AlwaysInstallElevated should be disabled in both HKLM and HKCU.

3. Service configuration permissions should be restricted to administrators and trusted accounts.

4. Service registry keys should not be writable by ordinary users.

5. Privileged application directories should not be writable by ordinary users.

6. Service binaries should be stored in protected directories.

7. Writable directories should not be included in privileged PATH variables.

8. The all-users Startup folder should be protected from modification by ordinary users.

9. Credentials should not be stored in accessible unattended installation files.

10. Scheduled task executable paths should be quoted and protected with appropriate filesystem permissions.