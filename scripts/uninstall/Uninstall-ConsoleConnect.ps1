#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Uninstalls ConsoleConnect agents and related software from the system based on specified publishers.

    .DESCRIPTION
        This script searches for installed software published by ConsoleConnect Systems, Inc. and vast limits GmbH (by default),
        logs the process, and uninstalls the matching applications.
        It supports both MSI and non-MSI uninstallers, handles logging, and checks for pending file rename operations that may require a reboot.
        After uninstallation, it suggests directories to remove and prompts for a system restart if necessary.

    .PARAMETER Publishers
        An array of publisher names to match installed software for uninstallation. Defaults to "ConsoleConnect Systems, Inc." and "vast limits GmbH".

    .FUNCTIONS
        Write-LogFile
            Writes log messages to a daily log file and outputs to the console. Supports log levels for information and warnings.

        Get-InstalledSoftware
            Retrieves a list of installed software from the system registry, filtering out system components.

        Uninstall-ConsoleConnectAgent
            Uninstalls a given application, handling both MSI and non-MSI uninstallers, and logs the process.

        Get-PendingFileRenameOperation
            Checks the registry for pending file rename operations that may require a system reboot.

    .EXAMPLE
        .\Uninstall-ConsoleConnectAgents.ps1
        Runs the script with default publishers to uninstall ConsoleConnect agents.

    .NOTES
        - Requires administrative privileges.
        - Logs are stored in $Env:SystemRoot\Logs\Uninstall-ConsoleConnectAgents.
        - After uninstallation, a reboot may be required to finalize file deletions.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Position = 0, Mandatory = $false)]
    [System.String[]] $Name = @("Zoho Assist Unattended Agent"),

    [Parameter(Position = 1, Mandatory = $false)]
    [System.String[]] $Paths = @("${Env:ProgramFiles(x86)}\ZohoMeeting\UnAttended")
)

begin {
    function Write-LogFile {
        [CmdletBinding(SupportsShouldProcess = $false)]
        param (
            [Parameter(Position = 0, ValueFromPipeline = $true, Mandatory = $true)]
            [System.String] $Message,

            [Parameter(Position = 1, Mandatory = $false)]
            [ValidateSet(1, 2, 3)]
            [System.Int16] $LogLevel = 1
        )

        begin {
            # Log file path
            $LogFile = "$Env:SystemRoot\Logs\Uninstall-ConsoleConnectAgents\Uninstall-ConsoleConnectAgents-$(Get-Date -Format "yyyy-MM-dd").log"
            if (!(Test-Path -Path "$Env:SystemRoot\Logs\Uninstall-ConsoleConnectAgents")) {
                New-Item -Path "$Env:SystemRoot\Logs\Uninstall-ConsoleConnectAgents" -ItemType "Directory" -ErrorAction "SilentlyContinue" -WhatIf:$false | Out-Null
            }
        }

        process {
            # Build the line which will be recorded to the log file
            $TimeGenerated = $(Get-Date -Format "HH:mm:ss.ffffff")
            $Date = Get-Date -Format "yyyy-MM-dd"
            $LineNumber = "$($MyInvocation.ScriptName | Split-Path -Leaf -ErrorAction "SilentlyContinue"):$($MyInvocation.ScriptLineNumber)"
            $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
            $Thread = $([Threading.Thread]::CurrentThread.ManagedThreadId)
            $LineFormat = $Message, $TimeGenerated, $Date, $LineNumber, $Context, $LogLevel, $Thread
            $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">' -f $LineFormat

            # Add content to the log file and output to the console
            Write-Information -MessageData "[$TimeGenerated] $Message" -InformationAction "Continue"
            Add-Content -Value $Line -Path $LogFile -WhatIf:$false

            # Write-Warning for log level 2 or 3
            if ($LogLevel -eq 3 -or $LogLevel -eq 2) {
                Write-Warning -Message "[$TimeGenerated] $Message"
            }
        }
    }

    function Get-InstalledSoftware {
        [CmdletBinding()]
        param ()
        $UninstallKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        $Apps = @()
        foreach ($Key in $UninstallKeys) {
            try {
                $propertyNames = "DisplayName", "DisplayVersion", "Publisher", "UninstallString", "PSPath", "WindowsInstaller", "InstallDate", "InstallSource", "HelpLink", "Language", "EstimatedSize", "SystemComponent"
                $Apps += Get-ItemProperty -Path $Key -Name $propertyNames -ErrorAction "SilentlyContinue" | `
                    . { process { if ($null -ne $_.DisplayName) { $_ } } } | `
                    Where-Object { $_.SystemComponent -ne 1 } | `
                    Select-Object -Property @{n = "Name"; e = { $_.DisplayName } }, @{n = "Version"; e = { $_.DisplayVersion } }, "Publisher", "UninstallString", @{n = "RegistryPath"; e = { $_.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", "" } }, "PSChildName", "WindowsInstaller", "InstallDate", "InstallSource", "HelpLink", "Language", "EstimatedSize" | `
                    Sort-Object -Property "DisplayName", "Publisher"
            }
            catch {
                throw $_.Exception.Message
            }
        }

        Remove-PSDrive -Name "HKU" -ErrorAction "SilentlyContinue" | Out-Null
        return $Apps
    }

    function Uninstall-ConsoleConnectAgent {
        <#
            Accepts output from Get-InstalledSoftware and uninstalls the specified application.
        #>
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [System.Object[]]$Application
        )

        begin {
            $LogPath = "$Env:SystemRoot\Logs\Uninstall-ConsoleConnectAgents"
        }

        process {
            Write-LogFile -Message "Uninstall: $($Application.Name) $($Application.Version)"
            if ($Application.WindowsInstaller -eq 1) {
                $ArgumentList = "/uninstall `"$($Application.PSChildName)`" /quiet /norestart /log `"$LogPath\$($Application.PSChildName).log`""
                $params = @{
                    FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = $true
                    ErrorAction  = "Continue"
                    Verbose      = $true
                }
                Write-LogFile -Message " Executable: $Env:SystemRoot\System32\msiexec.exe"
                Write-LogFile -Message " Arguments:  $ArgumentList"
                if ($PSCmdlet.ShouldProcess("$Env:SystemRoot\System32\msiexec.exe", "Start process")) {
                    $result = Start-Process @params
                    Write-LogFile -Message " Uninstall return code: $($result.ExitCode)"
                    if ($result.ExitCode -in 3, 3010) { Write-LogFile -Message " Reboot is required to complete uninstall." }
                }
            }
            else {
                # Split the uninstall string to extract the executable and arguments
                $String = $Application.UninstallString -replace "`"", "" -split ".exe"
                $ArgumentList = $String[1].Trim() -replace "^\s*|\s*$", "" # Remove leading and trailing whitespace

                $params = @{
                    FilePath     = "$($String[0].Trim()).exe"
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = $true
                    ErrorAction  = "Continue"
                    Verbose      = $true
                }
                Write-LogFile -Message " Executable: $($String[0].Trim()).exe"
                Write-LogFile -Message " Arguments:  $ArgumentList"
                if ($PSCmdlet.ShouldProcess("$($String[0].Trim()).exe", "Start process")) {
                    $result = Start-Process @params
                    Write-LogFile -Message " Uninstall return code: $($result.ExitCode)"
                    if ($result.ExitCode -in 3, 3010) { Write-LogFile -Message " Reboot is required to complete uninstall." }
                }
            }
        }
    }

    function Get-PendingFileRenameOperation {
        $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        $Value = "PendingFileRenameOperations"
        $FilesArray = Get-ItemProperty -Path $Path -Name $Value -ErrorAction "SilentlyContinue" | `
            Select-Object -ExpandProperty $Value -ErrorAction "SilentlyContinue"
        if ($null -ne $FilesArray) {
            if ($FilesArray.Count -ge 1) {
                [PSCustomObject]@{
                    RebootRequired = $true
                    Files          = ($FilesArray | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                }
            }
        }
        else {
            [PSCustomObject]@{
                RebootRequired = $false
                Files          = $null
            }
        }
    }
}

process {
    # Get the list of Console Connect agents to uninstall
    $ConsoleConnectAgents = Get-InstalledSoftware | Where-Object { $_.Name -in $Name }

    # Count the number of Console Connect agents found
    if ($null -eq $ConsoleConnectAgents) {
        $AgentsCount = 0
    }
    elseif ($ConsoleConnectAgents -is [System.Array]) {
        $AgentsCount = $ConsoleConnectAgents.Count
    }
    elseif ($ConsoleConnectAgents -is [System.Management.Automation.PSCustomObject]) {
        $AgentsCount = 1
    }
    else {
        $AgentsCount = 0
    }

    # Output the installed agents
    Write-LogFile -Message "Found $AgentsCount Console Connect agents for uninstallation:"
    $ConsoleConnectAgents | ForEach-Object { Write-LogFile -Message "  $($_.Name) $($_.Version)" }

    # Uninstall each ConsoleConnect agent. Sorted by name in descending order to ensure proper uninstallation order
    $ConsoleConnectAgents | Sort-Object -Property "Name" -Descending | ForEach-Object { Uninstall-ConsoleConnectAgent -Application $_ }
}

end {
    if ($AgentsCount -gt 0) {
        Write-LogFile -Message "Uninstallation of Console Connect agents completed."
        Write-LogFile -Message "The following directories still exist on the system:"
        $Paths | ForEach-Object { if (Test-Path -Path $_) { Write-LogFile -Message " $_" } }

        $FilesPending = Get-PendingFileRenameOperation
        if ($FilesPending.RebootRequired -eq $true) {
            Write-LogFile -Message "$($FilesPending.Files.Count) files pending for deletion."
            Write-LogFile -Message "Please restart the system to finalize the process."
            return 3010
        }
        else {
            Write-LogFile -Message "No pending file rename operations detected."
            return 0
        }
    }
    else {
        Write-LogFile -Message "No Console Connect agents found to uninstall."
        Write-LogFile -Message "The following directories still exist on the system:"
        $Paths | ForEach-Object { if (Test-Path -Path $_) { Write-LogFile -Message " $_" } }
        return 0
    }
}
