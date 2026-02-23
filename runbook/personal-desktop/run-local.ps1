param(
    [Parameter(Mandatory = $true)]
    [string]$GroupId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$HostPoolResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$HostPoolName,

    [string]$StateStorageAccountName,

    [string]$StateStorageContainerName = "runbook-state",

    [string]$DesktopVmResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AuditStorageAccountName,

    [string]$AuditStorageResourceGroupName,

    [string]$AuditStorageContainerName = "runbook-deletion-audit",

    [string]$AuditBlobPrefix = "deleted-resources",

    [string]$StatePath = "./local-state/state.json",

    [string]$RemovalWebhookUrl,

    [switch]$DryRun,

    [switch]$ForceFullSync
)

$scriptPath = Join-Path $PSScriptRoot "../runbook/Track-EntraGroupRemovals.ps1"

& $scriptPath `
    -GroupId $GroupId `
    -ResourceGroupName $ResourceGroupName `
    -HostPoolResourceGroupName $HostPoolResourceGroupName `
    -HostPoolName $HostPoolName `
    -StateStorageAccountName $StateStorageAccountName `
    -StateStorageContainerName $StateStorageContainerName `
    -DesktopVmResourceGroupName $DesktopVmResourceGroupName `
    -AuditStorageAccountName $AuditStorageAccountName `
    -AuditStorageResourceGroupName $AuditStorageResourceGroupName `
    -AuditStorageContainerName $AuditStorageContainerName `
    -AuditBlobPrefix $AuditBlobPrefix `
    -DryRun:$DryRun `
    -UseLocalState `
    -LocalStateFilePath $StatePath `
    -RemovalWebhookUrl $RemovalWebhookUrl `
    -ForceFullSync:$ForceFullSync `
    -SkipAzLogin:$false
