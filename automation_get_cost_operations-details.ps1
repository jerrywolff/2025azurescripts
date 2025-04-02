  Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'
  
import-module -Name az.billing -force -ErrorAction SilentlyContinue

import-module -Name az.advisor -force -ErrorAction SilentlyContinue
import-module -name Az.Reservations -force  -ErrorAction SilentlyContinue
   
                 $null = connect-AzAccount #-id



# FUNCTIONS
# Build out the body for the GET / PUT request via REST API

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
 




###################################################################

# Function used to build numbers in selection tables for menus
function Add-IndexNumberToArray (
    [Parameter(Mandatory=$True)]
    [array]$array
    )
{
    for($i=0; $i -lt $array.Count; $i++) 
    { 
        Add-Member -InputObject $array[$i] -Name "#" -Value ($i+1) -MemberType NoteProperty 
    }
    $array
}


##################################################################################################



$usageresponse = ''
$costreport = ''
$response = ''
$token = ''
$today = get-date -format 'yyyyMM'
$today

$month = 1  
$numberofmonths = 5

$date = ((Get-Date).AddMonths(-$numberofmonths) )

$datestart = get-date($date) -Format 'yyyyMM'     
         


###############################################################################

    $subscriptions = get-azsubscription
      
   foreach($subcription in $subscriptions)

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

                $Start = (Get-Date).AddDays(-7) | Get-Date -Hour 0 -Minute 0 -Second 0 | Get-Date -Format "yyyy-MM-ddThh:mm:ssZ"
    
                $End = (Get-Date).AddDays(-1) | Get-Date -Hour 23 -Minute 59 -Second 59 | Get-Date -Format "yyyy-MM-ddThh:mm:ssZ"
    
                $body = BuildBody GET

          
        Set-AzContext -Subscription $($subcription.Name)
        
        $subscriptionname = $($subcription.name) 
 

           $tenantId = "$($subscription.TenantId)"
          # write-output "$token ***********"

         $billingScope = "$($subcription.id)"
         $billingScope
        $billingaccount = (((get-azbillingaccount).Id) -split('/'))[-1]
        $billingaccount
  
  
  
   # Set the request URI
    $start_request_uri = "https://management.azure.com/subscriptions/{subscription_id}/providers/Microsoft.CostManagement/generateCostDetailsReport?api-version=2023-11-01"
    $start_ops = Invoke-RestMethod -Method Post -Uri $start_request_uri -Body $body -Headers $headers | ConvertFrom-Json

    # Get results of cost operation
    $request_uri = "https://management.azure.com/subscriptions/{subscription_id}/providers/Microsoft.CostManagement/costDetailsOperationResults/{start_ops}?api-version=2023-11-01"

    # Send the request to the API
    $response = Invoke-RestMethod -Uri $requestUri -Headers ($body.Headers) -Method GET -ErrorAction silentlycontinue

    # Parse the response
    if ($response.StatusCode -eq 200) {
        $data = $response | ConvertFrom-Json
        $properties = $data.value.properties

        # Export data to a CSV file
        $csvFilePath = "$($subscription_name)_billingdata.csv"
        if (-not (Test-Path $csvFilePath)) {
            $properties.Keys | Export-Csv -Path $csvFilePath -NoTypeInformation
        }
        $properties | Export-Csv -Path $csvFilePath -NoTypeInformation -Append

        Write-Host "Data retrieved successfully and saved to $csvFilePath"
    } else {
        Write-Host "Error retrieving data. Status code: $($response.StatusCode)"
    }
}
  
################# storage subinfo #################################################

$Region = "west us"

$subscriptionselected = 'contosolordsub'


$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffautosa'



### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)


#BEGIN Create Storage Accounts

 ##########################usage

$storagecontainer = 'billingcostsapiresults'





 try
{
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose

     
        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  -StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  -StorageAccountName $storageaccountname `
                                        -StorageAccountKey $StorageKey


             #Upload user.csv to storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext
                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -force
  







  #############################usage recommendations #      
  
 
 $storagecontainer = 'usagedetails'



try
{
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose

     
        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  -StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  -StorageAccountName $storageaccountname `
                                        -StorageAccountKey $StorageKey


             #Upload user.csv to storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext
                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename1  -File $resultsfilename1 -Context $destContext -force
        

 
