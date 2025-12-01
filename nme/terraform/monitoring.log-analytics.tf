#
# Deploy the Datasources for the Log Analytics Agent
#

resource "azurerm_log_analytics_datasource_windows_event" "system_events" {
  name                = "SystemEvents"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  event_log_name      = "Application"
  event_types = [
    "Error",
    "Warning",
  ]
}

resource "azurerm_log_analytics_datasource_windows_event" "ts_local_session_manager_operational" {
  name                = "TerminalServicesLocalSessionManagerOperational"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  event_log_name      = "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"
  event_types = [
    "Error",
    "Warning",
    "Information",
  ]
}

resource "azurerm_log_analytics_datasource_windows_event" "ts_remote_connection_manager_admin" {
  name                = "TerminalServicesRemoteConnectionManagerAdmin"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  event_log_name      = "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin"
  event_types = [
    "Error",
    "Warning",
    "Information",
  ]
}

resource "azurerm_log_analytics_datasource_windows_event" "fs_logix_apps_operational" {
  name                = "MicrosoftFSLogixAppsOperational"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  event_log_name      = "Microsoft-FSLogix-Apps/Operational"
  event_types = [
    "Error",
    "Warning",
    "Information",
  ]
}

resource "azurerm_log_analytics_datasource_windows_event" "fs_logix_apps_admin" {
  name                = "MicrosoftFSLogixAppsAdmin"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  event_log_name      = "Microsoft-FSLogix-Apps/Admin"
  event_types = [
    "Error",
    "Warning",
    "Information",
  ]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "free_space_c" {
  name                = "FreeSpaceC"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "% Free Space"
  interval_seconds    = 60
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "avg_queue_length_c" {
  name                = "AvgQueueLengthC"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Avg. Disk Queue Length"
  interval_seconds    = 30
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "curr_queue_length_c" {
  name                = "CurrQueueLengthC"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Current Disk Queue Length"
  interval_seconds    = 30
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "avg_disk_transfer_c" {
  name                = "AvgDiskTransferC"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Avg. Disk sec/Transfer"
  interval_seconds    = 60
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "avail_memory" {
  name                = "AvailableMemory"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  object_name         = "Memory"
  instance_name       = "*"
  counter_name        = "Available Mbytes"
  interval_seconds    = 30
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "page_faults" {
  name                = "PageFaults"
  workspace_name      = azurerm_log_analytics_workspace.nerdio.name
  resource_group_name = azurerm_log_analytics_workspace.nerdio.resource_group_name
  object_name         = "Memory"
  instance_name       = "*"
  counter_name        = "Page Faults/sec"
  interval_seconds    = 30
}
