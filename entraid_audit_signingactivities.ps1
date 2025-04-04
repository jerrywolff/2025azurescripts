
Import-Module Microsoft.Graph.Identity.DirectoryManagement

  Connect-MgGraph  
#Get-MgAuditLogDirectoryAudit | fl *
$signinreport = ''
$signinlogs = Get-MgAuditLogSignIn -Property *
 

 foreach($signin in $signinlogs)
 {

  $($signin.Status).AdditionalDetails #| Fl *
 $($signin.Status).AdditionalProperties  # | Fl *


    $signinobj = new-object Psobject 

    $signinobj | add-member -membertype Noteproperty -name AppDisplayName  -value $($signin.AppDisplayName)
    $signinobj | add-member -membertype Noteproperty -name AppId  -value $($signin.AppId)
    $signinobj | add-member -membertype Noteproperty -name AppliedConditionalAccessPolicies  -value $($signin.AppliedConditionalAccessPolicies).DisplayName
    $signinobj | add-member -membertype Noteproperty -name ClientAppUsed  -value $($signin.ClientAppUsed)
    $signinobj | add-member -membertype Noteproperty -name ConditionalAccessStatus  -value $($signin.ConditionalAccessStatus)
    $signinobj | add-member -membertype Noteproperty -name CorrelationId  -value $($signin.CorrelationId)
    $signinobj | add-member -membertype Noteproperty -name CreatedDateTime  -value $($signin.CreatedDateTime)
    $signinobj | add-member -membertype Noteproperty -name DeviceID  -value $($signin.DeviceDetail).DeviceId
    $signinobj | add-member -membertype Noteproperty -name Devicename  -value $($signin.DeviceDetail).DisplayName
    $signinobj | add-member -membertype Noteproperty -name DeviceCompliant  -value $($signin.DeviceDetail).IsCompliant
    $signinobj | add-member -membertype Noteproperty -name DeviceManaged  -value $($signin.DeviceDetail).IsManaged
    $signinobj | add-member -membertype Noteproperty -name DeviceOS  -value $($signin.DeviceDetail).OperatingSystem
    $signinobj | add-member -membertype Noteproperty -name DeviceTrustType  -value $($signin.DeviceDetail).TrustType
    $signinobj | add-member -membertype Noteproperty -name IPAddress  -value $($signin.IPAddress)
    $signinobj | add-member -membertype Noteproperty -name Id  -value $($signin.Id)
    $signinobj | add-member -membertype Noteproperty -name IsInteractive  -value $($signin.IsInteractive)
    $signinobj | add-member -membertype Noteproperty -name Location  -value $($signin.Location).City
    $signinobj | add-member -membertype Noteproperty -name State  -value $($signin.Location).State
    $signinobj | add-member -membertype Noteproperty -name ResourceDisplayName  -value $($signin.ResourceDisplayName)
    $signinobj | add-member -membertype Noteproperty -name ResourceId  -value $($signin.ResourceId)
    $signinobj | add-member -membertype Noteproperty -name RiskDetail  -value $($signin.RiskDetail)
    $signinobj | add-member -membertype Noteproperty -name RiskEventTypes  -value $($signin.RiskEventTypes)
    $signinobj | add-member -membertype Noteproperty -name RiskEventTypesV2  -value $($signin.RiskEventTypesV2)
    $signinobj | add-member -membertype Noteproperty -name RiskLevelAggregated  -value $($signin.RiskLevelAggregated)
    $signinobj | add-member -membertype Noteproperty -name RiskLevelDuringSignIn  -value $($signin.RiskLevelDuringSignIn)
    $signinobj | add-member -membertype Noteproperty -name RiskState  -value $($signin.RiskState)
    $signinobj | add-member -membertype Noteproperty -name Status  -value   $($signin.Status).AdditionalDetails
    $signinobj | add-member -membertype Noteproperty -name UserDisplayName  -value $($signin.UserDisplayName)
    $signinobj | add-member -membertype Noteproperty -name UserId  -value $($signin.UserId)
    $signinobj | add-member -membertype Noteproperty -name UserPrincipalName  -value $($signin.UserPrincipalName)
    $signinobj | add-member -membertype Noteproperty -name AdditionalProperties  -value $($signin.Status).AdditionalProperties

    [array]$signinreport += $signinobj

    
 } 





 ###GENERATE HTML Output for review        
 
    $CSS = @" 
  EntraId signin Audit $date
<Title> Azure Role Audit $date Report: $date </Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #4B0082;
	border-bottom: 1px solid #4B0082;
	border-top: 1px solid #4B0082;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #4B0082;
	border-bottom: 1px solid #4B0082;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #4B0082;
}
</Style>
"@


 

 

 ((($signinreport| SELECT  `
AppDisplayName,`
AppId,`
AppliedConditionalAccessPolicies,`
ClientAppUsed,`
ConditionalAccessStatus,`
CorrelationId,`
CreatedDateTime,`
DeviceID,`
Devicename,`
DeviceCompliant,`
DeviceManaged,`
DeviceOS,`
DeviceTrustType,`
IPAddress,`
Id,`
IsInteractive,`
Location,`
State,`
ResourceDisplayName,`
ResourceId,`
RiskDetail,`
RiskEventTypes,`
RiskEventTypesV2,`
RiskLevelAggregated,`
RiskLevelDuringSignIn,`
RiskState,`
Status,`
UserDisplayName,`
UserId,`
UserPrincipalName | `
ConvertTo-Html -Head $CSS ).replace("root","<font color=red>root</font>")).replace("subscriptions","<font color=green>subscriptions</font>"))| out-file "C:\TEMP\EntraId_signin_audit.html"
Invoke-Item    "C:\TEMP\EntraId_signin_audit.html"                                                                                                     


######## Prep for export to storage account

$resultsfilename = 'entraidsigninlogs.csv'

$deviceownership =  $signinreport| SELECT   `
AppDisplayName,`
AppId,`
AppliedConditionalAccessPolicies,`
ClientAppUsed,`
ConditionalAccessStatus,`
CorrelationId,`
CreatedDateTime,`
DeviceID,`
Devicename,`
DeviceCompliant,`
DeviceManaged,`
DeviceOS,`
DeviceTrustType,`
IPAddress,`
Id,`
IsInteractive,`
Location,`
State, `
ResourceDisplayName,`
ResourceId,`
RiskDetail,`
RiskEventTypes,`
RiskEventTypesV2,`
RiskLevelAggregated,`
RiskLevelDuringSignIn,`
RiskState,`
Status,`
UserDisplayName,`
UserId,`
UserPrincipalName | export-csv  $resultsfilename  -notypeinformation




 ##### storage sub info and creation

#connect-azaccount ## only uncomment if using a storage account under another tenant or account for consilidation of reports 


 ########################################################################################################################
 ###

 #### Change subscription , Region, Resourcegroupname, Storageaccountname below 

$Region =  "West US"   ## pick storage account region 

 $subscriptionselected = 'contosoentpSub'   ### designated storage account subscription if different from current running subscription



$resourcegroupname = 'contosoautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'contosoautosa'    ## dedicate storage account
$storagecontainer = 'entrasignins'   ### Container for export


### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)

 

#BEGIN Create Storage Accounts
 
 
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry contoso"; "purpose" = "Az Automation storage write" } -Verbose
 
     
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


             #Upload  .csv to storage account

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
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -Force

















