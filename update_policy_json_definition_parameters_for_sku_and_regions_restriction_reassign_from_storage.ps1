 
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

    Script Name: update_policy_json_definition_parameters_for_sku_and_regions_restriction_reassign_from_storage.ps1

    Description: 

    summary of the PowerShell script:

        Setup and Initialization:
        Suppresses Azure PowerShell breaking change warnings.
        Connects to Azure using connect-azaccount -identity.
        Sets up variables for subscription, resource group, storage account, and containers.
        Set Azure Context:
        Sets the Azure context to the specified subscription and tenant.
        Prompts the user to select regions to block using Out-GridView.
        Storage Account and Containers:
        Retrieves the storage account key and creates a storage context.
        Checks if the restrictedskus.csv file exists in the policyupdates container.
        If it exists, downloads the file and imports its content into $blockedSkuList.
        Build Policy:
        Defines policy parameters and rules to restrict specific SKUs in selected regions.
        Converts the policy definition to JSON and outputs it for debugging.
        Creates a new policy definition named “RestrictSpecificSKUs”.
        Update and Apply Policy:
        Writes the updated policy definition to a JSON file.
        Uploads the updated policy file to the historycontainer.
        Retrieves the existing policy definition and its properties.
        Removes any old policy assignments and reassigns the updated policy to the subscription.
        Validation and Reassignment:
        Validates the policy definition and its parameters.
        Reassigns the policy definition to the subscription with updated parameters.
        This script automates the process of managing and applying Azure policies to restrict specific SKUs in selected regions.
#>

#requiredversion 5.1
   Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'
 
connect-azaccount -identity

 

################  Set up storage account and containers ################
$subscriptionselected = 'contosolordsub'
$resourcegroupname = 'jwgovernance'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'policydatasa'
$storagecontainer = 'policyupdates'
$historycontainer = 'policyhistory'
$region = 'eastus'
#################
 
 
# Set Azure context
Set-AzContext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId

# Get SKUs to block
# Get SKUs to block
$blockedregions = get-azlocation | Out-GridView -Title "Select Regions to block:" -PassThru | Select  displayname -first 1

# Get SKUs to block
$blockedSkuList  


######################## Storage account info for source files and history files

$currentrestrictedlistname = "restrictedskus.csv"



$StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $storageaccountname).value | select -first 1
$destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
                 -StorageAccountKey $StorageKey



if(get-AzStorageBlob -Blob $currentrestrictedlistname -Container $storagecontainer -Context $destContext -ErrorAction SilentlyContinue)
{

    $currentrestrictedlist = get-AzStorageBlob -Blob $currentrestrictedlistname -Container $storagecontainer -Context $destContext

 
      $currentrestrictedlistcontent = Get-AzStorageBlobContent -Blob $currentrestrictedlistname -Container $storagecontainer    -Context $destContext -Force


    $blockedSkuList = import-csv   "$env:SystemRoot\System32\$currentrestrictedlistname"
   

}
Else 
{
    write-warning "$currentrestrictedlistname list does not exist in $($destContext.BlobEndPoint)" -ErrorAction Stop

}

################################################################################ Build policy #########


if ($blockedSkuList.Count -lt 1) {
    Write-Warning "Nothing selected" -ErrorAction Stop
} else {
    # Define the policy parameters
    $policyParameters = @{
        "listofexcludedsks" = @{
            "type" = "Array"
            "metadata" = @{
                "displayName" = "Excluded SKU types"
                "description" = "Value of the SKU, such as Standard_Xasxxxx_vx"
            }
            "defaultValue" = $($blockedSkuList.name)
        }
        "region" = @{
            "type" = "Array"
            "metadata" = @{
                "displayName" = "Region"
                "description" = "The regions to apply the policy to."
            }
            "defaultValue" = @($blockedregions.DisplayName)
        }
    }

    # Define the policy rule
    $policyRule = @{
        "if" = @{
            "allOf" = @(
                @{
                    "field" = "type"
                    "in" = @("Microsoft.Compute/virtualMachines", "Microsoft.Compute/virtualMachineScaleSets")
                },
                @{
                    "field" = "Microsoft.Compute/virtualMachines/sku.name"
                    "in" = "[parameters('listofexcludedsks')]"
                },
                @{
                    "field" = "location"
                    "in" = "[parameters('region')]"
                }
            )
        }
        "then" = @{
            "effect" = "deny"
        }
    }

    # Define the policy definition
    $policyDefinition = @{
        "properties" = @{
            "displayName" = "Restrict Specific SKUs"
            "description" = "This policy restricts the creation of specific SKUs in specified regions."
            "policyRule" = $policyRule
            "parameters" = $policyParameters
            "metadata" = @{
                "category" = "Restrictions"
            }
        }
    }

    # Convert the policy definition to JSON
    $policyDefinitionJson = $policyDefinition | ConvertTo-Json -Depth 10

    # Output the JSON for debugging
    Write-Output "Policy Definition JSON:"
    Write-Output $policyDefinitionJson

    # Create the new policy definition
    New-AzPolicyDefinition -Name "RestrictSpecificSKUs" -Policy $policyDefinitionJson -Mode All

    Write-Output "Policy created successfully."
}


#######################################################


 $updatedpolicy = "updatedrestrictedskupolicy.json"

 
          $policyDefinitionJson  | out-file  $updatedpolicy

        ################################## Add raw content to Variable
 
 
     $date = get-date -Format 'yyyyMMddHHmmss'   

   
        ##################  Write updated parameters file to Storage account 

              Set-azStorageBlobContent -Container $historycontainer -Blob "$($updatedpolicy)$date"  -File "$($updatedpolicy)"  -Context $destContext -Force

 

        ############## Apply updates to Policy parameters and reapply to Definition
 

           $policytoassign = Get-AzPolicyDefinition -Name "RestrictSpecificSKUs" 

        

      ############## Test/ Validation Policy and values 


          $policydefinitionproperties = Get-AzPolicyDefinition -Name "RestrictSpecificSKUs" -SubscriptionId $subscriptioninfo.Id  
   
          $policydefinitionproperties
          $($policydefinitionproperties.metadata) | fl *

   
          write-host "$($policydefinitionproperties.metadata) " -ForegroundColor Green
          write-host "$($policydefinitionproperties.parameter.listofexcludedsks.displayName) " -ForegroundColor Green
          write-host "$($policydefinitionproperties.policyrule) " -ForegroundColor Green
         write-host "$($policydefinitionproperties.description) " -ForegroundColor Green

          $($policydefinitionproperties.parameter).listofexcludedsks.defaultvalue  




        #####################################  Reassign subscription to update policy
        ######### Remove old assignment on resource
        try
        {
        
        $PolicyAssignment = Get-AzPolicyAssignment  -PolicyDefinitionId $($policytoassign.id)
        Remove-AzPolicyAssignment -Id $PolicyAssignment.id  -ErrorAction SilentlyContinue

 
         ##################  Reassign Policydefinition
 
         $listofexcludedsks  = @{'listofexcludedsks'=$($policydefinitionproperties.parameter).listofexcludedsks.defaultvalue  }

         $assigntoscope =   New-AzPolicyAssignment -Name 'listofexcludedskusbyregion' -PolicyDefinition  $policytoassign  -PolicyParameterObject  $listofexcludedsks  -Scope  "/subscriptions/$($subscriptioninfo.Id)" -NonComplianceMessage @{Message="Stop making mistakes - I will find you"}
        
     }
     catch
     {
        Write-host " Policy: $($policydefinitionproperties.displayname)  not assigned yet to any level ******"  -ForegroundColor Black -BackgroundColor white
         

     }

################  Write json policy definition to history container

   Set-azStorageBlobContent -Container $storagecontainer -Blob "$restricteskuslist"  -File "$restricteskuslist"  -Context $destContext -Force






