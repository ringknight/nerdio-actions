#description: Downloads and installs an FSLogix App Masking ruleset
#execution mode: Combined
#tags: FSLogix
[System.String] $Path = "$Env:ProgramFiles\FSLogix\Apps\Rules"

#region Script logic
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null
New-Item -Path "$Env:ProgramData\Nerdio\Logs" -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

try {
    $params = @{
        Uri             = $SecureVars.AppMaskingRuleset
        OutFile         = "$Path\ruleset.zip"
        UseBasicParsing = $true
        ErrorAction     = "Stop"
    }
    Invoke-WebRequest @params

    $params = @{
        Path            = "$Path\ruleset.zip"
        DestinationPath = $Path
        Force           = $true
    }
    Expand-Archive @params

    Remove-Item -Path "$Path\ruleset.zip" -Force -ErrorAction "SilentlyContinue"
}
catch {
    throw $_
}
