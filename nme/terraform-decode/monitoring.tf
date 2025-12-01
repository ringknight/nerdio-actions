# Log Analytics Data Sources - Windows Events
# Apply this file separately after main infrastructure is deployed:
# terraform apply -var="resource_group_name=rg-NerdioManager1-aue" -target=module.monitoring

resource "azurerm_log_analytics_datasource_windows_event" "system" {
  name                = "SystemEvents"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  event_log_name      = "System"
  event_types         = ["Error", "Warning"]
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_event" "application" {
  name                = "ApplicationEvents"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  event_log_name      = "Application"
  event_types         = ["Error", "Warning"]
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_event" "terminal_services_local" {
  name                = "TerminalServicesLocalSessionManagerOperational"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  event_log_name      = "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"
  event_types         = ["Error", "Warning", "Information"]
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_event" "terminal_services_remote" {
  name                = "TerminalServicesRemoteConnectionManagerAdmin"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  event_log_name      = "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin"
  event_types         = ["Error", "Warning", "Information"]
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_event" "fslogix_operational" {
  name                = "MicrosoftFSLogixAppsOperational"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  event_log_name      = "Microsoft-FSLogix-Apps/Operational"
  event_types         = ["Error", "Warning", "Information"]
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_event" "fslogix_admin" {
  name                = "MicrosoftFSLogixAppsAdmin"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  event_log_name      = "Microsoft-FSLogix-Apps/Admin"
  event_types         = ["Error", "Warning", "Information"]
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

# Log Analytics Performance Counters
resource "azurerm_log_analytics_datasource_windows_performance_counter" "disk_free_space" {
  name                = "perfcounter1"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "% Free Space"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "disk_avg_queue_length" {
  name                = "perfcounter2"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Avg. Disk Queue Length"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "disk_avg_sec_transfer" {
  name                = "perfcounter3"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Avg. Disk sec/Transfer"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "disk_current_queue_length" {
  name                = "perfcounter4"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Current Disk Queue Length"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "disk_reads_sec" {
  name                = "perfcounter5"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Disk Reads/sec"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "disk_transfers_sec" {
  name                = "perfcounter6"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Disk Transfers/sec"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "disk_writes_sec" {
  name                = "perfcounter7"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "LogicalDisk"
  instance_name       = "C:"
  counter_name        = "Disk Writes/sec"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "memory_available_mb" {
  name                = "perfcounter8"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "Memory"
  instance_name       = "*"
  counter_name        = "Available Mbytes"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "memory_page_faults_sec" {
  name                = "perfcounter9"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "Memory"
  instance_name       = "*"
  counter_name        = "Page Faults/sec"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "memory_pages_sec" {
  name                = "perfcounter10"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "Memory"
  instance_name       = "*"
  counter_name        = "Pages/sec"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "memory_percent_committed_bytes" {
  name                = "perfcounter11"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "Memory"
  instance_name       = "*"
  counter_name        = "% Committed Bytes In Use"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "physical_disk_avg_sec_read" {
  name                = "perfcounter12"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "PhysicalDisk"
  instance_name       = "*"
  counter_name        = "Avg. Disk sec/Read"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "physical_disk_avg_sec_write" {
  name                = "perfcounter13"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "PhysicalDisk"
  instance_name       = "*"
  counter_name        = "Avg. Disk sec/Write"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "processor_percent_processor_time" {
  name                = "perfcounter14"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "Processor Information"
  instance_name       = "_Total"
  counter_name        = "% Processor Time"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "terminal_services_sessions" {
  name                = "perfcounter15"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "Terminal Services"
  instance_name       = "*"
  counter_name        = "Active Sessions"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "user_input_delay" {
  name                = "perfcounter16"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "User Input Delay per Process"
  instance_name       = "*"
  counter_name        = "Max Input Delay"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "user_input_delay_session" {
  name                = "perfcounter17"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "User Input Delay per Session"
  instance_name       = "*"
  counter_name        = "Max Input Delay"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "network_bytes_total" {
  name                = "perfcounter18"
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_name      = azurerm_log_analytics_workspace.avd.name
  object_name         = "Network Interface"
  instance_name       = "*"
  counter_name        = "Bytes Total/sec"
  interval_seconds    = 60
  
  depends_on = [azurerm_log_analytics_workspace.avd]
}
