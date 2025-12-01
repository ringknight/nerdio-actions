locals {
  performance_counters = {
    # Logical Disk
    FreeSpaceC = {
      object_name      = "LogicalDisk",
      instance_name    = "C:",
      counter_name     = "% Free Space"
      interval_seconds = 60,
    }
    AvgQueueLengthC = {
      object_name      = "LogicalDisk",
      instance_name    = "C:",
      counter_name     = "Avg. Disk Queue Length"
      interval_seconds = 30,
    }
    AvgLogDiskTransferC = {
      object_name      = "LogicalDisk",
      instance_name    = "C:",
      counter_name     = "Avg. Disk sec/Transfer"
      interval_seconds = 60,
    }
    CurrQueueLengthC = {
      object_name      = "LogicalDisk",
      instance_name    = "C:",
      counter_name     = "Current Disk Queue Length"
      interval_seconds = 30,
    }
    # Physical Disk
    AvgPhyDiskReadC = {
      object_name      = "PhysicalDisk",
      instance_name    = "*",
      counter_name     = "Avg. Disk sec/Read"
      interval_seconds = 30,
    }
    AvgPhyDiskWriteC = {
      object_name      = "PhysicalDisk",
      instance_name    = "*",
      counter_name     = "Avg. Disk sec/Write"
      interval_seconds = 30,
    }
    AvgPhyDiskTransferC = {
      object_name      = "PhysicalDisk",
      instance_name    = "*",
      counter_name     = "Avg. Disk sec/Transfer"
      interval_seconds = 30,
    }
    AvgQueueLengthC = {
      object_name      = "PhysicalDisk",
      instance_name    = "*",
      counter_name     = "Avg. Disk Queue Length"
      interval_seconds = 30,
    }
    # Memory
    AvailableMemory = {
      object_name      = "Memory",
      instance_name    = "*",
      counter_name     = "Available Mbytes"
      interval_seconds = 30,
    }
    PageFaults = {
      object_name      = "Memory",
      instance_name    = "*",
      counter_name     = "Page Faults/sec"
      interval_seconds = 30,
    }
    Pages = {
      object_name      = "Memory",
      instance_name    = "*",
      counter_name     = "Pages/sec"
      interval_seconds = 30,
    }
    CommittedBytes = {
      object_name      = "Memory",
      instance_name    = "*",
      counter_name     = "% Committed Bytes In Use"
      interval_seconds = 30,
    }
    # Processor
    ProcessorPercent = {
      object_name      = "Processor Information",
      instance_name    = "_Total",
      counter_name     = "% Processor Time"
      interval_seconds = 30,
    }
    # Terminal Services
    ActiveSessions = {
      object_name      = "Terminal Services",
      instance_name    = "*",
      counter_name     = "Active Sessions"
      interval_seconds = 60,
    }
    InactiveSessions = {
      object_name      = "Terminal Services",
      instance_name    = "*",
      counter_name     = "Inactive Sessions"
      interval_seconds = 60,
    }
    TotalSessions = {
      object_name      = "Terminal Services",
      instance_name    = "*",
      counter_name     = "Total Sessions"
      interval_seconds = 60,
    }
    UserInputDelayPerProcess = {
      object_name      = "User Input Delay per Process",
      instance_name    = "*",
      counter_name     = "Max Input Delay"
      interval_seconds = 30,
    }
    UserInputDelayPerSession = {
      object_name      = "User Input Delay per Session",
      instance_name    = "*",
      counter_name     = "Max Input Delay"
      interval_seconds = 30,
    }
    # RemoteFX
    TcpRtt = {
      object_name      = "RemoteFX Network",
      instance_name    = "*",
      counter_name     = "Current TCP RTT"
      interval_seconds = 30,
    }
    UdpBandwidth = {
      object_name      = "RemoteFX Network",
      instance_name    = "*",
      counter_name     = "Current UDP Bandwidth"
      interval_seconds = 30,
    }
  }
}
