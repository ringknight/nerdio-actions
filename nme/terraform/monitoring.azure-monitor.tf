# Deploy Data Collection Rules for Azure Monitor agent

resource "azurerm_log_analytics_solution" "event_forwarding" {
  solution_name         = "WindowsEventForwarding"
  location              = local.resource_group_location
  resource_group_name   = local.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.nerdio.id
  workspace_name        = azurerm_log_analytics_workspace.nerdio.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/WindowsEventForwarding"
  }
}

/*
resource "azurerm_monitor_data_collection_rule" "nerdio" {
  name                = "VirtualDesktops"
  location            = azurerm_resource_group.nerdio.location
  resource_group_name = azurerm_resource_group.nerdio.name
  description         = "Data Collection rules for Azure Virtual Desktops"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.nerdio.id
      name                  = "LogAnalytics"
    }

    azure_monitor_metrics {
      name = "AzureMetrics"
    }
  }

  data_flow {
    destinations = ["AzureMetrics"]
    streams = [
      "Microsoft-InsightsMetrics"
    ]
  }

  data_flow {
    destinations = ["LogAnalytics"]
    streams = [
      "Microsoft-InsightsMetrics",
      "Microsoft-Syslog",
      "Microsoft-Perf"
    ]
  }

  data_sources {
    performance_counter {
      name                          = "FreeSpaceC"
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = ["LogicalDisk(C:)\\% Free Space"]
    }

    performance_counter {
      name                          = "AvgQueueLengthC"
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 30
      counter_specifiers            = ["LogicalDisk(C:)\\Avg. Disk Queue Length"]
    }

    performance_counter {
      name                          = "CurrQueueLengthC"
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 30
      counter_specifiers            = ["LogicalDisk(C:)\\Current Disk Queue Length"]
    }

    performance_counter {
      name                          = "AvgDiskTransferC"
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = ["LogicalDisk(C:)\\Avg. Disk sec/Transfer"]
    }

    performance_counter {
      name                          = "AvailableMemory"
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 30
      counter_specifiers            = ["Memory(*)\\Available Mbytes"]
    }

    performance_counter {
      name                          = "PageFaults"
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 30
      counter_specifiers            = ["Memory(*)\\Page Faults/sec"]
    }

    windows_event_log {
      name           = "SystemEvents"
      streams        = ["Microsoft-WindowsEvent"]
      x_path_queries = ["*[Application/Level <= 2]"]
    }

    windows_event_log {
      name           = "TS-LSM-Operational"
      streams        = ["Microsoft-WindowsEvent"]
      x_path_queries = ["*[Microsoft-Windows-TerminalServices-LocalSessionManager/Operational <= 3]"]
    }

    windows_event_log {
      name           = "TS-RCM-Admin"
      streams        = ["Microsoft-WindowsEvent"]
      x_path_queries = ["*[Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin <= 3]"]
    }

    windows_event_log {
      name           = "FSLogix-Operational"
      streams        = ["Microsoft-WindowsEvent"]
      x_path_queries = ["*[Microsoft-FSLogix-Apps/Operational <= 3]"]
    }

    windows_event_log {
      name           = "FSLogix-Admin"
      streams        = ["Microsoft-WindowsEvent"]
      x_path_queries = ["*[Microsoft-FSLogix-Apps/Admin <= 3]"]
    }
  }

  tags = var.tags

  depends_on = [
    azurerm_log_analytics_solution.event_forwarding
  ]
}
*/
