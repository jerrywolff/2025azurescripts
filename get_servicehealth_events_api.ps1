 

# Connect to your cloud service account
$azcontext = Connect-AzAccount -identity

$subscriptioninfo = Get-AzSubscription -SubscriptionName 'contosolordsub'

$service_events = @()

$startDate = (Get-Date).AddMonths(-10).ToString('MM/dd/yyyy')

$servichealthapi = "https://management.azure.com/providers/Microsoft.ResourceHealth/events?api-version=2024-02-01&queryStartTime=$startDate"

# Get an access token for the API call
$accessToken = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com').Token

# Define the headers for the API call
$headers = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer $accessToken"
}

# Call the API and get the response
$response = Invoke-RestMethod -Method GET -Uri $servichealthapi -Headers $headers

# Output the cost data
$results = $response.value.properties

# Display the results
$results

foreach ($event in $results) {
    $descriptions = ($event.description) -replace "<.*?>", ""
 
    $summary = ($event.summary) -replace "<.*?>", ""

    foreach($impact in $($event.impact))
    {
 
    $eventobj = New-Object PSObject

    $eventobj | Add-Member -MemberType NoteProperty -Name Eventtype -Value $($event.eventtype)
    $eventobj | Add-Member -MemberType NoteProperty -Name Status -Value $($event.status)
    $eventobj | Add-Member -MemberType NoteProperty -Name Description -Value "$descriptions"
    $eventobj | Add-Member -MemberType NoteProperty -Name TrackingId -Value $($event.externalIncidentId)
    $eventobj | Add-Member -MemberType NoteProperty -Name Summary -Value "$summary"
    $eventobj | Add-Member -MemberType NoteProperty -Name Priority -Value $($event.priority)
    $eventobj | Add-Member -MemberType NoteProperty -Name ImpactStartTime -Value $($event.impactStartTime)
    $eventobj | Add-Member -MemberType NoteProperty -Name ImpactMitigationTime -Value $($event.impactMitigationTime)
    $eventobj | Add-Member -MemberType NoteProperty -Name impactedresources -Value "$($impact.impactedService) - $($impact.impactedRegions) - $($impact.impactedServiceGuid)"
    $service_events += $eventobj
    }
}

$service_events

  




$CSS = @"

<Title>Azure service health events : $(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Azure service health events : $(Get-Date -Format 'dd MMMM yyyy')  </H2>

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




( $service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime, impactedresources `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\servicehealth_events.html"


invoke-item "c:\temp\servicehealth_events.html"
###################
 



#######################################################################
####  For storage account archiving 

$Region = "westus"

 $subscriptionselected = 'contosolordsub'
  

 $resultsfilename = 'servicehealth_events.csv'


$service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime, impactedresources `
 | export-csv $resultsfilename -NoTypeInformation




$Region = "West US"
$subscriptionselected = 'contosolordSub'
$resourcegroupname = 'wolffautomationrg'
$storageaccountname = 'wolffautosa'
$storagecontainer = 'servicehealthevents'

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)

## un block storage 
# Enable Allow Storage Account Key Access
$scope = "/subscriptions/$($subscriptioninfo.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Storage/storageAccounts/$storageaccountname"

 
 

Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -AllowSharedKeyAccess $true  -force

 $destContext = New-AzStorageContext -StorageAccountName "$storageaccountname" -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName "$resourcegroupname" -Name $storageaccountname).Value | select -first 1)


#BEGIN Create Storage Accounts
  
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
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
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
        
 
 
 









