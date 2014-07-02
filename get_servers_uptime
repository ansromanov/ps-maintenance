

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
