Workflow IISHybridWorkerOrchestrator {
    Param(
        [Parameter (Mandatory= $false)]
        [Object]$WebhookData
    )

    if ($WebhookData) {
        Write-Verbose $WebhookData

        # Check header for message to validate request
        if ($WebhookData.RequestHeader.Key -eq 'c5f8d8d8-bf94-4132-a305-0a6f07921e21') {
            Write-Verbose "Header has required information"

            # We dont provide the body
            #$HybridWorkerGroups = (ConvertFrom-Json -InputObject $WebhookData.RequestBody).HybridWorkerGroups
        }
        else {
            Write-Verbose "Header missing required information";
            exit;
        }
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

    # Retrieve all Hybrid Worker Groups
    $AllHybridWorkerGroups = (Get-AzAutomationHybridWorkerGroup -ResourceGroupName "$($ContextParameters.ResourceGroupName)" -AutomationAccountName "$($ContextParameters.AutomationAccountName)" -ErrorAction SilentlyContinue).Name

    if ($AllHybridWorkerGroups) {
        ForEach -Parallel ($HybridWorkerGroup in $AllHybridWorkerGroups) {
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
}
