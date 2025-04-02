
install-Module -Name Az.Automation -AllowClobber
import-module  -Name Az.Automation

connect-azaccount -Identity
# Set the subscription context
$subscriptioninfo = Get-AzSubscription -SubscriptionName wolffentpsub
$TenantID = $subscriptioninfo.TenantId
Set-AzContext -Subscription $subscriptioninfo.Name -Tenant $TenantID


# Define variables
$automationAccountName = "wolffentpautoact"
$resourceGroupName = "jwgovernance"


#$jobname = 'automation_azure_storage_account_usage_sizes_Commerical'

  $runningjobs = Get-AzAutomationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName 

 foreach($jobid in $runningjobs  )
 {

 

$jobDetails = Get-AzAutomationJob -ResourceGroupName "$resourceGroupName" -AutomationAccountName "$automationAccountName" -Id "$($jobid.JobId.Guid)"
#$jobDetails 

$hybridWorkerGroup = $jobDetails.HybridWorker



$hybridWorkers = Get-AzAutomationHybridRunbookWorker -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -HybridRunbookWorkerGroupName $hybridWorkerGroup


$jobOutput = Get-AzAutomationJobOutput -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Id $($jobDetails.JobId.Guid)


Write-Output "Job ID: $($jobDetails.JobId)  $($jobid.runbookname) is running on Hybrid Worker: $($jobDetails.HybridWorker)"
     #   $hybridWorkers = Get-AzAutomationHybridRunbookWorker  -ResourceGroupName $resourceGroupName -AutomationAccountName "$automationAccountName" -HybridRunbookWorkerGroupName  $($job.HybridWorker)  

        $($hybridWorkers.workername)


}









