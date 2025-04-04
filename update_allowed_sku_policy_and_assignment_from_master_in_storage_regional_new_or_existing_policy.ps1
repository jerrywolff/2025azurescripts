 
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

    Script Name: update_allowed_sku_policy_and_assignment_from_master_in_storage_regional.ps1

    Description: 

    summary of the PowerShell script:

 Description: 
This PowerShell script is designed to manage Azure Policy definitions and assignments, specifically focusing on 
allowed SKUs for virtual machines and regions. The script performs the following key functions:

Environment Setup:
    Suppresses Azure PowerShell breaking change warnings.
    Connects to Azure using a managed identity.
    Storage Account and Container Setup:
    Selects the subscription and resource group.
    Retrieves subscription and tenant information.
    Defines storage account and container names for storing policy data and history.
    Azure Context Setup:
    Sets the Azure context to the selected subscription and tenant.
    Retrieve Allowed SKUs and Regions:
    Prompts the user to select regions to block using an interactive grid view.
    Retrieves the list of allowed SKUs from a CSV file stored in a specified storage container.
    Policy Definition:
    Checks if the allowed SKUs list is not empty.
    Defines policy parameters for allowed SKUs and regions.
    Constructs the policy rule to audit virtual machines and scale sets that do not match the allowed SKUs in the specified regions.
    Converts the policy definition to JSON and creates a new policy definition in Azure.
    Policy Assignment:
    Writes the updated policy definition to a JSON file and uploads it to the storage account.
    Retrieves the existing policy assignment and removes it if it exists.
    Reassigns the policy definition with the updated parameters to the subscription.
    Logging and Error Handling:
    Outputs the policy definition JSON for debugging.
    Handles errors and outputs relevant messages to the console.

    This script ensures that only specified SKUs are allowed in the selected regions and maintains a history of
     policy updates in a storage account, providing a robust mechanism for managing Azure Policy compliance.

#>

#requiredversion 5.1
   Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'
 
connect-azaccount  -WarningAction SilentlyContinue # -identity


##############################################
 


################  Set up storage account and containers ################
$subscriptionselected = 'contosolordsub'
$resourcegroupname = 'jwgovernance'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'policydatasa'
$storagecontainer = 'policyupdates'
$historycontainer = 'policyhistory'
$skumasters = 'skumasterssa'
$region = 'eastus'    ########  $region is for storage account only change if repo storage account is in a diferent region 
#################
 
 
# Set Azure context
$azcontext = Set-AzContext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId


######################## Storage account info for source files and history files


## un block storage 
# Enable Allow Storage Account Key Access
$scope = "/subscriptions/$($subscriptioninfo.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Storage/storageAccounts/$storageaccountname"

$servicePrincipal = Get-AzADServicePrincipal -DisplayName "$($azcontext.Account)"

# Display the service principal's Object ID
$servicePrincipal.Id

 

Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -AllowSharedKeyAccess $true  -force

 $destContext = New-AzStorageContext -StorageAccountName "$storageaccountname" -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName "$resourcegroupname" -Name $storageaccountname).Value | select -first 1)

 
 #############################################


#############  look at exising policy definitions and select one is to be modified - click cancle to create new policy 
$existingpolicies = ''

$existing_policy_defs = Get-AzPolicyDefinition 

$($existing_policy_defs) | where policytype -eq 'Custom' | Fl * 

 
 


$custompolicies = $($existing_policy_defs) | where-object {  ($($existing_policy_defs) | where policytype -eq 'Custom') }  


foreach($custompolicy in $custompolicies)
{
    if($($custompolicy.metadata.category) -eq 'allowonlyskus')
    {
        $policydefinitionproperties = Get-AzPolicyDefinition | where Displayname -eq  "$($custompolicy.displayname)" | ConvertTo-Json -Depth 10

            $custompolobj = new-object PSObject 

                    $custompolobj | Add-member -MemberType NoteProperty -name Displayname -Value $($custompolicy.displayname)
                    $custompolobj | Add-member -MemberType NoteProperty -name category -Value $($custompolicy.metadata.category)
                    $custompolobj | Add-member -MemberType NoteProperty -name policytype -Value $($custompolicy.policytype)
                    $custompolobj | Add-member -MemberType NoteProperty -name policyrule -Value "$($policydefinitionproperties)"
 
            [array]$existingpolicies += $custompolobj
            }
       

}
 

$existingpolicies | select Displayname, category, policytype, policyrule | export-csv c:\temp\custompolicies.csv -NoTypeInformation



$custompolicies  = $existingpolicies | select Displayname, policytype, category

$policytomodify = $custompolicies | ogv -Title " Select policy to modify or cancel to create new***:" -PassThru | Select Displayname, category, policytype

if($policytomodify -eq $null)
{

 ############### modify to be able to generate new sku master list with custom name ***********************************************
$Allowedpolicyname = read-host " Enter a custom name for this policy to manage Allowed Skus :" 

$Allowedpolicyname = $Allowedpolicyname -replace ('\s+', '')

write-host "$Allowedpolicyname is the new policy name for this selection set" -ForegroundColor blue -BackgroundColor white

}
else
{

    $Allowedpolicyname = $($policytomodify.displayname) -replace ('\s+', '')

write-host "$Allowedpolicyname is the new policy name for this selection set" -ForegroundColor blue -BackgroundColor white




}


######################################################
# Get SKUs to allow
$policyallowedregions = get-azlocation | Out-GridView -Title "Select Regions to allow:" -PassThru | Select  displayname 

   

# Get SKUs to block

#####################################  get existing sku list to select or skip to create new 

$skuallowedfiles = get-AzStorageBlob   -Container $skumasters -Context $destContext | ogv -Title " here is a list of existing Slu allowed lists - if the desired list is not present run update_allowed_sku_master_list tool " -passthru | Select * -First 1  

 $skuallowedfiles


 
$currentallowedlistname = "$($skuallowedfiles.name)"

 
 if(get-AzStorageBlob -Blob  $($skuallowedfiles.name) -Container $storagecontainer -Context $destContext -ErrorAction SilentlyContinue)
{

    $currentallowedlist = get-AzStorageBlob -Blob  $($skuallowedfiles.name) -Container $storagecontainer -Context $destContext

 
      $currentallowedlistcontent = Get-AzStorageBlobContent -Blob  $($skuallowedfiles.name) -Container $storagecontainer    -Context $destContext -Force


    $allowedskuslist = import-csv   "$env:SystemRoot\System32\$currentallowedlistname"
   

}
Else 
{
    write-warning "$currentallowedlistname list does not exist in $($destContext.BlobEndPoint)" -ErrorAction Stop

}

 


if ($allowedskuslist.Count -lt 1) {
    Write-Warning "Nothing selected" -ErrorAction Stop
} else {

# Define the policy parameters
$policyParameters = @{
    "listofallowedskus" = @{
        "type" = "Array"
        "metadata" = @{
            "displayName" = "$Allowedpolicyname"
            "description" = "Value of the SKU, such as Standard_Xasxxxx_vx"
        }
        "defaultValue" = $($allowedskuslist.name)
    }
    "listOfAllowedLocations" = @{
        "type" = "Array"
        "metadata" = @{
            "displayName" = "Allowed locations"
            "description" = "The regions to apply the policy to."
        }
        "defaultValue" = @($policyallowedregions.DisplayName)
    }
}

# Define the policy rule



$policyRule = @{
    "if" = @{
        "allOf" = @(
            @{
                "field" = "Microsoft.Compute/virtualMachines/sku.name"
                "notIn" = "[parameters('listofallowedskus')]"
            },
            @{
                "field" = "location"
                "in" = "[parameters('listOfAllowedLocations')]"
            }
        )
    }
    "then" = @{
        "effect" = "audit"
    }
}

   # Define the policy definition
   ####  Review the category and make sure there is no typo  ******************
   ##### need to make displayname reflect name derived by action/update actor  ****************************


    $policyDefinition = @{
        "properties" = @{
            "displayName" = "$Allowedpolicyname"
            "description" = "This policy allow only  the creation of specific SKUs."
            "policyRule" = $policyRule
            "parameters" = $policyParameters
            "metadata" = @{
                "category" = "allowonlyskus"
            }
        }
    }

    # Convert the policy definition to JSON
    $policyDefinitionJson = $policyDefinition | ConvertTo-Json -Depth 10

    # Output the JSON for debugging
    Write-Output "Policy Definition JSON:"
    Write-Output $policyDefinitionJson

    # Create the new policy definition
    New-AzPolicyDefinition -Name "$Allowedpolicyname" -Policy $policyDefinitionJson -Mode All

    Write-Output "Policy created successfully."
 }


#######################################################


 $updatedpolicy = "$Allowedpolicyname.json"

 
     $newpolicydefiniton =      $policyDefinitionJson   

     $policyDefinitionJson  | out-file  $updatedpolicy

 
     
  ################################## Add raw content to Variable
 
 
     $date = get-date -Format 'yyyyMMddHHmmss'   

   
        ##################  Write updated parameters file to Storage account 

              Set-azStorageBlobContent -Container $historycontainer -Blob "$($updatedpolicy)$date"  -File "$($updatedpolicy)"  -Context $destContext -Force

 

        ############## Apply updates to Policy parameters and reapply to Definition

        #############  Change " -name "xxxx" to variable based on custom name   ****************************************


 $policytoassign = Get-AzPolicyDefinition | where displayname -eq "$Allowedpolicyname"

############## Test/ Validation Policy and values

$policydefinitionproperties = Get-AzPolicyDefinition | where displayname -eq "$($policytoassign.name)"  

$policydefinitionproperties
$($policydefinitionproperties.metadata) | fl *

Write-Host "$($policydefinitionproperties.metadata)" -ForegroundColor Green
Write-Host "$($policydefinitionproperties.parameter.listofallowedskus.displayName)" -ForegroundColor Green
Write-Host "$($policydefinitionproperties.policyrule)" -ForegroundColor Green
Write-Host "$($policydefinitionproperties.description)" -ForegroundColor Green

$($policydefinitionproperties.parameter).listofallowedskus.defaultvalue

##################################### Reassign subscription to update policy
 
######### Update  old assignment on resource
try {
    $PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $($policytoassign.id)

    if (-not [string]::IsNullOrEmpty($PolicyAssignment))
     {
        # Remove existing policy assignment if needed

        # Reassign Policy Definition
        $listofallowedskus = @{'listofallowedskus' = $($policydefinitionproperties.parameter).listofallowedskus.defaultvalue}

        # Ensure the Name parameter is provided
        $policyid = "$($policytoassign.id)"

        if (-not [string]::IsNullOrEmpty($policyid)) {

          $policyassignment = Get-AzPolicyAssignment -PolicyDefinitionId $($policyid)  
          


          $answer = read-host " Please confirm changes or setting for this policy $($policytoassign.displayname) Y/N only :" 

                    $confirm = switch ($anwser)
                    {
                        Y { 
                        
                             Update-AzPolicyAssignment -name $($policyassignment.Name)   -PolicyParameterObject $listofallowedskus -NonComplianceMessage @{Message = "Stop making mistakes - I will find you"}
                         
                          }
                        N { Write-host " Please start over and review or create new master list with update_allowed_sku_master_list_select_name.ps1 " -foregroundcolor red -BackgroundColor white

                              exit
                            }

                        default { exit }
                    }

           Update-AzPolicyAssignment -name $($policyassignment.Name)   -PolicyParameterObject $listofallowedskus -NonComplianceMessage @{Message = "Stop making mistakes - I will find you"}
        
        
        } else {
            Write-Host "The Name parameter is null or empty. Please provide a valid Name." -ForegroundColor Red
        }
    } else {
        Write-Host "Policy: $($policydefinitionproperties.displayName) not assigned yet to any level ******" -ForegroundColor Black -BackgroundColor White
        Write-Host "No existing assignments yet - please do the ***initial policy assignments*** in the portal using the link below -  all assignments will be automatically updated if they exist " -ForegroundColor Cyan
      write-host " set new assignmentes here : https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Definitions " -ForegroundColor Cyan  

   
    }
} catch {
    Write-Host "No assignment made for this policy yet" -ForegroundColor Cyan
 

}

################  Write json policy definition to history container

 Set-azStorageBlobContent -Container $historycontainer -Blob "$updatedpolicy"  -File "$updatedpolicy"  -Context $destContext -Force






