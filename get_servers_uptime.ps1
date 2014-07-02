<#
    Script gets uptime data for Windows & Linux servers. Use SSH-Sessions
    module to implement SSH connections through PowerShell.
    
    Copyright (C) 2014 Andrey Romanov

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

# Get windows servers uptime part
Set-ExecutionPolicy -Scope CurrentUser Unrestricted
Import-Module SSH-Sessions

Function Get-Uptime {
    Param([string]$ComputerName=$env:COMPUTERNAME)
    Process {
        if ($_) {$computername=$_}
        Get-WmiObject win32_operatingsystem -ComputerName $computername |
        Select-Object @{Name="Computername";Expression={$_.CSName}},
            @{Name="LastBoot";Expression={$_.ConvertToDateTime($_.LastBootUpTime)}},
            @{Name="Uptime";Expression={(Get-Date)-($_.ConvertToDateTime($_.LastBootUpTime))}}
    }
}

Get-Content -Path C:\win_servers.list | where {Test-Connection $_ -Quiet -Count 2} | Get-Uptime


# Get linux servers uptime part

Write-Output ""
$LinuxServers = Get-Content -Path C:\linux_servers.list
foreach ($Data in $LinuxServers)
{$ServerName, $Port = $Data -split(',')
    $output_srv = $ServerName + " : "
    New-SshSession -
    ComputerName $ServerName -Port $Port -Username user -Password pass > null
    $output_srv += Invoke-SshCommand -ComputerName $ServerName -Command "uptime" -Quiet
    Remove-SshSession -ComputerName $ServerName > $null
    Write-Host $output_srv
}
