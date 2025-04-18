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

Purpose:
The script creates or updates a custom Azure role definition by allowing administrators to select specific actions to allow and not allow.

Functions:
Connect to Azure: Uses managed identity to connect to the Azure account.
Select Subscription: Prompts the user to select an Azure subscription.
Retrieve Providers: Gets a list of registered resource providers.
Filter Operations: Filters provider operations based on specific criteria.
Select Actions: Allows the user to select actions to allow and not allow using a grid view.
Role Details: Prompts the user to enter the role name and description.
Check Role Existence: Checks if the role already exists.
Create/Update Role: Creates a new role or updates an existing one with the selected actions and not actions.
Save Role Definition: Saves the role definition to a JSON file.
This script helps define precise permissions for users or groups in an Azure subscription
#>

#Install-Module -Name Az -AllowClobber -Force
Import-Module Az

 
$ErrorActionPreference = 'Continue'

########################################
  

$mgrouplist = ''
 
  $context = Connect-AzAccount     -identity
 
 set-azcontext -Tenant  $($context.Context.Tenant.TenantId)

$date = get-date
# Ensure you have the Az module installed and imported

 

# Define the query to list all subscriptions with their management group hierarchy
$query = @"
resourcecontainers
| where type == 'microsoft.resources/subscriptions'
| extend managementGroupParent = properties.managementGroupAncestorsChain[0]
| project name, id, managementGroupParent.displayName
"@

# Execute the query using Azure Resource Graph
$response = Search-AzGraph -Query $query

# Display the results
 $mgroupsublist = $response | Select-Object name, id, managementGroupParent_displayName

 
$mgsubstoaddroleto =  $mgroupsublist | ogv -title " Select Subs in the list from the managment groups to add role to:" -PassThru | Select *



# Get the list of registered resource providers
$registeredProviders = Get-AzResourceProvider -ListAvailable | Where-Object { $_.RegistrationState -eq 'Registered' }

# Get all provider operations and filter for registered providers only
$provider_operations = Get-AzProviderOperation | Where-Object {
    $registeredProviders.ProviderNamespace -contains $_.ProviderNamespace -and $_.Description
}

# Filter provider operations based on criteria
$provider_actions = $provider_operations | Where-Object {
    $_.Operation -like '*virtualMachines*' -or $_.Operation -like '*Compute*' -or $_.Operation -like '*AlertsManagement*' `
    -or $_.Operation -like '*storage*' -and $_.Operation -notlike '*Classic*' -and $_.Operation -notlike '*stack*' `
    -and $_.Operation -notlike '*apis*' -and $_.operation -notlike '*k8s*' -and $_.Operation -notlike '*ConnectedVMwarevSphere*'
} | Select-Object Operation

# Select Actions
$actions_to_allow = $provider_actions | Out-GridView -Title "Select all actions to allow for this group:" -PassThru | Select-Object Operation

# Select NotActions
$notactions_to_block = $provider_actions | Out-GridView -Title "Select all actions  to block for this group:" -PassThru | Select-Object Operation

$rolename = Read-Host "Enter new role name:"
$roledescription = Read-Host "Enter brief role description:"

$rolename  = $rolename -replace(' ','') 

foreach($sub in $mgsubstoaddroleto)
{
    $roleuniquename  = "$rolename"+"$($subscription.name)"
    $subscription = get-azsubscription -SubscriptionName $($sub.name)
    set-azcontext -Subscription $($subscription.Name)

        # Check if role already exists
        $existingRole = Get-AzRoleDefinition | Where-Object { $_.Name -eq $roleuniquename }

        if ($null -eq $existingRole) {
            $role = New-Object -TypeName Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition
            $role.Name = "$roleuniquename"
            $role.Description = $roledescription
            $role.IsCustom = $true
            $role.Actions = @()
            $role.NotActions = @()
            $role.AssignableScopes = @("/subscriptions/$($subscription.Id)")

            foreach ($perms in $actions_to_allow) {
                if ($null -ne $perms.Operation -and $perms.Operation -ne '') {
                    $role.Actions.Add($perms.Operation)
                }
            }

            foreach ($perms in $notactions_to_block) {
                if ($null -ne $perms.Operation -and $perms.Operation -ne '') {
                    $role.NotActions.Add($perms.Operation)
                }
            }

            New-AzRoleDefinition -Role $role  -Verbose
        } else {
            Write-Output "Role already exists."
            $existingRole.Actions = @()
            $existingRole.NotActions = @()

            foreach ($perms in $actions_to_allow) {
                if ($null -ne $perms.Operation -and $perms.Operation -ne '') {
                    $existingRole.Actions.Add($perms.Operation)
                }
            }

            foreach ($perms in $notactions_to_block) {
                if ($null -ne $perms.Operation -and $perms.Operation -ne '') {
                    $existingRole.NotActions.Add($perms.Operation)
                }
            }

            $existingRole.AssignableScopes = @("/subscriptions/$($subscription.Id)")
            Set-AzRoleDefinition -Role $existingRole -Verbose
        }

        Get-AzRoleDefinition "$rolename" | ConvertTo-Json | Out-File "C:\temp\$rolename.json"

       # invoke-item "C:\temp\$rolename.json"

}
