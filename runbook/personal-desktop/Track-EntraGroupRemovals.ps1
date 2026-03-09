#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Storage, Az.DesktopVirtualization, Az.Compute, Az.Resources
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [System.String]$GroupId,

    [Parameter(Mandatory = $true)]
    [System.String]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [System.String]$StateStorageAccountName,

    [Parameter(Mandatory = $false)]
    [System.String]$StateStorageContainerName = "runbook-state",

    [Parameter(Mandatory = $false)]
    [System.String]$StateBlobPrefix = "entra-group-state",

    [Parameter(Mandatory = $true)]
    [System.String]$AuditStorageAccountName,

    [Parameter(Mandatory = $false)]
    [System.String]$AuditStorageResourceGroupName,

    [Parameter(Mandatory = $false)]
    [System.String]$AuditStorageContainerName = "runbook-deletion-audit",

    [Parameter(Mandatory = $false)]
    [System.String]$AuditBlobPrefix = "deleted-resources",

    [Parameter(Mandatory = $true)]
    [System.String]$HostPoolResourceGroupName,

    [Parameter(Mandatory = $true)]
    [System.String]$HostPoolName,

    [Parameter(Mandatory = $false)]
    [System.String]$DesktopVmResourceGroupName,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DryRun,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$ForceFullSync,

    [Parameter(Mandatory = $false)]
    [System.String]$RemovalWebhookUrl,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$UseLocalState,

    [Parameter(Mandatory = $false)]
    [System.String]$LocalStateFilePath = "./state.json",

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SkipAzLogin,

    [Parameter(Mandatory = $false)]
    [System.String]$ClientId,

    [Parameter(Mandatory = $false)]
    [System.String]$ClientSecret,

    [Parameter(Mandatory = $false)]
    [System.String]$TenantId
)

# Configure the environment
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$InformationPreference = [System.Management.Automation.ActionPreference]::Continue
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Set-StrictMode -Version Latest

#region Authentication Helper
function Initialize-AzAuthentication {
    [CmdletBinding()]
    param(
        [System.String]$ClientId,
        [System.String]$ClientSecret,
        [System.String]$TenantId
    )

    if ($ClientId -and $ClientSecret -and $TenantId) {
        Write-Information "Authenticating with service principal credentials."
        $credential = New-Object System.Management.Automation.PSCredential(
            $ClientId,
            (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)
        )
        Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $TenantId
        Write-Information "Service principal authentication successful."
    }
    else {
        Write-Information "Attempting managed identity authentication (for Azure resources)."
        try {
            Connect-AzAccount -Identity
            Write-Information "Managed identity authentication successful."
        }
        catch {
            Write-Information "Managed identity not available. Prompting for interactive login."
            Connect-AzAccount
            Write-Information "Interactive authentication successful."
        }
    }
}
#endregion

#region Functions
function Get-GraphToken {
    [CmdletBinding()]
    param()

    # Try multiple methods to get the token
    try {
        # Method 1: ResourceTypeName
        Write-Host "Attempting to get Graph token" -ForegroundColor Cyan
        $token = Get-AzAccessToken -ResourceTypeName "MSGraph"

        # Method 2 fallback: ResourceUrl (sometimes more reliable)
        if (-not $token) {
            Write-Host "Trying alternate method" -ForegroundColor Cyan
            $token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/"
        }
    }
    catch {
        throw "Failed to get MSGraph token. Ensure you are authenticated with Connect-AzAccount. Error: $($_.Exception.Message)"
    }

    if (-not $token) {
        throw "Unable to acquire Microsoft Graph token - Get-AzAccessToken returned null."
    }

    # Extract token string - handle different Az.Accounts versions
    $tokenString = $null

    if ($token -is [System.String]) {
        $tokenString = $token
    }
    elseif ($token.PSObject.Properties.Name -contains "Token") {
        $tokenValue = $token.Token

        # Handle SecureString
        if ($tokenValue -is [System.Security.SecureString]) {
            try {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenValue)
                $tokenString = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            }
        }
        else {
            $tokenString = $tokenValue
        }
    }
    elseif ($token.PSObject.Properties.Name -contains "AccessToken") {
        $tokenValue = $token.AccessToken

        # Handle SecureString
        if ($tokenValue -is [System.Security.SecureString]) {
            try {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenValue)
                $tokenString = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            }
        }
        else {
            $tokenString = $tokenValue
        }
    }

    if (-not $tokenString) {
        Write-Warning "Token object type: $($token.GetType().FullName)"
        Write-Warning "Token object properties: $($token | Get-Member -MemberType Property | Select-Object -ExpandProperty Name)"
        throw "Unable to extract token string from Get-AzAccessToken response."
    }

    # Ensure it's a string and trim any whitespace
    $tokenString = $tokenString.ToString().Trim()

    # Validate token is a proper JWT (format: header.payload.signature)
    if ($tokenString -notmatch '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$') {
        throw "Invalid token format. Token does not match JWT pattern. Length: $($tokenString.Length)"
    }

    # Write-Host "`nToken acquired. Length: $($tokenString.Length)" -ForegroundColor Cyan
    # Write-Host "First 50 chars: $($tokenString.Substring(0, [Math]::Min(50, $tokenString.Length)))" -ForegroundColor Gray

    # Decode and display token claims (for debugging)
    try {
        $parts = $tokenString.Split('.')
        if ($parts.Count -ne 3) {
            throw "Token doesn't have 3 parts (header.payload.signature). Found $($parts.Count) parts."
        }

        $payload = $parts[1]
        #Write-Host "Raw payload (base64): $($payload.Substring(0, [Math]::Min(100, $payload.Length)))"

        # Fix padding for base64 decode
        $padding = (4 - ($payload.Length % 4)) % 4
        $padded = $payload + ('=' * $padding)

        #Write-Host "Payload length: $($payload.Length), Padding added: $padding"

        $decodedBytes = [System.Convert]::FromBase64String($padded)
        $decodedText = [System.Text.Encoding]::UTF8.GetString($decodedBytes)

        # Write-Host "Decoded payload length: $($decodedText.Length) chars" -ForegroundColor Gray
        # Write-Host "First 200 chars of payload: $($decodedText.Substring(0, [Math]::Min(200, $decodedText.Length)))" -ForegroundColor Gray

        $claims = $decodedText | ConvertFrom-Json

        # Application permissions are in 'roles', delegated permissions in 'scp'
        # $appPermissions = if ($claims.roles) { @($claims.roles) -join ", " } else { "NONE" }
        # $delegatedPermissions = if ($claims.scp) { $claims.scp } else { "NONE" }

        # Write-Host "`n=== TOKEN PERMISSIONS DIAGNOSTIC ===" -ForegroundColor Cyan
        # Write-Host "Audience (aud): $($claims.aud)"
        # Write-Host "Issuer: $($claims.iss)"
        # Write-Host "Token Type: $($claims.idtyp)"
        # Write-Host "App ID (appid): $($claims.appid)"
        # Write-Host "Object ID (oid): $($claims.oid)"
        # Write-Host "Application Permissions (roles): $appPermissions" -ForegroundColor $(if ($claims.roles -and @($claims.roles).Count -gt 0) { "Green" } else { "Red" })
        # Write-Host "Delegated Permissions (scp): $delegatedPermissions" -ForegroundColor $(if ($claims.scp) { "Yellow" } else { "Gray" })
        # Write-Host "Token Expiry: $([DateTimeOffset]::FromUnixTimeSeconds($claims.exp).LocalDateTime)"

        if (-not $claims.roles -or @($claims.roles).Count -eq 0) {
            Write-Host "`n!!! PROBLEM DETECTED !!!" -ForegroundColor Red
            Write-Warning @"
No application permissions (roles) found in token!

Current authentication: $($claims.idtyp)
This token was issued for app: $($claims.appid)
Token audience: $($claims.aud)

CRITICAL: The token does NOT contain the required application roles.

The token is valid but doesn't include the Graph API permissions you configured.
This usually means the token was requested for the wrong resource/audience.

Expected audience: https://graph.microsoft.com or 00000003-0000-0000-c000-000000000000
Actual audience: $($claims.aud)

"@
        }
        else {
            Write-Host "`n✓ Token contains application roles - Graph API calls should work" -ForegroundColor Green

            $requiredRoles = @("GroupMember.Read.All", "User.Read.All", "Group.Read.All")
            $missingRoles = $requiredRoles | Where-Object { @($claims.roles) -notcontains $_ }

            if ($missingRoles) {
                Write-Warning "Missing recommended roles: $($missingRoles -join ', ')"
            }
        }

        Write-Host "====================================`n" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Could not decode token claims for debugging: $($_.Exception.Message)"
        Write-Warning "Exception type: $($_.Exception.GetType().FullName)"
        Write-Warning "Stack trace: $($_.ScriptStackTrace)"

        # Output the raw token for manual inspection
        # Write-Host "`nRAW TOKEN (paste this at https://jwt.ms to inspect):" -ForegroundColor Cyan
        # Write-Host $tokenString -ForegroundColor Gray
    }

    return $tokenString
}

function Invoke-GraphGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]$Uri,
        [Parameter(Mandatory = $true)]
        [System.String]$Token
    )

    # Ensure token is a clean string
    $cleanToken = $Token.ToString().Trim()

    try {
        Write-Host "Graph GET: $Uri"
        $headers = @{
            "Authorization" = "Bearer $cleanToken"
            "Content-Type"  = "application/json"
        }
        return Invoke-RestMethod -Method GET -Uri $Uri -Headers $headers
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        $errorMessage = $_.Exception.Message

        # Try to get detailed error from response body
        $errorDetails = $null
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            $errorDetails = $responseBody | ConvertFrom-Json
            $reader.Close()
            $stream.Close()
        }
        catch {
            # Couldn't parse error details
        }

        Write-Host "`nGraph API Error - Status Code: $statusCode"
        Write-Host "URI: $Uri"
        Write-Host "Error: $errorMessage"

        if ($errorDetails) {
            Write-Host "Error Code: $($errorDetails.error.code)" -ForegroundColor Cyan
            Write-Host "Error Message: $($errorDetails.error.message)" -ForegroundColor Cyan

            if ($errorDetails.error.innerError) {
                Write-Host "Inner Error: $($errorDetails.error.innerError | ConvertTo-Json -Depth 3)" -ForegroundColor Cyan
            }
        }

        if ($statusCode -eq 401) {
            Write-Host "`nDIAGNOSING 401 UNAUTHORIZED ERROR:" -ForegroundColor Cyan
            Write-Host "Current Azure context:" -ForegroundColor Cyan

            $context = Get-AzContext
            Write-Host "  Account Type: $($context.Account.Type)"
            Write-Host "  Account ID: $($context.Account.Id)"
            Write-Host "  Tenant: $($context.Tenant.Id)"

            Write-Error @"

Graph API returned 401 Unauthorized even though permissions appear configured.

POSSIBLE CAUSES:
1. Token audience mismatch - token issued for wrong resource
2. Service principal not properly synchronized in your tenant
3. Conditional Access policy blocking the service principal
4. Token claims not including the roles despite portal configuration

NEXT STEPS:
1. Copy the full token diagnostic output above
2. Go to https://jwt.ms and paste the token to verify roles are present
3. Check Azure AD Sign-in logs for this service principal
4. Verify no Conditional Access policies are blocking it

"@
        }
        else {
            Write-Error "Graph API call failed ($statusCode): $errorMessage`nURI: $Uri"
        }
        throw
    }
}

function Invoke-GraphPost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]$Uri,
        [Parameter(Mandatory = $true)]
        [System.String]$Token,
        [Parameter(Mandatory = $true)]
        [hashtable]$Body
    )

    # Ensure token is a clean string
    $cleanToken = $Token.ToString().Trim()

    try {
        Write-Host "Graph POST: $Uri"
        $headers = @{
            "Authorization" = "Bearer $cleanToken"
            "Content-Type"  = "application/json"
        }
        return Invoke-RestMethod -Method POST -Uri $Uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 8)
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        $errorMessage = $_.Exception.Message

        if ($statusCode -eq 401) {
            Write-Error "Graph API returned 401 Unauthorized. Service principal/managed identity lacks required 'Directory.Read.All' permission on Microsoft Graph. See previous error output for resolution steps."
        }
        else {
            Write-Error "Graph API call failed ($statusCode): $errorMessage`nURI: $Uri"
        }
        throw
    }
}

function Get-StateBlobName {
    param(
        [System.String]$Prefix,
        [System.String]$GroupId
    )

    $sanitized = ($GroupId -replace "[^a-zA-Z0-9]", "_")
    return "$Prefix/$sanitized.json"
}

function Get-StateStorageContext {
    [CmdletBinding()]
    param(
        [System.String]$ResourceGroupName,
        [System.String]$StorageAccountName
    )

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    return (New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -UseConnectedAccount)
}

function Get-AssignedSessionHost {
    [CmdletBinding()]
    param(
        [System.String]$HostPoolResourceGroupName,
        [System.String]$HostPoolName,
        [System.String]$UserPrincipalName
    )

    $sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName
    foreach ($sessionHost in $sessionHosts) {
        if ($sessionHost.AssignedUser -and $sessionHost.AssignedUser.Equals($UserPrincipalName, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $sessionHost
        }
    }
    return $null
}

function Get-SessionHostFqdn {
    [CmdletBinding()]
    param(
        [System.Object]$SessionHost
    )

    if (-not $SessionHost) {
        return $null
    }

    if ($SessionHost.Name -and $SessionHost.Name.Contains('/')) {
        return ($SessionHost.Name.Split('/')[1])
    }

    return $SessionHost.Name
}

function Get-VirtualMachineNameFromSessionHost {
    param(
        [System.String]$SessionHostFqdn
    )

    if (-not $SessionHostFqdn) {
        return $null
    }

    return ($SessionHostFqdn.Split('.')[0])
}

function Get-ResourceSummaryById {
    [CmdletBinding()]
    param(
        [System.String]$ResourceId
    )

    try {
        $resource = Get-AzResource -ResourceId $ResourceId
        return [PSCustomObject]@{
            id            = $ResourceId
            name          = $resource.Name
            resourceType  = $resource.ResourceType
            resourceGroup = $resource.ResourceGroupName
        }
    }
    catch {
        return [PSCustomObject]@{
            id            = $ResourceId
            name          = ($ResourceId.TrimEnd('/').Split('/')[-1])
            resourceType  = $null
            resourceGroup = $null
        }
    }
}

function Remove-ResourceById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]$ResourceId,
        [System.Management.Automation.SwitchParameter]$DryRun
    )

    $summary = Get-ResourceSummaryById -ResourceId $ResourceId
    $status = "Deleted"
    $errorMessage = $null

    if ($DryRun) {
        return [PSCustomObject]@{
            id            = $summary.id
            name          = $summary.name
            resourceType  = $summary.resourceType
            resourceGroup = $summary.resourceGroup
            status        = "DryRun"
            error         = $null
        }
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Write-Host "Remove: $($summary.name) (Type: $($summary.resourceType), Group: $($summary.resourceGroup)) - Attempt $attempt" -ForegroundColor Cyan
            Remove-AzResource -ResourceId $ResourceId -Force
            $status = "Deleted"
            $errorMessage = $null
            break
        }
        catch {
            if ($attempt -eq 3) {
                $status = "Failed"
                $errorMessage = $_.Exception.Message
            }
            else {
                Start-Sleep -Seconds 8
            }
        }
    }

    return [PSCustomObject]@{
        id            = $summary.id
        name          = $summary.name
        resourceType  = $summary.resourceType
        resourceGroup = $summary.resourceGroup
        status        = $status
        error         = $errorMessage
    }
}

function Remove-AssignedVirtualMachineResources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$VirtualMachine,
        [System.Management.Automation.SwitchParameter]$DryRun
    )

    $resourceIds = New-Object -TypeName System.Collections.Generic.List[System.String]
    [void]$resourceIds.Add($VirtualMachine.Id)

    if ($VirtualMachine.StorageProfile -and $VirtualMachine.StorageProfile.OsDisk -and $VirtualMachine.StorageProfile.OsDisk.ManagedDisk -and $VirtualMachine.StorageProfile.OsDisk.ManagedDisk.Id) {
        [void]$resourceIds.Add($VirtualMachine.StorageProfile.OsDisk.ManagedDisk.Id)
    }

    if ($VirtualMachine.StorageProfile -and $VirtualMachine.StorageProfile.DataDisks) {
        foreach ($disk in $VirtualMachine.StorageProfile.DataDisks) {
            if ($disk.ManagedDisk -and $disk.ManagedDisk.Id) {
                [void]$resourceIds.Add($disk.ManagedDisk.Id)
            }
        }
    }

    if ($VirtualMachine.NetworkProfile -and $VirtualMachine.NetworkProfile.NetworkInterfaces) {
        foreach ($nic in $VirtualMachine.NetworkProfile.NetworkInterfaces) {
            if ($nic.Id) {
                [void]$resourceIds.Add($nic.Id)
            }
        }
    }

    $results = @()
    foreach ($resourceId in $resourceIds) {
        $results += Remove-ResourceById -ResourceId $resourceId -DryRun:$DryRun
    }

    return $results
}

function Remove-SessionHostFromHostPool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.String]$HostPoolResourceGroupName,
        [Parameter(Mandatory = $true)]
        [System.String]$HostPoolName,
        [Parameter(Mandatory = $true)]
        [System.String]$SessionHostName,
        [System.Management.Automation.SwitchParameter]$DryRun
    )

    $status = "Deleted"
    $errorMessage = $null
    $resourceType = "Microsoft.DesktopVirtualization/hostPools/sessionHosts"

    if ($DryRun) {
        return [PSCustomObject]@{
            id            = "$HostPoolName/$SessionHostName"
            name          = $SessionHostName
            resourceType  = $resourceType
            resourceGroup = $HostPoolResourceGroupName
            status        = "DryRun"
            error         = $null
        }
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Write-Host "Remove session host: $SessionHostName from host pool $HostPoolName (Group: $HostPoolResourceGroupName) - Attempt $attempt" -ForegroundColor Cyan
            Remove-AzWvdSessionHost -ResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -Name $SessionHostName -Force
            $status = "Deleted"
            $errorMessage = $null
            break
        }
        catch {
            $message = $_.Exception.Message
            if ($message -match "(?i)not\s+found|cannot\s+find|404") {
                # If the session host registration no longer exists, treat it as already removed.
                $status = "Deleted"
                $errorMessage = $null
                break
            }

            if ($attempt -eq 3) {
                $status = "Failed"
                $errorMessage = $message
            }
            else {
                Start-Sleep -Seconds 5
            }
        }
    }

    return [PSCustomObject]@{
        id            = "$HostPoolName/$SessionHostName"
        name          = $SessionHostName
        resourceType  = $resourceType
        resourceGroup = $HostPoolResourceGroupName
        status        = $status
        error         = $errorMessage
    }
}

function Save-DeletionAuditRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Record,
        [Parameter(Mandatory = $true)]
        [object]$StorageContext,
        [Parameter(Mandatory = $true)]
        [System.String]$ContainerName,
        [Parameter(Mandatory = $true)]
        [System.String]$BlobPrefix
    )

    $container = Get-AzStorageContainer -Context $StorageContext -Name $ContainerName
    if (-not $container) {
        $container = New-AzStorageContainer -Context $StorageContext -Name $ContainerName -Permission Off
    }

    $datePath = [DateTime]::UtcNow.ToString("yyyy/MM/dd")
    $blobName = "$BlobPrefix/$datePath/$($Record.runId)-$([Guid]::NewGuid().ToString()).json"
    $json = $Record | ConvertTo-Json -Depth 12 -Compress

    $blobRef = $container.CloudBlobContainer.GetBlockBlobReference($blobName)
    $blobRef.UploadText($json)
}

function Get-RunState {
    [CmdletBinding()]
    param(
        [System.String]$BlobName,
        [System.String]$ContainerName,
        [object]$StorageContext,
        [System.Management.Automation.SwitchParameter]$UseLocal,
        [System.String]$LocalPath
    )

    if ($UseLocal) {
        if (Test-Path $LocalPath) {
            $raw = Get-Content -Raw -Path $LocalPath
            if ($raw) {
                return $raw | ConvertFrom-Json -Depth 10
            }
        }
        return $null
    }

    try {
        $blob = Get-AzStorageBlob -Context $StorageContext -Container $ContainerName -Blob $BlobName
        if ($blob -and $blob.ICloudBlob) {
            $raw = $blob.ICloudBlob.DownloadText()
            if ($raw) {
                return ($raw | ConvertFrom-Json -Depth 10)
            }
        }
    }
    catch {
        return $null
    }

    return $null
}

function Save-RunState {
    [CmdletBinding()]
    param(
        [System.String]$BlobName,
        [System.String]$ContainerName,
        [object]$StorageContext,
        [Parameter(Mandatory = $true)]
        [object]$State,
        [System.Management.Automation.SwitchParameter]$UseLocal,
        [System.String]$LocalPath
    )

    $json = $State | ConvertTo-Json -Depth 10 -Compress

    if ($UseLocal) {
        $dir = Split-Path -Path $LocalPath -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory
        }
        Set-Content -Path $LocalPath -Value $json
        return
    }

    $container = Get-AzStorageContainer -Context $StorageContext -Name $ContainerName -ErrorAction "SilentlyContinue"
    if (-not $container) {
        $container = New-AzStorageContainer -Context $StorageContext -Name $ContainerName -Permission "Off"
    }

    $blobRef = $container.CloudBlobContainer.GetBlockBlobReference($BlobName)
    $blobRef.UploadText($json)
}

function Get-FullUserMemberIds {
    [CmdletBinding()]
    param(
        [System.String]$Token,
        [System.String]$GroupId
    )

    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/members/microsoft.graph.user?`$select=id&`$top=999"
    $ids = New-Object -TypeName System.Collections.Generic.HashSet[System.String]

    while ($uri) {
        $response = Invoke-GraphGet -Uri $uri -Token $Token
        foreach ($entry in $response.value) {
            if ($entry.id) {
                [void]$ids.Add($entry.id)
            }
        }

        # Check if there's a next page
        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $uri = $response.'@odata.nextLink'
        }
        else {
            $uri = $null
        }
    }

    return $ids
}

function Get-DeltaChanges {
    [CmdletBinding()]
    param(
        [System.String]$Token,
        [System.String]$GroupId,
        [System.String]$DeltaLink
    )

    if ($DeltaLink) {
        $uri = $DeltaLink
    }
    else {
        # Delta endpoint - use minimal syntax for seeding the link
        $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/members/delta"
    }

    $added = New-Object -TypeName System.Collections.Generic.HashSet[System.String]
    $removed = New-Object -TypeName System.Collections.Generic.HashSet[System.String]
    $newDeltaLink = $null

    while ($uri) {
        $response = Invoke-GraphGet -Uri $uri -Token $Token

        foreach ($entry in $response.value) {
            if (-not $entry.id) {
                continue
            }

            if ($entry.PSObject.Properties.Name -contains "@removed") {
                [void]$removed.Add($entry.id)
                [void]$added.Remove($entry.id)
            }
            else {
                [void]$added.Add($entry.id)
                [void]$removed.Remove($entry.id)
            }
        }

        if ($response.PSObject.Properties.Name -contains "@odata.deltaLink") {
            $newDeltaLink = $response.'@odata.deltaLink'
        }

        # Check if there's a next page
        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $uri = $response.'@odata.nextLink'
        }
        else {
            $uri = $null
        }
    }

    return @{
        Added     = $added
        Removed   = $removed
        DeltaLink = $newDeltaLink
    }
}

function Get-UserDetails {
    [CmdletBinding()]
    param(
        [System.String]$Token,
        [System.String[]]$UserIds,
        [System.Int32]$LookupRetryCount = 3,
        [System.Int32]$LookupRetryDelaySeconds = 2
    )

    $users = @()
    foreach ($userId in $UserIds) {
        $resolvedUser = $null
        $lastLookupError = $null
        $escapedUserId = [System.Uri]::EscapeDataString($userId)

        for ($attempt = 1; $attempt -le $LookupRetryCount; $attempt++) {
            try {
                $resolvedUser = Invoke-GraphGet -Uri "https://graph.microsoft.com/v1.0/users/$escapedUserId?`$select=id,userPrincipalName,displayName,accountEnabled" -Token $Token
                if ($resolvedUser -and -not [System.String]::IsNullOrWhiteSpace($resolvedUser.userPrincipalName)) {
                    break
                }
            }
            catch {
                $lastLookupError = $_.Exception.Message
            }

            if ($attempt -lt $LookupRetryCount) {
                Start-Sleep -Seconds $LookupRetryDelaySeconds
            }
        }

        if (-not $resolvedUser -or [System.String]::IsNullOrWhiteSpace($resolvedUser.userPrincipalName)) {
            try {
                $lookupResponse = Invoke-GraphGet -Uri "https://graph.microsoft.com/v1.0/users?`$filter=id eq '$userId'&`$select=id,userPrincipalName,displayName,accountEnabled&`$top=1" -Token $Token
                $lookupMatches = @($lookupResponse.value)
                if ($lookupMatches.Count -gt 0) {
                    $resolvedUser = $lookupMatches[0]
                }
            }
            catch {
                $lastLookupError = $_.Exception.Message
            }
        }

        if (-not $resolvedUser -or [System.String]::IsNullOrWhiteSpace($resolvedUser.userPrincipalName)) {
            try {
                $deletedUser = Invoke-GraphGet -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.user/$escapedUserId?`$select=id,userPrincipalName,displayName" -Token $Token
                if ($deletedUser) {
                    $resolvedUser = $deletedUser
                }
            }
            catch {
                $lastLookupError = $_.Exception.Message
            }
        }

        if ($resolvedUser) {
            $users += [PSCustomObject]@{
                id                = $resolvedUser.id
                userPrincipalName = $resolvedUser.userPrincipalName
                displayName       = $resolvedUser.displayName
                accountEnabled    = $resolvedUser.accountEnabled
            }
        }
        else {
            Write-Warning "Unable to resolve user details for ID '$userId'. Last lookup error: $lastLookupError"
            $users += [PSCustomObject]@{
                id                = $userId
                userPrincipalName = $null
                displayName       = $null
                accountEnabled    = $null
            }
        }
    }

    return $users
}

function Invoke-RemovedUserAction {
    [CmdletBinding()]
    param(
        [System.String]$GroupId,
        [System.Object[]]$RemovedUsers,
        [System.String]$HostPoolResourceGroupName,
        [System.String]$HostPoolName,
        [System.String]$DesktopVmResourceGroupName,
        [System.Object]$AuditStorageContext,
        [System.String]$AuditStorageContainerName,
        [System.String]$AuditBlobPrefix,
        [System.Management.Automation.SwitchParameter]$DryRun,
        [System.String]$WebhookUrl,
        [System.String]$RunId
    )

    if (-not $RemovedUsers -or @($RemovedUsers).Count -eq 0) {
        Write-Host "No removed users to process." -ForegroundColor Green
        return
    }

    $resourceActionResults = @()

    Write-Host "Removed users detected: $(@($RemovedUsers).Count)"
    foreach ($user in $RemovedUsers) {
        Write-Host ("Removed: id={0}, upn={1}, displayName={2}" -f $user.id, $user.userPrincipalName, $user.displayName)

        $auditRecord = [ordered]@{
            runId                  = $RunId
            occurredUtc            = [DateTime]::UtcNow.ToString("o")
            groupId                = $GroupId
            userId                 = $user.id
            userPrincipalName      = $user.userPrincipalName
            upn                    = $user.userPrincipalName
            hostPoolName           = $HostPoolName
            hostPoolResourceGroup  = $HostPoolResourceGroupName
            desktopVmResourceGroup = $DesktopVmResourceGroupName
            sessionHost            = $null
            vmName                 = $null
            vmResourceId           = $null
            osDiskResourceId       = $null
            nicResourceId          = $null
            actionStatus           = "NoAction"
            deletedResources       = @()
            errors                 = @()
        }

        if (-not $user.userPrincipalName) {
            $auditRecord.actionStatus = "SkippedMissingUserPrincipalName"
            Write-Host "User principal name is missing for user ID $($user.id). Skipping resource deletion for this user." -ForegroundColor Cyan
            Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
            continue
        }

        $sessionHost = Get-AssignedSessionHost -HostPoolResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -UserPrincipalName $user.userPrincipalName
        if (-not $sessionHost) {
            $auditRecord.actionStatus = "NoAssignedSessionHost"
            Write-Host "No session host assigned to user $($user.userPrincipalName). Skipping resource deletion for this user." -ForegroundColor Cyan
            Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
            continue
        }

        $sessionHostFqdn = Get-SessionHostFqdn -SessionHost $sessionHost
        $vmName = Get-VirtualMachineNameFromSessionHost -SessionHostFqdn $sessionHostFqdn
        $auditRecord.sessionHost = $sessionHostFqdn
        $auditRecord.vmName = $vmName

        if (-not $vmName) {
            $auditRecord.actionStatus = "VmNameNotResolved"
            Write-Host "VM name could not be resolved for session host $($sessionHostFqdn). Skipping resource deletion for this user." -ForegroundColor Cyan
            Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
            continue
        }

        $vm = Get-AzVM -ResourceGroupName $DesktopVmResourceGroupName -Name $vmName
        if (-not $vm) {
            $auditRecord.actionStatus = "VmNotFound"
            Write-Host "VM $vmName not found in resource group $DesktopVmResourceGroupName. Skipping resource deletion for this user." -ForegroundColor Cyan
            Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
            continue
        }

        # Capture VM resource details for audit record
        $auditRecord.vmResourceId = $vm.Id
        if ($vm.StorageProfile -and $vm.StorageProfile.OsDisk -and $vm.StorageProfile.OsDisk.ManagedDisk -and $vm.StorageProfile.OsDisk.ManagedDisk.Id) {
            $auditRecord.osDiskResourceId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
        }
        if ($vm.NetworkProfile -and $vm.NetworkProfile.NetworkInterfaces -and $vm.NetworkProfile.NetworkInterfaces.Count -gt 0) {
            # Capture first NIC (primary NIC)
            $auditRecord.nicResourceId = $vm.NetworkProfile.NetworkInterfaces[0].Id
        }

        $sessionHostRemovalResult = Remove-SessionHostFromHostPool -HostPoolResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -SessionHostName $sessionHostFqdn -DryRun:$DryRun
        $actionResults = @($sessionHostRemovalResult)

        if ($sessionHostRemovalResult.status -eq "Failed") {
            Write-Host "Failed to remove session host $sessionHostFqdn from host pool $HostPoolName. Skipping VM resource deletion for this user." -ForegroundColor Red
            $auditRecord.actionStatus = "SessionHostRemovalFailed"
            $auditRecord.errors = @($sessionHostRemovalResult.error)
        }
        else {
            $deletionResults = Remove-AssignedVirtualMachineResources -VirtualMachine $vm -DryRun:$DryRun
            $actionResults += @($deletionResults)
        }

        $resourceRecords = @()
        foreach ($result in $actionResults) {
            # Safely extract properties from result object, handling cases where properties may not exist
            $resourceGroupValue = if ($null -ne $result -and $result.PSObject.Properties.Name -contains "resourceGroup") { $result.resourceGroup } else { $null }
            $resourceIdValue = if ($null -ne $result -and $result.PSObject.Properties.Name -contains "id") { $result.id } else { $null }
            $resourceNameValue = if ($null -ne $result -and $result.PSObject.Properties.Name -contains "name") { $result.name } else { $null }
            $resourceTypeValue = if ($null -ne $result -and $result.PSObject.Properties.Name -contains "resourceType") { $result.resourceType } else { $null }
            $statusValue = if ($null -ne $result -and $result.PSObject.Properties.Name -contains "status") { $result.status } else { $null }
            $errorValue = if ($null -ne $result -and $result.PSObject.Properties.Name -contains "error") { $result.error } else { $null }

            $resourceRecords += [PSCustomObject]@{
                runId             = $RunId
                occurredUtc       = [DateTime]::UtcNow.ToString("o")
                groupId           = $GroupId
                userPrincipalName = $user.userPrincipalName
                upn               = $user.userPrincipalName
                sessionHost       = $sessionHostFqdn
                vmName            = $vmName
                resourceGroup     = $resourceGroupValue
                resourceId        = $resourceIdValue
                resourceName      = $resourceNameValue
                resourceType      = $resourceTypeValue
                status            = $statusValue
                error             = $errorValue
                dryRun            = [bool]$DryRun
            }
        }

        $auditRecord.deletedResources = $resourceRecords
        $resourceActionResults += $resourceRecords

        $failed = @($actionResults | Where-Object { $null -ne $_ -and $_.PSObject.Properties.Name -contains 'status' -and $_.status -ne "Deleted" -and $_.status -ne "DryRun" })
        if ($auditRecord.actionStatus -eq "SessionHostRemovalFailed") {
            # Keep SessionHostRemovalFailed set above.
        }
        elseif ($DryRun) {
            $auditRecord.actionStatus = "DryRun"
        }
        elseif ($failed.Count -gt 0) {
            $auditRecord.actionStatus = "PartialFailure"
            $auditRecord.errors = @($failed | ForEach-Object { if ($null -ne $_ -and $_.PSObject.Properties.Name -contains 'error') { $_.error } })
        }
        else {
            $auditRecord.actionStatus = "Deleted"
        }

        Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
    }

    if ($WebhookUrl) {
        $payload = @{
            runId        = $RunId
            occurredUtc  = [DateTime]::UtcNow.ToString("o")
            groupId      = $GroupId
            removedUsers = $RemovedUsers
        }

        Write-Host "Graph POST: $WebhookUrl"
        Invoke-RestMethod -Method POST -Uri $WebhookUrl -ContentType "application/json" -Body ($payload | ConvertTo-Json -Depth 8) -UseBasicParsing
        Write-Host "Posted removed users payload to webhook."
    }

    return @($resourceActionResults)
}
#endregion

# Main script execution wrapped in try/catch for better error reporting
try {
    # Create a unique runId for this execution
    $runId = [Guid]::NewGuid().ToString()
    Write-Host "Runbook runId: $runId"

    # Login to Azure if not skipped
    if (-not $SkipAzLogin) {
        Initialize-AzAuthentication -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId
    }

    # Validate storage account name variable
    if (-not $UseLocalState -and [System.String]::IsNullOrWhiteSpace($StateStorageAccountName)) {
        throw "StateStorageAccountName is required when UseLocalState is not set."
    }

    # Set resource group name for the target VM
    if ([System.String]::IsNullOrWhiteSpace($DesktopVmResourceGroupName)) {
        $DesktopVmResourceGroupName = $HostPoolResourceGroupName
    }

    # If audit storage resource group name is not provided, default to the state storage resource group
    if ([System.String]::IsNullOrWhiteSpace($AuditStorageResourceGroupName)) {
        $AuditStorageResourceGroupName = $ResourceGroupName
    }

    # Get storage context for state and audit (can be the same if using the same storage account)
    $storageContext = $null
    if (-not $UseLocalState) {
        $storageContext = Get-StateStorageContext -ResourceGroupName $ResourceGroupName -StorageAccountName $StateStorageAccountName
    }

    # Audit storage context (for recording deletion audit logs)
    $auditStorageContext = Get-StateStorageContext -ResourceGroupName $AuditStorageResourceGroupName -StorageAccountName $AuditStorageAccountName

    # Determine prior state and changes
    $stateBlobName = Get-StateBlobName -Prefix $StateBlobPrefix -GroupId $GroupId
    $priorState = Get-RunState -BlobName $stateBlobName -ContainerName $StateStorageContainerName -StorageContext $storageContext -UseLocal:$UseLocalState -LocalPath $LocalStateFilePath
    $token = Get-GraphToken

    # Use delta query if possible, otherwise fall back to full sync
    $currentMembers = New-Object -TypeName System.Collections.Generic.HashSet[System.String]
    $removedIds = New-Object -TypeName System.Collections.Generic.HashSet[System.String]
    $newDeltaLink = $null

    # If we have a prior state with a deltaLink and memberIds, we can attempt to use the delta query to find changes since the last run. This is more efficient than doing a full sync of all members, especially for large groups. If we don't have a valid prior state, or if ForceFullSync is set, then we will do a full sync to establish the current membership baseline.
    if (-not $ForceFullSync -and $priorState -and $priorState.deltaLink -and $priorState.memberIds) {
        Write-Host "Using delta query based on stored deltaLink."

        foreach ($id in $priorState.memberIds) {
            if ($id) {
                [void]$currentMembers.Add($id)
            }
        }

        $deltaResult = Get-DeltaChanges -Token $token -GroupId $GroupId -DeltaLink $priorState.deltaLink
        $newDeltaLink = $deltaResult.DeltaLink

        foreach ($id in $deltaResult.Added) {
            [void]$currentMembers.Add($id)
        }

        foreach ($id in $deltaResult.Removed) {
            if ($currentMembers.Contains($id)) {
                [void]$currentMembers.Remove($id)
            }
            [void]$removedIds.Add($id)
        }
    }
    else {
        Write-Host "Using full sync to establish/refresh membership baseline."
        $fullSyncResult = Get-FullUserMemberIds -Token $token -GroupId $GroupId
        
        # Ensure we always have a valid HashSet, even if the result is null
        if ($null -eq $fullSyncResult) {
            $currentMembers = New-Object -TypeName System.Collections.Generic.HashSet[System.String]
            Write-Warning "Full sync returned null. Initializing empty member set."
        }
        else {
            $currentMembers = $fullSyncResult
        }

        if ($priorState -and $priorState.memberIds) {
            $priorMemberSet = New-Object -TypeName System.Collections.Generic.HashSet[System.String]
            foreach ($id in $priorState.memberIds) {
                if ($id) {
                    [void]$priorMemberSet.Add($id)
                }
            }

            foreach ($id in $priorMemberSet) {
                if (-not $currentMembers.Contains($id)) {
                    [void]$removedIds.Add($id)
                }
            }

            # Only try to seed delta link if we have prior state to compare against
            try {
                $deltaSeed = Get-DeltaChanges -Token $token -GroupId $GroupId
                $newDeltaLink = $deltaSeed.DeltaLink
                Write-Host "Delta link seeded for next run."
            }
            catch {
                Write-Host "Could not seed delta link (this is expected on some tenants). Will use full sync next time."
                $newDeltaLink = $null
            }
        }
        else {
            # First run - no prior state, so skip delta seeding
            Write-Host "First run - skipping delta link seed. Next run will use delta query if available."
            $newDeltaLink = $null
        }
    }

    # For any removed members, attempt to find details about the user and then take action on their assigned session host and related resources.
    $removedArray = @($removedIds)
    $removedUsers = @()
    if ($removedArray.Count -gt 0) {
        $removedUsers = Get-UserDetails -Token $token -UserIds $removedArray
    }

    # Based on the removed users, find their assigned session host and attempt to remove the VM and related resources. Record all actions and outcomes in the audit storage.
    $params = @{
        GroupId                    = $GroupId
        RemovedUsers               = $removedUsers
        HostPoolResourceGroupName  = $HostPoolResourceGroupName
        HostPoolName               = $HostPoolName
        DesktopVmResourceGroupName = $DesktopVmResourceGroupName
        AuditStorageContext        = $auditStorageContext
        AuditStorageContainerName  = $AuditStorageContainerName
        AuditBlobPrefix            = $AuditBlobPrefix
        DryRun                     = $DryRun
        WebhookUrl                 = $RemovalWebhookUrl
        RunId                      = $runId
    }
    $resourceActionResults = Invoke-RemovedUserAction @params
    if ($resourceActionResults -and @($resourceActionResults).Count -gt 0) {
        $resourceActionResults
    }

    # Update state with current members and new delta link for next run
    $newState = [PSCustomObject]@{
        groupId    = $GroupId
        memberIds  = @($currentMembers)
        deltaLink  = $newDeltaLink
        lastRunUtc = [DateTime]::UtcNow.ToString("o")
        lastRunId  = $runId
    }

    # Save the new state back to blob storage for the next run to use
    $params = @{
        BlobName       = $stateBlobName
        ContainerName  = $StateStorageContainerName
        StorageContext = $storageContext
        State          = $newState
        UseLocal       = $UseLocalState
        LocalPath      = $LocalStateFilePath
    }
    Save-RunState @params
    Write-Host "Tracking complete. Current members: $(@($currentMembers).Count), removed users this run: $($removedArray.Count)."

    # Summarize the resource actions taken for removed users in this run
    $deletedCount = 0
    $dryRunCount = 0
    $failedCount = 0

    if (@($resourceActionResults).Count -gt 0) {
        Write-Host "Found $(@($resourceActionResults).Count) resource action results to summarize"
        $deletedCount = @($resourceActionResults | Where-Object { $_.PSObject.Properties.Name -contains 'status' -and $_.status -eq "Deleted" }).Count
        $dryRunCount = @($resourceActionResults | Where-Object { $_.PSObject.Properties.Name -contains 'status' -and $_.status -eq "DryRun" }).Count
        $failedCount = @($resourceActionResults | Where-Object { $_.PSObject.Properties.Name -contains 'status' -and $_.status -eq "Failed" }).Count
    }

    # Output a summary object for this run
    [PSCustomObject]@{
        runId                = $runId
        occurredUtc          = [DateTime]::UtcNow.ToString("o")
        totalResourceActions = @($resourceActionResults).Count
        Deleted              = $deletedCount
        DryRun               = $dryRunCount
        Failed               = $failedCount
    }
}
catch {
    Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error at Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Cyan
    Write-Host "Error at Position: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Cyan
    Write-Host "Script Name: $($_.InvocationInfo.ScriptName)" -ForegroundColor Gray
    Write-Host "Command: $($_.InvocationInfo.MyCommand)" -ForegroundColor Gray
    Write-Host "`nFull Error:" -ForegroundColor Cyan
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    throw
}
