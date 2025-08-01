<#
    .SYNOPSIS
    Installs the latest version of the Citrix Workspace app.

    .DESCRIPTION
    This script installs the latest version of the Citrix Workspace app.
    It uses the Evergreen module to retrieve the appropriate version based on the specified stream.
    The installation is performed silently with specific command-line arguments.

    .PARAMETER Path
    The path where the Citrix Workspace app will be download. The default path is "$Env:SystemDrive\Apps\Citrix\Workspace".

    .NOTES
    - This script requires the Evergreen module to be installed.
    - The script assumes that the Citrix Workspace app installation file is available in the specified stream.
    - The script disables the Citrix Workspace app update tasks and removes certain startup items.
#>

#description: Installs the latest version of the Citrix Workspace app
#execution mode: Individual
#tags: Evergreen, Citrix
#Requires -Modules Evergreen
[System.String] $Path = "$Env:SystemDrive\Apps\Citrix\Workspace"
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

# Import shared functions written to disk by 000_PrepImage.ps1
$FunctionFile = "$Env:TEMP\NerdioFunctions.psm1"
Import-Module -Name $FunctionFile -Force -ErrorAction "Stop"
Write-LogFile -Message "Functions imported from: $FunctionFile"

# Try current release and fall back to LTSR the download fails
try {
    Import-Module -Name "Evergreen" -Force
    Write-LogFile -Message "Query Evergreen for Citrix Workspace app Current release"
    $App = Get-EvergreenApp -Name "CitrixWorkspaceApp" | `
        Where-Object { $_.Stream -eq "Current" } | `
        Select-Object -First 1
    Write-LogFile -Message "Downloading Citrix Workspace app version $($App.Version) to $Path"
    $OutFile = Save-EvergreenApp -InputObject $App -CustomPath $Path -ErrorAction "Stop"
}
catch {
    Write-LogFile -Message "Failed to download Citrix Workspace app Current release, falling back to LTSR"
    $App = Get-EvergreenApp -Name "CitrixWorkspaceApp" | `
        Where-Object { $_.Stream -eq "LTSR" } | `
        Select-Object -First 1
    Write-LogFile -Message "Downloading Citrix Workspace app version $($App.Version) to $Path"
    $OutFile = Save-EvergreenApp -InputObject $App -CustomPath $Path -ErrorAction "Stop"
}

# Rename the installer
if (!(Test-Path -Path $(Join-Path -Path $OutFile.DirectoryName -ChildPath "CitrixWorkspaceApp.exe"))) {
    Write-LogFile -Message "Renaming Citrix Workspace app installer to CitrixWorkspaceApp.exe"
    Rename-Item -Path $OutFile -NewName "CitrixWorkspaceApp.exe"
    $OutFile = Get-ChildItem -Path $OutFile.DirectoryName -Filter "CitrixWorkspaceApp.exe"
}

# Install the Citrix Workspace app
$Arguments = @("/silent /noreboot",
    #"/includeSSON"
    "/AutoUpdateCheck=Disabled",
    "EnableTracing=false",
    "EnableCEIP=False",
    "PutShortcutsOnDesktop=False",
    "ALLOWADDSTORE=S",
    "InstallEmbeddedBrowser=N",
    "ADDLOCAL=ReceiverInside,ICA_Client,DesktopViewer,AM,WebHelper")
$params = @{
    FilePath     = $OutFile.FullName
    ArgumentList = $($Arguments -join " ")
    Wait         = $false
}
Start-ProcessWithLog @params

# Wait for the installation to complete because Citrix can't work out how to write an installer correctly
$ExePaths = $("${Env:ProgramFiles(x86)}\Citrix\ICA Client\appprotection.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\bgblursvc.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\CDViewer.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\concentr.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\config.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\cpviewer.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\Ctx64Injector64.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\ctxapconfig.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\CtxBrowserInt.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\CtxCFRUI.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\CtxTwnPA.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\HdxRtcEngine.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\icaconf.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\NMHost.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\pcl2bmp.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\PdfPrintHelper.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\RawPrintHelper.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\redirector.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\SetIntegrityLevel.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\vdrcghost64.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\WebHelper.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\wfcrun32.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\wfcwow64.exe",
    "${Env:ProgramFiles(x86)}\Citrix\ICA Client\wfica32.exe")
do {
    Start-Sleep -Seconds 15
    Write-LogFile -Message "Waiting for Citrix Workspace app installation to complete."
} while (!(Test-Path -Path $ExePaths))
Start-Sleep -Seconds 30

# Disable update tasks - assuming we're installing on a gold image or updates will be managed
Write-LogFile -Message "Disabling Citrix Workspace app update tasks and services"
Get-Service -Name "CWAUpdaterService" -ErrorAction "SilentlyContinue" | Set-Service -StartupType "Disabled" -ErrorAction "SilentlyContinue"

# Remove startup items
Start-ProcessWithLog -FilePath "$Env:SystemRoot\System32\reg.exe" -ArgumentList "delete HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run /v AnalyticsSrv /f"
Start-ProcessWithLog -FilePath "$Env:SystemRoot\System32\reg.exe" -ArgumentList "delete HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run /v ConnectionCenter /f"
Start-ProcessWithLog -FilePath "$Env:SystemRoot\System32\reg.exe" -ArgumentList "delete HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run /v Redirector /f"
