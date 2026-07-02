[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$LogFile = "C:\Temp\ScanSnapInstall.log"
"=== ScanSnap Install $(Get-Date) ===" | Out-File $LogFile -Encoding utf8
function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format o) - $Message"
    $line | Tee-Object -FilePath $LogFile -Append
}
Write-Log "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
if (Test-Path 'C:\Program Files (x86)\PFU\ScanSnap\Home\PfuSshMain.exe') {
    Write-Log "Already installed - skipping."
    exit 0
}
Stop-Process -Name "ScanSnapHome","SsWiaChecker","SsWiaRestartSvc","SshCloudMonitor" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
msiexec /x "{EE10D390-8467-41B3-B033-31B6883BEA8E}" /qn /norestart
Start-Sleep -Seconds 10
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{1806D5A5-0B2C-4E54-8219-7BD4CB9CB690}" /f 2>$null
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{4AD7410E-8842-4DF3-93F0-F13A6BC07638}" /f 2>$null
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{FAEF32A4-2231-48DC-8084-B1FB69A8D185}" /f 2>$null
reg delete "HKLM\SOFTWARE\WOW6432Node\PFU" /f 2>$null
reg delete "HKLM\SOFTWARE\PFU" /f 2>$null
takeown /f "C:\Program Files (x86)\PFU" /r /d y 2>$null
icacls "C:\Program Files (x86)\PFU" /grant administrators:F /t 2>$null
cmd /c rmdir /s /q "C:\Program Files (x86)\PFU" 2>$null
cmd /c rmdir /s /q "C:\ProgramData\ScanSnapHomeInstallerWork" 2>$null
cmd /c rmdir /s /q "C:\ProgramData\fiScanSnap" 2>$null
cmd /c rmdir /s /q "C:\Temp\ScanSnapDisk1" 2>$null
Remove-Item 'C:\Temp\ScanSnapDisk1.zip','C:\Temp\ScanSnapHome.iss' -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path 'C:\Temp\ScanSnapDisk1' -Force | Out-Null
$base = 'https://raw.githubusercontent.com/elancaster-boop/it-software/refs/heads/main/ScanSnapDisk1.part'
$zip = 'C:\Temp\ScanSnapDisk1.zip'
Write-Log "Starting download..."
$outStream = [System.IO.File]::OpenWrite($zip)
for ($i = 1; $i -le 50; $i++) {
    Write-Log "Downloading part $i of 50..."
    $bytes = (New-Object System.Net.WebClient).DownloadData($base + $i + '.bin')
    $outStream.Write($bytes, 0, $bytes.Length)
}
$outStream.Close()
Write-Log "Download complete. Size: $((Get-Item $zip).Length) bytes"
Write-Log "Extracting..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zip, 'C:\Temp\ScanSnapDisk1')
Write-Log "Extraction complete"
if (-not (Test-Path 'C:\Temp\ScanSnapDisk1\ScanSnapHome.exe')) {
    Write-Log "ERROR: ScanSnapHome.exe not found"
    exit 1
}
$iss = @"
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[{FAEF32A4-2231-48DC-8084-B1FB69A8D185}-DlgOrder]
Dlg0={FAEF32A4-2231-48DC-8084-B1FB69A8D185}-SdWelcome-0
Count=3
Dlg1={FAEF32A4-2231-48DC-8084-B1FB69A8D185}-SdStartCopy2-0
Dlg2={FAEF32A4-2231-48DC-8084-B1FB69A8D185}-SdFinish-0
[{FAEF32A4-2231-48DC-8084-B1FB69A8D185}-SdWelcome-0]
Result=1
[{FAEF32A4-2231-48DC-8084-B1FB69A8D185}-SdStartCopy2-0]
Result=1
[{FAEF32A4-2231-48DC-8084-B1FB69A8D185}-SdFinish-0]
Result=1
bOpt1=0
bOpt2=0
[Application]
Name=ScanSnap Home Setup
Version=3.6.0.10
Company=PFU
Lang=0409
"@
$iss | Out-File 'C:\Temp\ScanSnapHome.iss' -Encoding ascii
Write-Log "Response file created"
$loggedInUser = (Get-WMIObject -class Win32_ComputerSystem).Username
Write-Log "Logged in user: $loggedInUser"
if ($loggedInUser) {
    Write-Log "Creating scheduled task..."
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -Command `"Start-Process -FilePath 'C:\Temp\ScanSnapDisk1\ScanSnapHome.exe' -ArgumentList '/s /f1C:\Temp\ScanSnapHome.iss' -Wait`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(10)
    $principal = New-ScheduledTaskPrincipal -UserId $loggedInUser -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
    Register-ScheduledTask -TaskName "InstallScanSnap" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Log "Scheduled task created - waiting 10 minutes for completion..."
    Start-Sleep -Seconds 600
    Unregister-ScheduledTask -TaskName "InstallScanSnap" -Confirm:$false -ErrorAction SilentlyContinue
} else {
    Write-Log "No user logged in - running directly"
    Start-Process -FilePath 'C:\Temp\ScanSnapDisk1\ScanSnapHome.exe' -ArgumentList '/s /f1C:\Temp\ScanSnapHome.iss' -Wait
}
if (Test-Path 'C:\Program Files (x86)\PFU\ScanSnap\Home\PfuSshMain.exe') {
    Write-Log "SUCCESS: ScanSnap installed"
} else {
    Write-Log "WARNING: PfuSshMain.exe not found"
}
Remove-Item $zip -Force -ErrorAction SilentlyContinue
cmd /c rmdir /s /q "C:\Temp\ScanSnapDisk1" 2>$null
Remove-Item 'C:\Temp\ScanSnapHome.iss' -Force -ErrorAction SilentlyContinue
Write-Log "=== Script Complete ==="
