#Requires -Modules WebAdministration
#Requires -Version 5

# Optional parameter input
param (
    [CmdletBinding()]
    [Parameter(Position=0,Mandatory=$false,HelpMessage="Input IIS AppPool name to retrieve its state")]
    [string]$Name
)

# Import the IIS WebAdministration module
Import-Module WebAdministration

function LogAppPoolState($AppPoolName) {
    # Try to retrieve the state
    Try {
        $State=Get-WebAppPoolState -Name "$AppPoolName" -ErrorAction Stop
    }
    Catch {
        Write-Verbose $_.Exception
        Continue;
    }
    # Check if state has a value and that it contains either Stopped or Started before continuing
    if (($State.Value) -and ($State.Value -eq "Stopped" -or $State.Value -eq "Started")) {
        Switch ($State.Value) {
            "Stopped" { $EventId = "3001"; $EntryType = "Warning"; [Switch]$WriteEventLog = $True }
            "Started" { $EventId = "3000"; $EntryType = "Information"; [Switch]$WriteEventLog = $False }
        }
        # Log to Azure Automation Job Output
        Write-Output "IIS AppPools `'$AppPoolName`' state: $($State.Value)"

        # Write to EventLog if $WriteEventLog is True
        if ($WriteEventLog) {
            Try { 
                # Check if the EventLog Source is already created
                $null = New-EventLog -LogName "Application" -Source "IIS AppPool `'$AppPoolName`'" -ErrorAction Stop
            }
            Catch {
                
            }
            # Write to the EventLog
            Write-EventLog -LogName "Application" -Source "IIS AppPool `'$AppPoolName`'" -EventID $EventId -EntryType $EntryType -Message "IIS AppPool `'$AppPoolName`' state: $($State.Value)"
        }
    }
}
# Add each AppPool Name to monitor
$AppPoolNames = @(
    "DefaultAppPool"
)
# Loop through array of AppPoolNames, if not parameter input $Name is being used
if (-not($Name)) {
    ForEach ($AppPoolName in $AppPoolNames) { 
        # execute the function LogAppPoolState that logs state to event log
        LogAppPoolState -AppPoolName $AppPoolName
    }
}
# If parameter input $Name is being used
if ($Name) {
    # execute the function LogAppPoolState that logs state to event log
    LogAppPoolState -AppPoolName $Name
}