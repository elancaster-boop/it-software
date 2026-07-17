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
cmd /c rmdir /s /q "C:\Temp\ScanSnapHomeFiles" 2>$null
Remove-Item 'C:\Temp\ScanSnapHome.zip','C:\Temp\ScanSnapHome.iss' -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path 'C:\Temp\ScanSnapHomeFiles' -Force | Out-Null
$base = 'https://raw.githubusercontent.com/elancaster-boop/it-software/refs/heads/main/ScanSnapHome.part'
$zip = 'C:\Temp\ScanSnapHome.zip'
Write-Log "Starting download..."
$outStream = [System.IO.File]::OpenWrite($zip)
for ($i = 1; $i -le 33; $i++) {
    Write-Log "Downloading part $i of 33..."
    $bytes = (New-Object System.Net.WebClient).DownloadData($base + $i + '.bin')
    $outStream.Write($bytes, 0, $bytes.Length)
}
$outStream.Close()
Write-Log "Download complete. Size: $((Get-Item $zip).Length) bytes"
Write-Log "Extracting..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zip, 'C:\Temp\ScanSnapHomeFiles')
Write-Log "Extraction complete"
if (-not (Test-Path 'C:\Temp\ScanSnapHomeFiles\PfuSshMain.exe')) {
    Write-Log "ERROR: PfuSshMain.exe not found after extraction"
    exit 1
}
Write-Log "Files verified - copying to install location..."
New-Item -ItemType Directory -Path 'C:\Program Files (x86)\PFU\ScanSnap\Home' -Force | Out-Null
Copy-Item 'C:\Temp\ScanSnapHomeFiles\*' 'C:\Program Files (x86)\PFU\ScanSnap\Home\' -Recurse -Force
Write-Log "Copy complete"
if (Test-Path 'C:\Program Files (x86)\PFU\ScanSnap\Home\PfuSshMain.exe') {
    Write-Log "SUCCESS: ScanSnap files installed"
} else {
    Write-Log "WARNING: PfuSshMain.exe not found after copy"
}
Remove-Item $zip -Force -ErrorAction SilentlyContinue
cmd /c rmdir /s /q "C:\Temp\ScanSnapHomeFiles" 2>$null
Write-Log "=== Script Complete ==="