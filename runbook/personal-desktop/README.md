# Entra Group Removal Tracking Runbook

This workspace contains a PowerShell runbook implementation that tracks Entra ID group membership across executions and reacts when user accounts are removed by cleaning up their assigned Azure Virtual Desktop personal desktops and recording an audit trail.

## Files

- `Track-EntraGroupRemovals.ps1` - runbook logic with persisted state and Graph delta tracking.
- `run-local.ps1` - local execution helper.

## How membership is tracked across runs

The runbook persists a JSON state object per Entra group in Azure Blob Storage:

- `memberIds`: last known user member IDs
- `deltaLink`: Microsoft Graph delta token URL
- `lastRunUtc` and `lastRunId`

On each run:

1. Load previous state from a blob in the configured container.
2. If `deltaLink` exists, call Graph delta endpoint to get changes since last run.
3. Apply changes to previous membership and detect removals.
4. Trigger removal actions.
5. Save updated `memberIds` and refreshed `deltaLink`.

If no prior state exists, runbook performs a full membership baseline and then seeds delta tracking.

## What happens when a user is removed

For each removed user, the runbook:

1. Queries the specified Azure Virtual Desktop personal host pool for the session host assigned to the removed user (`AssignedUser`).
2. Resolves the VM name from the assigned session host name.
3. Deletes the associated Azure resources:
  - virtual machine
  - managed disks (OS + data)
  - network interfaces
4. Writes an audit record to a separate blob storage account containing:
  - date/time (`occurredUtc`)
  - associated UON (`uon`, set to user principal name)
  - resource group
  - deleted resources and status/errors
5. Emits a compact summary object at the end with counts by `Deleted`, `DryRun`, and `Failed` for quick job scanning.

Use `DryRun = true` to validate the deletion workflow without deleting resources. In dry-run mode, the runbook returns resource-level `PSCustomObject` output with `occurredUtc`, `userPrincipalName`, `uon`, and `resourceGroup`.

Summary output example:

```powershell
[PSCustomObject]@{
  runId = "4a2d5c1e-1f2a-4a6b-9f0c-9b8f3c7b2d9a"
  occurredUtc = "2026-02-24T17:03:18.412Z"
  totalResourceActions = 3
  Deleted = 2
  DryRun = 1
  Failed = 0
}
```

## Prerequisites

- Azure Automation Account with System Assigned Managed Identity enabled.
- Az modules available in Automation Account (`Az.Accounts`, `Az.Storage`, `Az.DesktopVirtualization`, `Az.Compute`, `Az.Resources`).
- Managed identity must have Microsoft Graph app role permissions to read group members and user profiles:
  - `GroupMember.Read.All`
  - `User.Read.All`
- Managed identity must have RBAC access to the state storage account (for example `Storage Blob Data Contributor`).
- Managed identity must have RBAC access to the audit storage account (for example `Storage Blob Data Contributor`).
- Managed identity must have RBAC permissions to read AVD host pool/session hosts and delete VM resources in the target resource group(s).

## Runbook Parameters

- `GroupId` (required)
- `ResourceGroupName` (required)
- `HostPoolResourceGroupName` (required)
- `HostPoolName` (required)
- `StateStorageAccountName` (required unless `UseLocalState` is set)
- `StateStorageContainerName` (default: `runbook-state`)
- `StateBlobPrefix` (default: `EntraGroupState`)
- `DesktopVmResourceGroupName` (optional, defaults to `HostPoolResourceGroupName`)
- `AuditStorageAccountName` (required)
- `AuditStorageResourceGroupName` (optional, defaults to `ResourceGroupName`)
- `AuditStorageContainerName` (default: `runbook-deletion-audit`)
- `AuditBlobPrefix` (default: `deleted-resources`)
- `DryRun` (optional switch)
- `ForceFullSync` (optional switch)
- `RemovalWebhookUrl` (optional)

## Publish to Azure Automation

1. Create a PowerShell runbook in your Automation Account.
2. Paste/publish the content of `Track-EntraGroupRemovals.ps1`.
3. Configure a schedule.
4. Start with `ForceFullSync = true` on first run if you want a clean baseline.

## Local test example

```powershell
pwsh ./run-local.ps1 `
  -GroupId "<group-guid>" `
  -ResourceGroupName "<rg-name>" `
  -HostPoolResourceGroupName "<hostpool-rg-name>" `
  -HostPoolName "<hostpool-name>" `
  -StateStorageAccountName "<state-storage-account-name>" `
  -AuditStorageAccountName "<audit-storage-account-name>"
```

## Action hook

When users are removed, the runbook:

- writes each removed user to output
- optionally POSTs a payload to `RemovalWebhookUrl`

Customize `Invoke-RemovedUserAction` in `Track-EntraGroupRemovals.ps1` to integrate your target workflow.
