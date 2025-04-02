import-module -name az.RecoveryServices | out-null


$connection = connect-azaccount  # -Environment AzureUSGovernment
$credential = Get-AzAccessToken


$vaultinfo = ''

$subscriptions = get-azsubscription

$subscriptionselected = $subscriptions | ogv -Title " Select the subscription for the restoration process: " -PassThru | Select * -First 1

        
   foreach($subscription in $subscriptionselected)

  { 
  
              Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
                        try
                        {
                            $AzureLogin = Get-AzSubscription 
                            $currentContext = Get-AzContext
                            $token = Get-AzAccessToken -TenantId $($subscription.TenantId)
                            if($Token.ExpiresOn -lt $(get-date))
                            {
                                "Logging you out due to cached token is expired for REST AUTH.  Re-run script"
                                #$null = Disconnect-AzAccount        
                            } 
                  
                        }
                        catch
                        {

                            $AzureLogin = Get-AzSubscription  
                            $currentContext = Get-AzContext
                            $token = Get-AzAccessToken -TenantId $($subscription.TenantId)
    
                        }


            set-azcontext -Subscription $($subscriptionselected.name) 


 
            function BuildBody
            (
                [parameter(mandatory=$True)]
                [string]$method
            )
            {
                $BuildBody = @{
                Headers = @{
                    Authorization = "Bearer $($token.token)"
                    'Content-Type' = 'application/json'
                }
                Method = $Method
                UseBasicParsing = $true
                }
                $BuildBody
            }  
 
               $body = BuildBody GET


            $recoveryservicesvaults = Get-AzRecoveryServicesVault

            $vaultselected = $recoveryservicesvaults | ogv -Title " Select recovery services vault to use :" -PassThru | select *

             foreach ($vault in $vaultselected)
             {
 

            $vault = Get-AzRecoveryServicesVault -ResourceGroupName $($vault.ResourceGroupName) -Name $($vault.Name) 

            Set-AzRecoveryServicesVaultContext -Vault $vault 
 
  



                $requesturi = "https://management.azure.com/Subscriptions/$($subscription.id)/resourceGroups/$($vault.ResourceGroupName)/providers/Microsoft.RecoveryServices/vaults/$($vault.Name)/usages?api-version=2023-04-01"

                     $response = Invoke-RestMethod -Uri $requestUri -Headers ($body.Headers)  -Method GET -ErrorAction silentlycontinue
                     #$response.value | fl *


                    # Output the response
                     $($response.value).GetEnumerator() | where-object {$($_.bytes).value -ne 0 }| ForEach-Object {


                         if($($_.currentvalue) -ne 0  )
                         {
                    
                           WRITE-HOST " $($_.unit) : $($_.currentvalue) : $($_.name.value)"
                           if($_.unit -eq 'Bytes')
                           {
                            $sizelabel = 'Size in GB'
                            $size = $($_.currentvalue) /1024 /1024 /1024
                            }
                            else
                            {
                                $sizelabel = "$($_.unit)"
                                $size = $($_.currentvalue)
                            }

                            $vaultobj = new-object PSObject 


                            $vaultobj | add-member -MemberType NoteProperty -Name Subscriptionname -value  $($subcription.name)
                            $vaultobj | add-member -MemberType NoteProperty -Name Vaultname -value  $($vault.Name)
                            $vaultobj | add-member -MemberType NoteProperty -Name Resourcegroupname -value $($vault.ResourceGroupName)                             
                            $vaultobj | add-member -MemberType NoteProperty -Name Vaultitem -Value $($_.name.value)
                            $vaultobj | add-member -MemberType NoteProperty -Name Unit -value $($_.unit) 
                            $vaultobj | add-member -MemberType NoteProperty -Name Size  -Value $size
                            $vaultobj | add-member -MemberType NoteProperty -Name Note  -Value $sizelabel 
                [array]$vaultinfo  += $vaultobj 

                         }

                     }


            }



}



 $date = $(Get-Date -Format 'dd MMMM yyyy' )
 
    $CSS = @"
<Title> Azure Recovery services Storage Report: $date </Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	border-top: 1px solid #C1DAD7;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #6D929B;
}
</Style>
"@


 

 
$AZrecoverystorage_report = ($vaultinfo    | Select  Subscriptionname, Vaultname , Resourcegroupname ,Vaultitem  ,Unit,`
size, note|`   
ConvertTo-Html -Head $CSS )  | out-file "c:\temp\AZrecoverystorage_report.html" 

invoke-item "c:\temp\AZrecoverystorage_report.html" 



#####################################################################################






