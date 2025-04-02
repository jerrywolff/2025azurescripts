 connect-azaccount  #-Environment AzureUSGovernment

 import-module az.automation -verbose


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
 
 $running = (Get-AzAutomationJob -ResourceGroupName jwgovernance -AutomationAccountName wolffentpautoact   -Status suspended  | Select-Object JobId)

  foreach($job in $running){
   resume-AzAutomationJob -ResourceGroupName jwgovernance -AutomationAccountName wolffentpautoact -Id $($Job.JobId) -Verbose
  }