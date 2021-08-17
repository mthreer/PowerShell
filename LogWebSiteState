#Requires -Modules WebAdministration
#Requires -Version 5

param (
    [CmdletBinding()]
    [Parameter(Position=0,Mandatory=$true,HelpMessage="Input IIS WebSite name to retrieve its state")]
    [string]$Name
)
Import-Module WebAdministration

function LogWebSiteState($WebSiteName) {
	Try {
		$State=Get-WebSiteState -Name "$WebSiteName" -ErrorAction Stop
	}
	Catch {
		throw $_.Exception
	}
	if (($State.Value) -and ($State.Value -eq "Stopped" -or $State.Value -eq "Started")) {
		Switch ($State.Value) {
			"Stopped" { $EventId = "4001";$EntryType = "Warning" }
			"Started" { $EventId = "4000";$EntryType = "Information" }
		}
		Try { 
			$Source = Get-EventLog -LogName "Application" -Source "IIS WebSite $WebSiteName" -ErrorAction Stop
		}
		Catch {
			$null = New-EventLog -LogName "Application" -Source "IIS WebSite $WebSiteName"
		}
		Write-EventLog -LogName "Application" -Source "IIS WebSite $WebSiteName" -EventID $EventId -EntryType $EntryType -Message "IIS WebSite $WebSiteName state: $($State.Value)"
	}
}

LogWebSiteState -WebSiteName $Name
