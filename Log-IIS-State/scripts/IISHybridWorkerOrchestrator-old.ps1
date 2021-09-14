Workflow IISHybridWorkerOrchestrator {
    Param(
        [Parameter(Mandatory=$False)]
        [String]$HybridWorkerGroups
    )

    if (-not($HybridWorkerGroups)) {
        throw "You need to specify at least one Hybrid Worker Group that the script should orchestrate powershell executions on."
    }
    if ($HybridWorkerGroups -and ($HybridWorkerGroups -match ",")) {
        $HybridWorkerGroupsArray = $HybridWorkerGroups -split ","
    }

    $Runbooks = @(
        "LogAppPoolState"
        "LogWebsiteState"
    )

    ## Authentication
    Write-Verbose "Logging into Azure ..."
    Try {
        # Ensures you do not inherit an AzContext in your runbook
        $null = Disable-AzContextAutosave –Scope Process
        # Connect to Azure using Managed Service Identity (MSI)
        $null = Connect-AzAccount -Identity -SkipContextPopulation -ErrorAction Stop
        # Verify that we have connected and that we have a context
        $Conn = Get-AzContext
        Write-Verbose "Successfully logged into Azure." 
    } 
    Catch {
        if (-not($Conn)) {
            $ErrorMessage = "Connection failed! A Managed Service Identity (MSI) could not be found."
            throw $ErrorMessage
        } 
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    ## End of authentication
    $null = Select-AzSubscription -SubscriptionId $Conn.Subscription

    # Retrieve ResourceGroupName and AutomationAccountName to use as input to Start-AzAutomationRunbook
    $ContextParameters = Get-AzAutomationAccount

    ForEach -Parallel ($HybridWorkerGroup in $HybridWorkerGroupsArray) {
        foreach ($Runbook in $Runbooks) {
            Try{
                $job = Start-AzAutomationRunbook -Name "$Runbook" -RunOn "$HybridWorkerGroup" -ResourceGroupName "$($ContextParameters.ResourceGroupName)" -AutomationAccountName "$($ContextParameters.AutomationAccountName)"
                Write-Output "Started parallel job `'$Runbook`' on `'$HybridWorkerGroup`': $($job.JobId)"
            }
            Catch {
                Write-Error -Message $_.Exception.Message
                throw $_.Exception
            }
        }
    }
}
