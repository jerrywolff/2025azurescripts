<#
.NOTES

    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 

    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 

    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 

    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all

    implied warranties including, without limitation, any implied warranties of merchantability

    or of fitness for a particular purpose. The entire risk arising out of the use or performance

    of the sample and documentation remains with you. In no event shall Microsoft, its authors,

    or anyone else involved in the creation, production, or delivery of the script be liable for 

    any damages whatsoever (including, without limitation, damages for loss of business profits, 

    business interruption, loss of business information, or other pecuniary loss) arising out of 

    the use of or inability to use the sample or documentation, even if Microsoft has been advised 

    of the possibility of such damages, rising out of the use of or inability to use the sample script, 

    even if Microsoft has been advised of the possibility of such damages.

Description: 
The script connects to your Azure account, retrieves SKU restrictions for virtual machines across 
specified regions and subscriptions, generates an HTML report, exports the results to a CSV file, 
and uploads the CSV to a specified storage account. The purpose is to identify and document SKU restrictions 
for virtual machines in different Azure regions and store the results for further analysis. 
Variables marked with < > need to be changed to match your environment.

Permissions: 

To run the PowerShell script for managing Azure resources, 
you need specific Azure Role-Based Access Control (RBAC) permissions. Here are the required permissions:

**Microsoft.Authorization/roleAssignments/write: This permission is necessary 
to assign roles. It is typically included in roles such as Role Based Access Control
 Administrator, User Access Administrator, Owner, or Global Administrator1.

**Microsoft Graph Directory.Read.All: The account used to run the PowerShell command 
must have this permission to read directory data1.

**Contributor Role: This role provides full access to manage all Azure resources but
 does not allow you to grant access to others2.

**Storage Account Contributor: This role is required to manage storage accounts, 
including creating and deleting storage accounts, and managing access keys2.

**Reader Role: This role allows you to view all resources but not make any changes2.

#>

 $MaximumVariableCount = 8192
 $MaximumFunctionCount = 8192
  
   
  
  'Az.Accounts','Az.Resources','Az.Compute','az', 'Az.Storage' | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
         update-module $_ -force
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
        install-module -name $_ -allowclobber
        import-module -name $_ -force
    }
   #  Get-InstalledModule
}
  


# Connect to your Azure account
Connect-AzAccount -identity

# Specify the region you want to check (e.g., eastus)
 
$skurestrictions = ''
$subscriptions = get-azsubscription  | ogv -title " Select a Subscriptions to check : " -PassThru | select name, id

 $Regions = get-azlocation  | ogv -title " Select a region to check : " -PassThru | select location

foreach($sub in $subscriptions)
{
    set-azcontext -Subscription $($sub.name) 



        foreach($Region in $Regions)
        {
            # Get available SKUs for virtual machines in the specified region
            $vmSkus = Get-AzComputeResourceSku -Location $($region.location)   
 
    
            foreach($Skufamily in $vmskus)
            {
                if($($skufamily.Restrictions.reasoncode) -like '*NotAvailableForSubscription*')
                {

                $reasoncode =  'Not Available For Subscription'
                }
                else
                {
                 $reasoncode =   $($skufamily.Restrictions.reasoncode)

                }


                $skufamilyobj = new-object PSObject
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Name -value $($skufamily.name)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Family -value $($skufamily.Family)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name ResourceType -value $($skufamily.ResourceType)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Location -value $($skufamily.Locations)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Tier -value $($skufamily.Tier)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name ReasonCode -value "$reasoncode"
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Subscription -value $($sub.name)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name "RestrictionInfo" -value "$($skufamily.RestrictionInfo)" 
 

                [array]$skurestrictions += $skufamilyobj
            }
        }

}

$skurestrictions





$CSS = @"

<Title>Azure sku family restrictions : $(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Azure sku family restrictions : $(Get-Date -Format 'dd MMMM yyyy')  </H2>

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




($skurestrictions | select name ,Family,ResourceType,Tier, ReasonCode, Subscription, RestrictionInfo  ,Location `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\allSkus.html"


invoke-item "c:\temp\allSkus.html"
###################
## exceptions only

($skurestrictions | where ReasonCode -ne '' | select name ,Family,ResourceType,Tier, ReasonCode, Subscription, RestrictionInfo  ,Location `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\restrictedSkus.html"


invoke-item "c:\temp\restrictedSkus.html"




#######################################################################
####  For storage account archiving 

$Region = "<localtion/region>"

 $subscriptionselected = '<subscription for storage account to save to>'





 $resultsfilename = 'restrictedskus.csv'


$skurestrictions | select name ,Family,ResourceType,Tier, ReasonCode, Subscription, RestrictionInfo  ,Location  `
 | export-csv $resultsfilename 




$resourcegroupname = '<Storage account resourcegroup>'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = '<Storageaccount name>'
$storagecontainer = 'restrictedskus'
### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)


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
        
 
 
 









