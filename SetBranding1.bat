@echo off
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -WindowStyle Hidden -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -ExecutionPolicy Bypass -NoProfile -Command "Get-Content -LiteralPath '%~f0' | Select-Object -Skip 9 | Out-String | Invoke-Expression"
exit /b

# 1. Set up the Windows Script Host to create GUI message boxes
$wshell = New-Object -ComObject Wscript.Shell

# 2. Safely get the true interactive user
$TargetUser = (Get-WMIObject -class Win32_ComputerSystem | select username).username -replace ".*\\"
if (-not $TargetUser) { $TargetUser = $env:USERNAME }

# 3. Dynamically scan all drives to find the 'lab' folder
$sourceDir = $null
foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Root) {
    $testPath = Join-Path $drive "lab\Platinum Outsourcing Brand (1).png"
    if (Test-Path $testPath) {
        $sourceDir = Join-Path $drive "lab"
        break
    }
}

if (-not $sourceDir) {
    $wshell.Popup("ERROR: 'lab' folder with branding images not found on any drive.", 0, "Drive Not Found", 16) | Out-Null
    exit
}

# 4. Define paths and copy files to C:\Users\Public\lab
$lockImageSrc = Join-Path $sourceDir "Platinum Outsourcing Brand (1).png"
$wallImageSrc = Join-Path $sourceDir "Platinum Outsourcing Brand (1).png"
$profImageSrc = Join-Path $sourceDir "PlatservLogo.png"

$destDir = "C:\Users\Public\lab"
$lockImageDest = Join-Path $destDir "Platinum Outsourcing Brand (1).png"
$wallImageDest = Join-Path $destDir "Platinum Outsourcing Brand (1).png"
$profImageDest = Join-Path $destDir "PlatservLogo.png"

if (!(Test-Path $destDir)) { New-Item -ItemType Directory $destDir -Force | Out-Null }
Copy-Item $lockImageSrc $lockImageDest -Force
Copy-Item $wallImageSrc $wallImageDest -Force
Copy-Item $profImageSrc $profImageDest -Force

# ==============================================================================
# 5. Apply Lock Screen (Enterprise Lock - Prevents User from Changing)
# ==============================================================================
$lockRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
if (!(Test-Path $lockRegPath)) { New-Item $lockRegPath -Force | Out-Null }
Set-ItemProperty $lockRegPath LockScreenImagePath   $lockImageDest -Type String -Force
Set-ItemProperty $lockRegPath LockScreenImageUrl    $lockImageDest -Type String -Force
Set-ItemProperty $lockRegPath LockScreenImageStatus 1 -Type DWord -Force

# ==============================================================================
# 6. Apply Wallpaper (Run as Standard INTERACTIVE User to target correct HKCU)
# ==============================================================================
$UserScriptPath = "C:\Users\Public\lab\ApplyUserBranding.ps1"
$UserScriptContent = @'
$wallImageDest = "C:\Users\Public\lab\Platinum Outsourcing Brand (1).png"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper  -Value "0"
[Wallpaper]::SystemParametersInfo(0x0014, 0, $wallImageDest, 0x0003) | Out-Null
'@
Set-Content -Path $UserScriptPath -Value $UserScriptContent -Force

$UserAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$UserScriptPath`""
$UserPrincipal = New-ScheduledTaskPrincipal -UserId $TargetUser -LogonType Interactive
$UserTask = New-ScheduledTask -Action $UserAction -Principal $UserPrincipal
Register-ScheduledTask -TaskName "SetBranding_UserTask" -InputObject $UserTask -Force | Out-Null
Start-ScheduledTask -TaskName "SetBranding_UserTask" | Out-Null

# ==============================================================================
# 7. Apply Profile Picture (Run as SYSTEM account to bypass restrictions)
# ==============================================================================
$SysScriptPath = "C:\Users\Public\lab\ApplyProfilePic.ps1"
$SystemScriptContent = @'
param($TargetUser)
$User = Get-LocalUser -Name $TargetUser -ErrorAction SilentlyContinue
if (-not $User) { exit }
$SID = $User.SID.Value

$DestFolder = "$env:PUBLIC\AccountPictures\$SID"
if (-not (Test-Path $DestFolder)) { New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null }

takeown.exe /F $DestFolder /R /A /D Y | Out-Null
icacls.exe $DestFolder /grant SYSTEM:F /T /C /Q | Out-Null
Get-ChildItem -Path $DestFolder -File -Force | ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }

$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$SID"
if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }

$ImageSizes = @(32, 40, 48, 96, 192, 200, 240, 448)
foreach ($Size in $ImageSizes) {
    $DestImage = Join-Path $DestFolder "Image$Size.jpg"
    Copy-Item -Path "C:\Users\Public\lab\PlatservLogo.png" -Destination $DestImage -Force
    Set-ItemProperty -Path $RegPath -Name "Image$Size" -Value $DestImage -Force
}
'@
Set-Content -Path $SysScriptPath -Value $SystemScriptContent -Force

$SysAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SysScriptPath`" `"$TargetUser`""
$SysPrincipal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$SysTask = New-ScheduledTask -Action $SysAction -Principal $SysPrincipal
Register-ScheduledTask -TaskName "SetBranding_ProfileTask" -InputObject $SysTask -Force | Out-Null
Start-ScheduledTask -TaskName "SetBranding_ProfileTask" | Out-Null

# ==============================================================================
# 8. Wait for Tasks to Finish and Clean Up
# ==============================================================================
Start-Sleep -Seconds 5

Unregister-ScheduledTask -TaskName "SetBranding_UserTask" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Unregister-ScheduledTask -TaskName "SetBranding_ProfileTask" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
if (Test-Path $UserScriptPath) { Remove-Item $UserScriptPath -Force -ErrorAction SilentlyContinue }
if (Test-Path $SysScriptPath) { Remove-Item $SysScriptPath -Force -ErrorAction SilentlyContinue }

$wshell.Popup("Wallpaper, Lock Screen, and Profile Picture successfully updated!`n`nSign out and back in to see all the changes.", 0, "Done", 64) | Out-Null