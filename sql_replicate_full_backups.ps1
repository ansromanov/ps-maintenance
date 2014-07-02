<#
    MSSQL full backups replication/archiving script

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
    
Start-Transcript # Script output to log file


# Initializing variables
# ----------------------

$Begintime = Get-Date # Need for calculating backup processing time

Set-Alias -name SevenZip -value "C:\Program Files\7-Zip\7z.exe"
$InitialBackupsDirectory = "D:\SQLBackups" 

# Search for newest backups directory and parse its shortname 
#$CurrentBackupsFolder = (Get-ChildItem $InitialBackupsDirectory | `
#    ? {$_.PSIsContainer} | `
#    Sort-Object -Property LastWriteTime | `
#    Select-Object -Last 1 -Property Name).Name.ToString() 

# Alternate method- yesterday backups directory
$CurrentBackupsFolder = Get-Date -Uformat %Y%m%d -displayhint date `
    ((get-date).adddays(-1))


# Search for newest backups directory and parse fullname path
# to full backups subdirectory
#$FullBackupsDirectory = (Get-ChildItem $InitialBackupsDirectory | `
#    ? {$_.PSIsContainer} | `
#    Sort-Object -Property LastWriteTime | `
#    Select-Object -Last 1 `
#        -Property FullName).FullName.ToString() + "\Full"

# Alternate method
$FullBackupsDirectory = $InitialBackupsDirectory + "\" + `
    $CurrentBackupsFolder + "\Full"

# Wildcard to all MSSQL backups
$InitialBackupsName = $FullBackupsDirectory + '\*.bak'

# Result backups archive name
$DestBackupName = $FullBackupsDirectory `
    + '\' + $CurrentBackupsFolder + '_all_databases_full.7z'


# Mounting Network Drive
# ----------------------

If (!(Test-Path R:)) {
    New-PSDrive -Name R -PSProvider FileSystem -Root \\server\SQL
    Echo "Net drive mounted"
}


# Backup creating
# ---------------

Write-Host "Creating archive..." 

# If archive name exists, delete it before. This prevents 7-zip error
If (Test-Path $DestBackupName) {
    Remove-Item $DestBackupName
}

$LogPath = 'D:\SQLBackups\' + $Begintime + '_7zip.log'

# Archive backups and parsing result to a variable with html tags
$Result = SevenZip a -mx6 $DestBackupName $InitialBackupsName `
    | ForEach-Object {$_ + "<br>"}

Write-Host "Archive creating done"
Write-Host "Copying backup to network drive"



$NetCopyBackupName = "r:\"

# If not exist, create directory for diff backups on network drive
If (!(Test-Path $NetCopyBackupName)) {
    New-Item $NetCopyBackupName -ItemType directory
}

Move-Item -Path $DestBackupName -Destination $NetCopyBackupName -Force

Write-Host "Backup copy done"


# Unmounting Network Drive
# ----------------------
If (!(Test-Path R:)) {
    Remove-PSDrive -Name R
    Write-Host "Net folder unmounted"
}

$endtime = Get-Date # Need for calculating backup processing time


# Sending result on email
# -----------------------

Write-Host "Creating mail"

$ResTime = $EndTime - $BeginTime # Backup processing time
$EmailFrom = “sql@contoso.com”
$Subject = "Отчет о резервном копировании полной копии баз MSSQL с сервера SQL"

$Body = " " + $DestBackupName + ".<br>Done in " + $restime.Hours + `
        " H. " + $restime.Minutes + " min. " + $restime.Seconds + `
        " sec." + "<br>" + $Result
        
$SmtpServer = “smtp.yandex.ru”
$secpasswd = ConvertTo-SecureString "securedString" -AsPlainText -Force

$mycreds = New-Object System.Management.Automation.PSCredential `
        ("sql@contoso.com", $secpasswd)

$EmailTo = “itdep@contoso.com”

Send-MailMessage -SmtpServer $SmtpServer -From $EmailFrom -To $EmailTo `
        -Subject $Subject -Body $Body -credential $mycreds -Encoding OEM -BodyAsHtml

Write-Host "Mail sended"

Stop-Transcript # Stop script output
