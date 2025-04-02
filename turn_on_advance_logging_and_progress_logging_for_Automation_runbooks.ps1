Install-Module -Name Az.Automation
import-module  -Name Az.Automation

connect-azaccount -Identity
# Set the subscription context
$subscriptioninfo = Get-AzSubscription -SubscriptionName wolffentpsub
$TenantID = $subscriptioninfo.TenantId
Set-AzContext -Subscription $subscriptioninfo.Name -Tenant $TenantID


# Define variables
$automationAccountName = "wolffentpautoact"
$resourceGroupName = "jwgovernance"

# Get the Automation Account context
#$AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName

  $runbooks = Get-AzAutomationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName 

 foreach($runbook in $runbooks )
  {
  

# Enable verbose logging and progress logging for the runbook
Set-AzAutomationRunbook -ResourceGroupName $ResourceGroupName `
                        -AutomationAccountName $automationAccountName `
                        -RunbookName $($runbook.RunbookName) `
                        -LogVerbose $true `
                        -LogProgress $true

Write-Output "Verbose and progress logging enabled for runbook: $RunbookName"





  }