#Requires -Modules WebAdministration
#Requires -Version 5

# Optional parameter input
param (
    [CmdletBinding()]
    [Parameter(Position=0,Mandatory=$false,HelpMessage="Input IIS WebSite name to retrieve its state")]
    [string]$Name
)

# Import the IIS WebAdministration module
Import-Module WebAdministration

function LogWebSiteState($WebSiteName) {
	# Try to retrieve the state
	Try {
		$State=Get-WebSiteState -Name "$WebSiteName" -ErrorAction Stop
	}
	Catch {
		throw $_.Exception
	}
	# Check if state has a value and that it contains either Stopped or Started before continuing
	if (($State.Value) -and ($State.Value -eq "Stopped" -or $State.Value -eq "Started")) {
		Switch ($State.Value) {
			"Stopped" { $EventId = "4001"; $EntryType = "Warning"; [Switch]$WriteEventLog = $True }
			"Started" { $EventId = "4000"; $EntryType = "Information"; [Switch]$WriteEventLog = $False }
		}
		# Write to EventLog if $WriteEventLog is True
		if ($WriteEventLog) {
			Try { 
				# Check if the EventLog Source is already created
				$Source = Get-EventLog -LogName "Application" -Source "IIS WebSite $WebSiteName" -ErrorAction Stop
			}
			Catch {
				# Create the EventLog Source 
				$null = New-EventLog -LogName "Application" -Source "IIS WebSite $WebSiteName"
			}
			# Write to the EventLog
			Write-EventLog -LogName "Application" -Source "IIS WebSite $WebSiteName" -EventID $EventId -EntryType $EntryType -Message "IIS WebSite $WebSiteName state: $($State.Value)"
		}
	}
}
# Add each WebSite Name to monitor
$Sites = @(
	"Default Web Site"
)
# Loop through array of WebSiteNames, if not parameter input $Name is being used
if (-not($Name)) {
	ForEach ($Site in $Sites) { 
		LogWebSiteState -WebSiteName $Site
	}
}
# If parameter input $Name is being used
if ($Name) {
	# execute the function LogWebSiteState that logs state to event log
	LogWebSiteState -WebSiteName $Name
}
