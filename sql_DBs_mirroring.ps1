<#
    Enable database mirroring script on multiply databases according "principal, mirror, withess" scheme.

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

### Set initial variables
$DBServerPrincipal = "SQL" # Principal server
$DBServerMirroring = "SQLMirror"
$DBServerWitness = "SQLWitness"
#$DomainName = "contoso.com"
#$DBMirroringPort = "7022"
$DBPrincipalFQDN = "\\" + $DBServerPrincipal + "\Tempbackups\Mirroring"
$DBMirroringFQDN = "\\" + $DBServerMirroring + "\Tempbackups\Mirroring"
$DatabaseName = "master"
$ConnectionTimeout = 1
$QueryTimeout = 3000



### Get list of databases, need to be mirrored
Write-Host "1) Getting databases list used for mirroring from server $DBServerPrincipal." -ForegroundColor Yellow
$Connection = New-Object System.Data.SQLClient.SQLConnection
$Connection.ConnectionString = "server=$DBServerPrincipal;database=$DatabaseName;trusted_connection=True; `
    connect timeout=$ConnectionTimeout"
#Write-host "Connection Information:"  -foregroundcolor yellow -backgroundcolor black
#$Connection #List connection information

try { $Connection.open() }

catch
{
    if ($Connection.State -ne "Open") {
        Write-Host "The connection to $DBServerPrincipal server is $($Connection.State). There has been an error connecting to the database `"$DatabaseName`"." -ForegroundColor Red;
        exit
    }
}
Write-Host "Connection to database `"$DatabaseName`" on $DBServerPrincipal successful." -foregroundcolor green

$SqlQuery = @"
		SELECT TOP 10 d.name
	
		FROM sys.databases d
		inner JOIN sys.[database_mirroring] dm
		ON dm.database_id = d.database_id
		WHERE dm.mirroring_role IS NULL
			AND dm.mirroring_state IS NULL
			AND d.name NOT IN ('master','tempdb','model','msdb','ReportServer','ReportServerTempDB',
                'db_to_exclude1','db_to_exclude2')
			AND d.name not like 'tmp%'
			AND d.name not like '%tmp'
			AND d.name not like '%__tmp__%' escape '_'
			AND d.name not like 'test%'
			AND d.name not like '%test'
			AND d.name not like '%__old' escape '_'
			AND d.name not like 'demo%'
			AND d.name not like '%demo'
            --AND (d.name like 'tmp%'
			--OR d.name like '%tmp')
		ORDER BY dm.database_id

"@

$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandTimeout = $QueryTimeout
$SqlCmd.CommandText = $SqlQuery
$SqlCmd.Connection = $Connection

$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCmd)
$DataSet = New-Object System.Data.DataSet
$dbCount = $SqlAdapter.Fill($DataSet)

Write-Host -foregroundcolor yellow "Found $dbCount databases:"

$DataTable=New-Object System.Data.DataTable
$DataTable=$DataSet.Tables[0]
$result = $DataTable.DefaultView
Write-Host -Separator "`n"  $result.name

$Connection.Close()



### Create mirroring directories
Write-Host "`n2) Creating essential directories" -ForegroundColor Yellow
If (!(Test-Path $DBPrincipalFQDN)) {
            New-Item -ItemType directory $DBPrincipalFQDN -ErrorAction SilentlyContinue
            If ($? -eq $true) {
                Write-Host "Create $DBPrincipalFQDN" -ForegroundColor Green
            }
            Else {
                Write-Host "Failed to create directory $DBPrincipalFQDN" -ForegroundColor Red
                exit
            }
        }

If (!(Test-Path $DBMirroringFQDN)) {
            New-Item -ItemType directory $DBMirroringFQDN -ErrorAction SilentlyContinue
            If ($? -eq $true) {
                Write-Host "Create $DBMirroringFQDN" -ForegroundColor Green
            }
            Else {
                Write-Host "Failed to create directory $DBMirroringFQDN" -ForegroundColor Red
                exit
            }
        }



### Create mirroring for each database
Write-Host "`n3) Set database mirroring" -ForegroundColor Yellow

foreach ($line in $result) {
        $DBName = $line[0] # Current database
        
                  
        ### Backup database
        Write-host "`nBackup database `"$DBName`" to $DBPrincipalFQDN\$DBName.bak" -foregroundcolor yellow
        $Connection = New-Object System.Data.SQLClient.SQLConnection
        $Connection.ConnectionString = "server=$DBServerPrincipal;database=$DatabaseName;trusted_connection=True; `
            connect timeout=$ConnectionTimeout"
        
        try { $Connection.open() }

        catch {
            if ($Connection.State -ne "Open") {
                Write-Host "The connection to $DBServerPrincipal server is $($Connection.State). There has been an error connecting to the database `"$DatabaseName`"." -ForegroundColor Red;
                exit
            }
        }
        Write-Host "Connection to database `"$DatabaseName`" on $DBServerPrincipal successful." -foregroundcolor green
        
        $SqlQuery = @"
ALTER DATABASE [$DBName] 
SET RECOVERY FULL;    

BACKUP DATABASE [$DBName] 
TO  DISK = N'D:\Tempbackups\Mirroring\$DBName.bak' WITH NOFORMAT, INIT,  
NAME = N'$DBName-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10

BACKUP LOG [$DBName] 
TO  DISK = N'D:\Tempbackups\Mirroring\$DBName-log.bak' WITH NOFORMAT, INIT,  
NAME = N'$DBName-Transaction Log Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
"@
        
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandTimeout = $QueryTimeout
        $SqlCmd.CommandText = $SqlQuery
        $SqlCmd.Connection = $Connection
        $result = $SqlCmd.ExecuteNonQuery()
        
        $Connection.Close()
        
        if (! ((Test-Path "$DBPrincipalFQDN\$DBName.bak") -and (Test-Path "$DBPrincipalFQDN\$DBName-log.bak")) ) {
            Write-Host -ForegroundColor Red "Backup of database `"$DBName`" failed!"
            #continue 
        }
        Write-Host -ForegroundColor Green "Backup of database `"$DBName`" done"    
        
                
        ### Copy backup and log from principal server to mirror
        Write-Host "Copy database files to $DBMirroringFQDN" -ForegroundColor Yellow
        $CopyPath = "$DBPrincipalFQDN\$DBName.bak"
        Copy-Item -Path $CopyPath -Destination $DBMirroringFQDN -Force -ErrorAction SilentlyContinue
        If ($? -eq $true)
        {
            Write-Host "File $DBPrincipalFQDN\$DBName.bak succesfully copied to $DBMirroringFQDN" -ForegroundColor Green
        }
        Else
        {
            Write-Host "Failed to copy file $DBPrincipalFQDN\$DBName.bak to $DBMirroringFQDN" -ForegroundColor Red
            #continue
        }

        $CopyPath = "$DBPrincipalFQDN\$DBName-log.bak"
        Copy-Item -Path $CopyPath -Destination $DBMirroringFQDN -Force -ErrorAction SilentlyContinue
        If ($? -eq $true)
        {
            Write-Host "File $DBPrincipalFQDN\$DBName-log.bak succesfully copied to $DBMirroringFQDN" -ForegroundColor Green    
        }
        Else
        {
            Write-Host "Failed to copy file $DBPrincipalFQDN\$DBName-log.bak to $DBMirroringFQDN" -ForegroundColor Red
            #continue
        }
        

        ### Restore database
        Write-Host "Restore database files to $DBMirroringFQDN" -ForegroundColor Yellow
        $Connection = New-Object System.Data.SQLClient.SQLConnection
        $Connection.ConnectionString = "server=$DBServerMirroring;database=$DatabaseName;trusted_connection=True; `
            connect timeout=$ConnectionTimeout"
        #
        try { $Connection.open() }

        catch {
            if ($Connection.State -ne "Open") {
                Write-Host "The connection to $DBServerMirroring server is $($Connection.State). There has been an error connecting to the database `"$DatabaseName`"." -ForegroundColor Red;
                exit
            }
        }
        Write-Host "Connection to database `"$DatabaseName`" on $DBServerMirroring successful." -foregroundcolor green
        
        $SqlQuery = @"    
RESTORE DATABASE [$DBName] 
FROM  DISK = N'D:\TempBackups\Mirroring\$DBName.bak' WITH  FILE = 1,
  NORECOVERY,  NOUNLOAD,  REPLACE,  STATS = 5

RESTORE LOG [$DBName]
 FROM  DISK = N'D:\TempBackups\Mirroring\$DBName-log.bak' WITH  FILE = 1,
   NORECOVERY,  NOUNLOAD,  REPLACE,  STATS = 10

ALTER DATABASE [$DBName]
	SET PARTNER = 'TCP://$DBServerPrincipal.contoso.com:7022'
"@
        
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandTimeout = $QueryTimeout
        $SqlCmd.CommandText = $SqlQuery
        $SqlCmd.Connection = $Connection
        $result = $SqlCmd.ExecuteNonQuery()
        
        $Connection.Close()
        
        Write-Host "Restore database `"$DBName`" done" -ForegroundColor Green
        
        
        ### End of mirroring
        Write-Host "Set database `"$DBName`" mirroring" -ForegroundColor Yellow 
        $Connection = New-Object System.Data.SQLClient.SQLConnection
        $Connection.ConnectionString = "server=$DBServerPrincipal;database=$DatabaseName;trusted_connection=True; `
            connect timeout=$ConnectionTimeout"
        try { $Connection.open() }

        catch {
            if ($Connection.State -ne "Open") {
                Write-Host "The connection to $DBServerPrincipal server is $($Connection.State). There has been an error connecting to the database `"$DatabaseName`"." -ForegroundColor Red;
                exit
            }
        }
        Write-Host "Connection to database `"$DatabaseName`" on $DBServerPrincipal successful." -foregroundcolor green
        
        $SqlQuery = @"    
ALTER DATABASE [$DBName]
	SET PARTNER = 'TCP://$DBServerMirroring.contoso.com:7022'

ALTER DATABASE  [$DBName]
    SET WITNESS = 
    'TCP://$DBServerWitness.contoso.com:7022'
"@
        
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandTimeout = $QueryTimeout
        $SqlCmd.CommandText = $SqlQuery
        $SqlCmd.Connection = $Connection
        $result = $SqlCmd.ExecuteNonQuery()
        
        $Connection.Close()
        
        $echo = "Mirroring of " + $DBName + " database done"
        Write-Host "Mirroring of database `"$DBName`" done" -ForegroundColor Green
}



### Delete temporary files
Remove-Item $DBPrincipalFQDN -Recurse
Remove-Item $DBMirroringFQDN -Recurse
