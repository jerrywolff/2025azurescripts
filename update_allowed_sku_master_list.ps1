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

    Script Name: update_allowed_sku_master_list.ps1
    Description : 
    Setup and Initialization:
        Connects to Azure using connect-azaccount -identity.
        Imports necessary modules: az.storage and Az.Resources.
        Sets up variables for subscription, resource group, storage account, and containers.
        Collect allowed SKUs and Region:
        Sets the Azure context to the specified subscription and tenant.
        Prompts the user to select regions and SKUs to allowskus using Out-GridView.
        Retrieves the list of SKUs to allowskus based on the selected region.
        Setup Storage Account and Containers:
        Checks if the specified resource group exists; if not, it creates the resource group.
        Checks if the specified storage account exists; if not, it creates the storage account.
        Retrieves the storage account key and creates a storage context.
        Checks if the specified containers (policyupdates, policyhistory, policydata) exist; if not, it creates them.
        Manage allowed SKUs:
        Checks if the allowedskus.csv file exists in the policyupdates container.
        If it exists, downloads the file and imports its content.
        Writes a history file of the allowed SKUs to the policyhistory container.
        Updates the allowedskus.csv file with the new list of allowskused SKUs and uploads it to the policyupdates container.
        This script automates the process of managing allowed SKUs in Azure by setting
         up necessary resources, collecting data, and updating storage containers.
 #>



historycontainer
######  for Azure government tenant use  , run connect-azconnect -Environment AzureUSGovernment
cls
 


connect-azaccount -identity

import-module az.storage
import-module Az.Resources 

 
$subscriptionselected = 'contosolordsub'
$resourcegroupname = 'jwgovernance'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'policydatasa'
$storagecontainer = 'policyupdates'
$historycontainer = 'policyhistory'
$sourcecontainer = 'policydata'
$region = 'eastus'
$allowskuslist = 'allowed.csv'




################  Collect allowed sku list and region ################

 

# Set Azure context
Set-AzContext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId

# Get SKUs to allowskus
# Get SKUs to allowskus
$policyallowedregions = get-azlocation | Out-GridView -Title "Select Regions to allowskus:" -PassThru | Select-Object -ExpandProperty displayname -first 1

# Get SKUs to allowskus
$allowedskuslist = Get-AzComputeResourceSku -Location "$($policyallowedregions)" | where-object {$_.Resourcetype -like '*VirtualMachine*' -or $_.Resourcetype -like '*virtualMachineScaleSets*'} | Select-Object -Unique Name, ResourceType | Sort-Object ResourceType, Name | Out-GridView -Title "Select SKUs to allowskus:" -PassThru | Select Name

  
################  Set up storage account and containers ################




### end storagesub info

Set-azcontext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId

 ####resourcegroup 
 try
 {
     if (!(Get-azresourcegroup -Location "$region" -Name $resourcegroupname -erroraction "silentlycontinue" ) )
    {  
        Write-Host "resourcegroup Does Not Exist, Creating resourcegroup  : $resourcegroupname Now"

        # b. Provision resourcegroup
        New-azresourcegroup  -Name  $resourcegroupname -Location $region -Tag @{"owner" = "Ownername"; "purpose" = "Az Automation" } -Verbose -Force
 
       start-sleep 30
        Get-azresourcegroup    -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Resourcegroup   Aleady Exists, SKipping Creation of resourcegroupname"
   
   }

############ Storage Account
    
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname  -erroraction "silentlycontinue" ) )
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount  -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Ownername"; "purpose" = "Az Automation storage write" } -Verbose 
 
        start-sleep 30

        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
 
             #Upload user.json to storage account


  $date = get-date -Format 'yyyyMMddHHmmss'   


set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)



$StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $storageaccountname).value | select -first 1
$destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
                 -StorageAccountKey $StorageKey
if($destContext  )
{

##########  Containers  
        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext -erroraction silentlycontinue))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext

                         
                        start-sleep 30

                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }


         try
            {
                  if (!(get-azstoragecontainer -Name $historycontainer -Context $destContext -erroraction silentlycontinue))
                     { 
                         New-azStorageContainer $historycontainer -Context $destContext

                         
                        start-sleep 30

                        }
             }
        catch
             {
                Write-Warning " $historycontainer container already exists" 
             }

         try
            {
                  if (!(get-azstoragecontainer -Name $sourcecontainer -Context $destContext -erroraction silentlycontinue))
                     { 
                         New-azStorageContainer $sourcecontainer -Context $destContext

                         
                        start-sleep 30

                        }
             }
        catch
             {
                Write-Warning " $sourcecontainer container already exists" 
             }

}
else
{

    Write-Warning " $($destContext.StorageAccountName) connection not made" -ErrorAction stop


}


$currentallowedlistname = "allowedskus.csv"

if(get-AzStorageBlob -Blob $currentallowedlistname -Container $storagecontainer -Context $destContext -ErrorAction SilentlyContinue)
{

    $currentallowedlist = get-AzStorageBlob -Blob $currentallowedlistname -Container $storagecontainer -Context $destContext

 
      $currentallowedlistcontent = Get-AzStorageBlobContent -Blob $currentallowedlistname -Container $storagecontainer    -Context $destContext -Force


    $skulist = import-csv   "$env:SystemRoot\System32\$currentallowedlistname"
   

}
Else 
{
    write-warning "$currentallowedlistname list does not exist in $($destContext.BlobEndPoint)" -ErrorAction Stop

}



  ##################  Write history file for allowedskus to Storage account policyhistory container

  $date = get-date -Format 'yyyyMMddHHmmss'

  $allowedlisthistory = "allowskulist$date.csv"
  $skulist | select name | export-csv $allowedlisthistory -NoTypeInformation

   set-azStorageBlobContent -Container $historycontainer -Blob "$allowedlisthistory"  -File "$allowedlisthistory"  -Context $destContext -Force



#######################  Update with new list of allowed SKUS 

$allowskuslist = "allowedskus.csv" 


$allowedskuslist | select name  | export-csv $allowskuslist -NoTypeInformation


        ##################  Write updated parameters file to Storage account 

       Set-azStorageBlobContent -Container $storagecontainer -Blob "$allowskuslist"  -File "$allowskuslist"  -Context $destContext -Force




























