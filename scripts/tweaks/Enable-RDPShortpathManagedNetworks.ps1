#description: Enable RDP Shortpath for managed networks. Reboot required.
#execution mode: Combined
#tags: RDP Shortpath, Image
<#
https://docs.microsoft.com/en-us/azure/virtual-desktop/shortpath
#>

# Add registry keys
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" /v "fUseUdpPortRedirector" /t "REG_DWORD" /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" /v "UdpPortNumber" /t "REG_DWORD" /d 3390 /f | Out-Null

# Add windows firewall rule
$params = @{
    DisplayName = "Remote Desktop - RDP Shortpath (UDP-In)"
    Action      = "Allow"
    Description = "Inbound rule for the Remote Desktop service to allow RDP traffic. [UDP 3390]"
    Group       = "@FirewallAPI.dll,-28752"
    Name        = "RemoteDesktop-UserMode-In-Shortpath-UDP"
    PolicyStore = "PersistentStore"
    Profile      = "Domain, Private"
    Service     = "TermService"
    Protocol    = "udp"
    LocalPort   = 3390
    Program     = "$env:SystemRoot\system32\svchost.exe"
    Enabled     = "true"
    ErrorAction = "Stop"
}
New-NetFirewallRule @params