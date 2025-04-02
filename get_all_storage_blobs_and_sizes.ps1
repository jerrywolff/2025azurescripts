 <#
.SYNOPSIS  
 Wrapper script for Azure storage inventory
.DESCRIPTION  
 Wrapper script for Azure storage inventory to html report
.EXAMPLE  
.\automation_get_azure_block_and _page_blob_storage_inventory.ps1
Version History  
v1.0   - Initial Release  
 

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

#> 

### uncomment when using for AAzure Automation
 connect-azaccount   -Identity
<#
try
{ 

    "Logging in to Azure..." 

$identity = Get-AzUserAssignedIdentity -ResourceGroupName wolffautorg -Name wolffautomationMI
Connect-AzAccount -Identity -AccountId $identity.ClientId 
} 
catch { 
    Write-Error -Message $_.Exception 
    throw $_.Exception 
} 

#>

###########
import-module az.storage -force

      $AZStoragelist =''  
             $subscriptionlist =  Get-AZSubscription |select  name, ID 

    foreach($Subscription  in $subscriptionlist)
    {

             $SubscriptionName =  $Subscription.name
             
             $SubscriptionID =  $Subscription.ID 

            set-AZcontext -SubscriptionName  $SubscriptionName

             write-host "$SubscriptionName" -foregroundcolor yellow

            #Get-Command -Module Azure -Noun *Storage*`


             $SubscriptionName 
             $storageaccounts = Get-AZStorageAccount | select StorageAccountName, context, PrimaryEndpoints,AccountType, ProvisioningState ,PrimaryLocation ,Resourcegroupname ,Tags


                foreach($storageaccount in $storageaccounts)
                {    
                
                    Set-AZContext -SubscriptionName $SubscriptionName 
 
                            $StorageAccountName = $storageaccount.StorageAccountName
                            $storageaccountrg = $storageaccount.resourcegroupname
                              

                              Set-AzStorageAccount -ResourceGroupName $storageaccountrg -Name $StorageAccountName   -AllowSharedKeyAccess $true  -force


                              
                               $stgkey =  (Get-AZStorageAccountKey -Name $StorageAccountName -ResourceGroupName $storageaccountrg -erroraction silentlycontinue)
  
                      
                               # $stgkey.value
                                $storageacctkeyprimary = ($stgkey.value ) | select -First 1
                                $storageacctkeySecondary = ($stgkey.value ) | select -skip 1  
                                $storageacctkeyStorageAccountName = $StorageAccountName
 
 

                              $storageaccountendpoints = $storageaccount.PrimaryEndpoints
                              $storageaccountlocation = $storageaccount.PrimaryLocation
                              $storageaccount_type =  $storageaccount.AccountType
                              $storeageaccountstatus = $storageaccount.StatusOfPrimary
                    
                               # $ctx = $storageaccount.context
                                $ctx = New-AZStorageContext -StorageAccountName  $StorageAccountName -StorageAccountKey $storageacctkeyprimary 
                               $containers = Get-AzStorageContainer  -context $ctx




                               foreach($containeritem in $containers)
                              {
                                   # Get-AZStorageBlob -Context  $ctx  -Container $containeritem.Name

                                    $containername = $containeritem.name  

                                    #List the snapshots of a blob.
$blobs = Get-AzStorageBlob -Context $Ctx -Container $ContainerName | where length -gt 0 | Sort-Object length -desc
$blobresource = get-azresource -Name $ContainerName




foreach ($blob in $blobs) {
    $BlobType = $blob.BlobType
    $blobname = $blob.Name
    $blobcontenttype = $blob.ContentType
    $bloblastmodified = $blob.LastModified
    $blobcontext = $blob.Context
    $blobICloudBlob = $blob.ICloudBlob.Name
    $blobSize = $blob.Length

    # Get the blob tags
    $blobTags = Get-AzStorageBlobTag -Context $Ctx -Container $ContainerName -Blob $blobname

    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name "subscriptioname" -Value "$SubscriptionName"
    $obj | Add-Member -MemberType NoteProperty -Name "storageaccountname" -Value "$storageaccountname"
    $obj | Add-Member -MemberType NoteProperty -Name "storageaccountendpoints" -Value "$storageaccountendpoints"
    $obj | Add-Member -MemberType NoteProperty -Name "storageaccountlocation" -Value "$storageaccountlocation"
    $obj | Add-Member -MemberType NoteProperty -Name "storageaccount_type" -Value "$storageaccount_type"
    $obj | Add-Member -MemberType NoteProperty -Name "storageaccountstatus" -Value "$storageaccountstatus"
    $obj | Add-Member -MemberType NoteProperty -Name "storageacctkeyStorageAccountName" -Value "$storageacctkeyStorageAccountName"
    $obj | Add-Member -MemberType NoteProperty -Name "containername" -Value "$containername"
    $obj | Add-Member -MemberType NoteProperty -Name "BlobType" -Value "$BlobType"
    $obj | Add-Member -MemberType NoteProperty -Name "blobname" -Value "$blobname"
    $obj | Add-Member -MemberType NoteProperty -Name "blobcontenttype" -Value "$blobcontenttype"
    $obj | Add-Member -MemberType NoteProperty -Name "bloblastmodified" -Value "$bloblastmodified"
    $obj | Add-Member -MemberType NoteProperty -Name "blobcontext" -Value "$blobcontext"
    $obj | Add-Member -MemberType NoteProperty -Name "blobICloudBlob" -Value "$blobICloudBlob"
    $obj | Add-Member -MemberType NoteProperty -Name "blobSize" -Value $blobSize

    # Add blob tags to the object
     ($storageaccount.Tags).GetEnumerator() | foreach-object {
        $obj | Add-Member -MemberType NoteProperty -Name "$($_.Key)" -Value "$($_.Value)"
        $tag
    }

             [array]$AZStoragelist += $obj
        }
                }

        }

    }

 $date = $(Get-Date -Format 'dd MMMM yyyy' )
 
########### Prepare for storage account export

$csvresults = $AZStoragelist| Select subscriptioname,  storageaccountname, storageaccountendpoints, storageaccountlocation, storageaccount_type , storageaccountstatus, storageacctkeyStorageAccountName, containername,BlobType,blobname,blobcontenttype, bloblastmodified,blobcontext,blobICloudBlob,blobSize,owner,purpose

 $AZStoragelist| Select subscriptioname,  storageaccountname, storageaccountendpoints, storageaccountlocation, storageaccount_type ,`
  storageaccountstatus, storageacctkeyStorageAccountName, containername,BlobType,blobname,blobcontenttype, bloblastmodified,`
  blobcontext,blobICloudBlob,blobSize,owner,purpose | export-Csv  c:\temp\allstorageblobs.csv -NoTypeInformation


 $resultsfilename = "storageBlobs.csv"

$csvresults  | export-csv $resultsfilename  -NoTypeInformation   

# end vmss data 


##### storage subinfo

$Region = "West US"
 $date = Get-Date -Format MMddyyyy
 $subscriptionselected = 'wolffentpSub'



$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | select tenantid
$storageaccountname = 'wolffautosa'
$storagecontainer = 'allstorageblobs'
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
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfile  -File $resultsfilename -Context $destContext
        
        
 
 
     
 
 
 
 







