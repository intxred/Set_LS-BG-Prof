Windows Branding Automator
A robust Batch/PowerShell hybrid script designed to automate corporate branding across Windows 10 and 11 environments. This tool programmatically sets the Desktop Wallpaper, Lock Screen, and User Account Profile Picture—bypassing standard permission restrictions.

## Features
⚡ Zero-Touch Elevation: Automatically detects and requests Administrator privileges.

🔍 Dynamic Asset Discovery: Scans all available drives (USB, Local, Network) for the \lab source folder.

🖥️ Lock Screen Enforcement: Utilizes the PersonalizationCSP registry path for enterprise-level enforcement.

🖼️ Real-Time Wallpaper Update: Calls the SystemParametersInfo Win32 API to refresh the wallpaper instantly without requiring a restart.

👤 Profile Picture Injection: Orchestrates a SYSTEM-level task to take ownership of protected account picture directories and apply custom logos.

🧹 Automated Cleanup: Self-deletes temporary scripts and scheduled tasks upon completion.

## File Structure Requirements
The script is hardcoded to look for a specific folder structure on any connected drive root. Ensure your assets are named exactly as follows:

Plaintext
[Any Drive]:\
└── lab\
    ├── File.png  <-- (Used for Wallpaper & Lock Screen)
    └── File.png                    <-- (Used for Profile Picture)
## Installation & Usage
Download the script (e.g., SetBranding.bat).

Prepare your source media (USB drive or local partition) with the \lab folder and images.

Run the script by right-clicking and selecting Run as Administrator.

Completion: A popup will notify you once the process is finished.

Note: While the wallpaper and lock screen update almost immediately, Windows requires a Sign Out/Sign In to refresh the Profile Picture in the Start Menu and Settings app.

## Technical Deep Dive
How it bypasses restrictions:
Wallpaper: Instead of just changing a registry key (which often requires a restart), this script injects C# code into PowerShell to communicate directly with user32.dll.

Profile Pictures: Windows protects the AccountPictures folder with strict SID-based permissions. The script generates a temporary NT AUTHORITY\SYSTEM task to perform a takeown and icacls command, allowing the image swap to succeed.

Hybrid Architecture: The .bat wrapper ensures easy execution, while the embedded PowerShell handles the complex logic.

## Configuration
The script copies all assets to a local "staging" area to ensure reliability:

Staging Path: C:\Users\Public\lab

Registry Paths Targeted:

HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP

HKCU\Control Panel\Desktop

HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\

## Disclaimer
This script modifies system registry keys and file permissions. It is intended for use by system administrators in a controlled environment. Always test on a virtual machine before deploying to production workstations.
