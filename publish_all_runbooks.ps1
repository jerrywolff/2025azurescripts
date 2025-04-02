 connect-azaccount #-Identity controlmi  #-Environment AzureUSGovernment



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



# Login to Azure - if already logged in, use existing credentials.
Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
try
{
    $AzureLogin = Get-AzSubscription
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken 
    if($Token.ExpiresOn -lt $(get-date))
    {
        "Logging you out due to cached token is expired for REST AUTH.  Re-run script"
        $null = Disconnect-AzAccount        
    } 
}
catch
{
    $null = Login-AzAccount
    $AzureLogin = Get-AzSubscription
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken

}
 
 $automationaccounts = Get-AzAutomationAccount -Name wolffentpautoact  -ResourceGroupName jwgovernance
 
 
 $runbooks  = Get-AzAutomationRunbook -ResourceGroupName jwgovernance -AutomationAccountName wolffentpautoact

 foreach($runbook in  $runbooks )
 {
  


# Publish the runbook
Publish-AzAutomationRunbook -ResourceGroupName $ResourceGroupName `
                            -AutomationAccountName $AutomationAccountName `
                            -Name $($runbook.name)

Write-Output "Runbook published: $($runbook.name)"
}