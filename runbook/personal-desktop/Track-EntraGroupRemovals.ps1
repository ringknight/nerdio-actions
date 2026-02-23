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
    [System.Management.Automation.SwitchParameter]$SkipAzLogin
)

# Configure the environment
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$InformationPreference = [System.Management.Automation.ActionPreference]::Continue
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Set-StrictMode -Version Latest

#region Functions
function Get-GraphToken {
    $token = Get-AzAccessToken -ResourceTypeName MSGraph
    if (-not $token -or -not $token.Token) {
        throw "Unable to acquire Microsoft Graph token."
    }
    return $token.Token
}

function Invoke-GraphGet {
    param(
        [Parameter(Mandatory = $true)]
        [System.String]$Uri,
        [Parameter(Mandatory = $true)]
        [System.String]$Token
    )

    return Invoke-RestMethod -Method GET -Uri $Uri -Headers @{ Authorization = "Bearer $Token" }
}

function Invoke-GraphPost {
    param(
        [Parameter(Mandatory = $true)]
        [System.String]$Uri,
        [Parameter(Mandatory = $true)]
        [System.String]$Token,
        [Parameter(Mandatory = $true)]
        [hashtable]$Body
    )

    return Invoke-RestMethod -Method POST -Uri $Uri -Headers @{ Authorization = "Bearer $Token" } -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 8)
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
    param(
        [System.String]$ResourceGroupName,
        [System.String]$StorageAccountName
    )

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    return (New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -UseConnectedAccount)
}

function Get-AssignedSessionHost {
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
            Remove-AzResource -ResourceId $ResourceId -Force | Out-Null
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

function Save-DeletionAuditRecord {
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

    $container = Get-AzStorageContainer -Context $StorageContext -Name $ContainerName -ErrorAction SilentlyContinue
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
        $blob = Get-AzStorageBlob -Context $StorageContext -Container $ContainerName -Blob $BlobName -ErrorAction SilentlyContinue
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
            New-Item -Path $dir -ItemType Directory | Out-Null
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
        $uri = $response.'@odata.nextLink'
    }

    return $ids
}

function Get-DeltaChanges {
    param(
        [System.String]$Token,
        [System.String]$GroupId,
        [System.String]$DeltaLink
    )

    if ($DeltaLink) {
        $uri = $DeltaLink
    }
    else {
        $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/members/delta?`$select=id&`$top=999"
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

        $uri = $response.'@odata.nextLink'
    }

    return @{
        Added     = $added
        Removed   = $removed
        DeltaLink = $newDeltaLink
    }
}

function Get-UserDetails {
    param(
        [System.String]$Token,
        [System.String[]]$UserIds
    )

    $users = @()
    foreach ($userId in $UserIds) {
        try {
            $user = Invoke-GraphGet -Uri "https://graph.microsoft.com/v1.0/users/$userId?`$select=id,userPrincipalName,displayName,accountEnabled" -Token $Token
            $users += [PSCustomObject]@{
                id                = $user.id
                userPrincipalName = $user.userPrincipalName
                displayName       = $user.displayName
                accountEnabled    = $user.accountEnabled
            }
        }
        catch {
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

    if (-not $RemovedUsers -or $RemovedUsers.Count -eq 0) {
        return
    }

    $resourceActionResults = @()

    Write-Output "Removed users detected: $($RemovedUsers.Count)"
    foreach ($user in $RemovedUsers) {
        Write-Output ("Removed: id={0}, upn={1}, displayName={2}" -f $user.id, $user.userPrincipalName, $user.displayName)

        $auditRecord = [ordered]@{
            runId                  = $RunId
            occurredUtc            = [DateTime]::UtcNow.ToString("o")
            groupId                = $GroupId
            userId                 = $user.id
            userPrincipalName      = $user.userPrincipalName
            uon                    = $user.userPrincipalName
            hostPoolName           = $HostPoolName
            hostPoolResourceGroup  = $HostPoolResourceGroupName
            desktopVmResourceGroup = $DesktopVmResourceGroupName
            sessionHost            = $null
            vmName                 = $null
            actionStatus           = "NoAction"
            deletedResources       = @()
            errors                 = @()
        }

        if (-not $user.userPrincipalName) {
            $auditRecord.actionStatus = "SkippedMissingUserPrincipalName"
            Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
            continue
        }

        $sessionHost = Get-AssignedSessionHost -HostPoolResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -UserPrincipalName $user.userPrincipalName
        if (-not $sessionHost) {
            $auditRecord.actionStatus = "NoAssignedSessionHost"
            Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
            continue
        }

        $sessionHostFqdn = Get-SessionHostFqdn -SessionHost $sessionHost
        $vmName = Get-VirtualMachineNameFromSessionHost -SessionHostFqdn $sessionHostFqdn
        $auditRecord.sessionHost = $sessionHostFqdn
        $auditRecord.vmName = $vmName

        if (-not $vmName) {
            $auditRecord.actionStatus = "VmNameNotResolved"
            Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
            continue
        }

        $vm = Get-AzVM -ResourceGroupName $DesktopVmResourceGroupName -Name $vmName -ErrorAction SilentlyContinue
        if (-not $vm) {
            $auditRecord.actionStatus = "VmNotFound"
            Save-DeletionAuditRecord -Record $auditRecord -StorageContext $AuditStorageContext -ContainerName $AuditStorageContainerName -BlobPrefix $AuditBlobPrefix
            continue
        }

        $deletionResults = Remove-AssignedVirtualMachineResources -VirtualMachine $vm -DryRun:$DryRun

        $resourceRecords = @()
        foreach ($result in $deletionResults) {
            $resourceRecords += [PSCustomObject]@{
                runId             = $RunId
                occurredUtc       = [DateTime]::UtcNow.ToString("o")
                groupId           = $GroupId
                userPrincipalName = $user.userPrincipalName
                uon               = $user.userPrincipalName
                resourceGroup     = $result.resourceGroup
                resourceId        = $result.id
                resourceName      = $result.name
                resourceType      = $result.resourceType
                status            = $result.status
                error             = $result.error
                dryRun            = [bool]$DryRun
            }
        }

        $auditRecord.deletedResources = $resourceRecords
        $resourceActionResults += $resourceRecords

        $failed = @($deletionResults | Where-Object { $_.status -ne "Deleted" })
        if ($DryRun) {
            $auditRecord.actionStatus = "DryRun"
        }
        elseif ($failed.Count -gt 0) {
            $auditRecord.actionStatus = "PartialFailure"
            $auditRecord.errors = @($failed | ForEach-Object { $_.error })
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

        Invoke-RestMethod -Method POST -Uri $WebhookUrl -ContentType "application/json" -Body ($payload | ConvertTo-Json -Depth 8) -UseBasicParsing | Out-Null
        Write-Host "Posted removed users payload to webhook."
    }

    return $resourceActionResults
}
#endregion

# Create a unique runId for this execution
$runId = [Guid]::NewGuid().ToString()
Write-Host "Runbook runId: $runId"

# Login to Azure if not skipped
if (-not $SkipAzLogin) {
    Connect-AzAccount -Identity | Out-Null
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
    $currentMembers = Get-FullUserMemberIds -Token $token -GroupId $GroupId

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
    }

    $deltaSeed = Get-DeltaChanges -Token $token -GroupId $GroupId
    $newDeltaLink = $deltaSeed.DeltaLink
}

# For any removed members, attempt to find details about the user and then take action on their assigned session host and related resources.
$removedArray = @($removedIds)
$removedUsers = @()
if ($removedArray.Count -gt 0) {
    $removedUsers = Get-UserDetails -Token $token -UserIds $removedArray
}

# Based on the removed users, find their assigned session host and attempt to remove the VM and related resources. Record all actions and outcomes in the audit storage.
$resourceActionResults = Invoke-RemovedUserAction -GroupId $GroupId -RemovedUsers $removedUsers -HostPoolResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -DesktopVmResourceGroupName $DesktopVmResourceGroupName -AuditStorageContext $auditStorageContext -AuditStorageContainerName $AuditStorageContainerName -AuditBlobPrefix $AuditBlobPrefix -DryRun:$DryRun -WebhookUrl $RemovalWebhookUrl -RunId $runId
if ($resourceActionResults -and $resourceActionResults.Count -gt 0) {
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
Save-RunState -BlobName $stateBlobName -ContainerName $StateStorageContainerName -StorageContext $storageContext -State $newState -UseLocal:$UseLocalState -LocalPath $LocalStateFilePath
Write-Host "Tracking complete. Current members: $($currentMembers.Count), removed users this run: $($removedArray.Count)."

# Summarize the resource actions taken for removed users in this run
$deletedCount = @($resourceActionResults | Where-Object { $_.status -eq "Deleted" }).Count
$dryRunCount = @($resourceActionResults | Where-Object { $_.status -eq "DryRun" }).Count
$failedCount = @($resourceActionResults | Where-Object { $_.status -eq "Failed" }).Count

# Output a summary object for this run
[PSCustomObject]@{
    runId                = $runId
    occurredUtc          = [DateTime]::UtcNow.ToString("o")
    totalResourceActions = @($resourceActionResults).Count
    Deleted              = $deletedCount
    DryRun               = $dryRunCount
    Failed               = $failedCount
}
