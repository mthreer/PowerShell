#Requires -Modules WebAdministration
#Requires -Version 5

param (
    [CmdletBinding()]
    [Parameter(Position=0,Mandatory=$true,HelpMessage="Input IIS AppPool name to retrieve its state")]
    [string]$Name
)
Import-Module WebAdministration

function LogAppPoolState($AppPoolName) {
	Try {
		$State=Get-WebAppPoolState -Name "$AppPoolName" -ErrorAction Stop
	}
	Catch {
		throw $_.Exception
	}
	if (($State.Value) -and ($State.Value -eq "Stopped" -or $State.Value -eq "Started")) {
		Switch ($State.Value) {
			"Stopped" { $EventId = "3001";$EntryType = "Warning" }
			"Started" { $EventId = "3000";$EntryType = "Information" }
		}
		Try { 
			$Source = Get-EventLog -LogName "Application" -Source "IIS AppPool $AppPoolName" -ErrorAction Stop
		}
		Catch {
			$null = New-EventLog -LogName "Application" -Source "IIS AppPool $AppPoolName"
		}
		Write-EventLog -LogName "Application" -Source "IIS AppPool $AppPoolName" -EventID $EventId -EntryType $EntryType -Message "IIS AppPool $AppPoolName state: $($State.Value)"
	}
}
$AppPoolNames = @(
	"DefaultAppPool"
)
if (-not($Name)) {
	ForEach ($AppPoolName in $AppPoolNames) { 
		LogAppPoolState -AppPoolName $AppPoolName
	}
}
if ($Name) {
	LogAppPoolState -AppPoolName $Name
}
