<#
    Show user logon history script.
    
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

Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" | `
    Where-Object {($_.ID -eq 21) -and ($_.Message -match "domain\user") -and !($_.Message -match "")} | `
    Format-Table -Property TimeCreated, Id, Message -Wrap -AutoSize
