<#
#>

# Trust the PSGallery for modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.208" -Force
Install-PackageProvider -Name "PowerShellGet" -MinimumVersion "2.2.5" -Force
foreach ($Repository in "PSGallery") {
    if (Get-PSRepository | Where-Object { $_.Name -eq $Repository -and $_.InstallationPolicy -ne "Trusted" }) {
        try {
            Set-PSRepository -Name $Repository -InstallationPolicy "Trusted"
        }
        catch {
            $_.Exception.Message
        }
    }
}

foreach ($module in "Pester") {
    $installedModule = Get-Module -Name $module -ListAvailable -ErrorAction "SilentlyContinue" | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
        Select-Object -First 1
    $publishedModule = Find-Module -Name $module -ErrorAction "SilentlyContinue"
    if (($null -eq $installedModule) -or ([System.Version]$publishedModule.Version -gt [System.Version]$installedModule.Version)) {
        try {
            $params = @{
                Name               = $module
                SkipPublisherCheck = $true
                Force              = $true
                ErrorAction        = "Stop"
            }
            Install-Module @params
        }
        catch {
            throw $_.Exception.Message
        }
    }
}