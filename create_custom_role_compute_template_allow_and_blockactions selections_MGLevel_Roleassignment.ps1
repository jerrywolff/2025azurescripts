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

    This PowerShell script performs several functions related to Azure management and role assignments:
    Description:
        Module Import and Setup:
        Imports the Az module.
        Sets the error action preference to ‘Continue’.
        Connects to Azure using managed identity and sets the context to the current tenant.
        Query Subscriptions:
        Defines a query to list all subscriptions along with their management group hierarchy.
        Executes the query using Azure Resource Graph and stores the results.
        Select Subscriptions:
        Displays the list of subscriptions in a grid view for the user to select which subscriptions to add roles to.
        Resource Providers and Operations:
        Retrieves the list of registered resource providers.
        Gets all provider operations and filters them based on specific criteria (e.g.,
         operations related to virtual machines, compute, storage, etc.).
        Select Actions and NotActions:
        Displays the filtered provider operations in grid views for the user to select 
        actions to allow and actions to block.
        Role Creation and Assignment:
        Prompts the user to enter a new role name and description.
        For each selected subscription, it checks if the role already exists. 
        If not, it creates a new custom role with the specified actions and not actions.
        If the role already exists, it updates the existing role with the new actions and not actions.
        Saves the role definition to a JSON file.
        This script is useful for managing Azure roles and permissions across 
        multiple subscriptions and management groups, allowing for fine-grained control over what actions are permitted or blocked.
        #>



Import-Module Az

$ErrorActionPreference = 'Continue'

$mgrouplist = ''

$context = Connect-AzAccount -Identity
Set-AzContext -Tenant $($context.Context.Tenant.TenantId)

$date = Get-Date

# Define the query to list all subscriptions with their management group hierarchy
$query = @"
resourcecontainers
| where type == 'microsoft.resources/subscriptions'
| extend managementGroupParent = properties.managementGroupAncestorsChain[0]
| extend managementGroupLevel = array_length(properties.managementGroupAncestorsChain)
| project name, id, managementGroupParent.displayName,   managementGroupLevel
"@

# Execute the query using Azure Resource Graph
$response = Search-AzGraph -Query $query

# Display the results
$mgroupsublist = $response | Select-Object name, id, managementGroupParent_displayName, managementGroupLevel

$mgsubstoaddroleto = $mgroupsublist | Out-GridView -Title "Select managementgroup parent in the list to add role to (RBAC is inherited downwards):" -PassThru | Select -first 1

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
$notactions_to_block = $provider_actions | Out-GridView -Title "Select all actions to block for this group:" -PassThru | Select-Object Operation

$rolename = Read-Host "Enter new role name:"
$roledescription = Read-Host "Enter brief role description:"

$rolename = $rolename -replace(' ', '')

foreach ($mg in $mgsubstoaddroleto) {
    $roleuniquename = "$rolename" + "$($mg.managementGroupParent_displayName)"


    # Check if role already exists
    $existingRole = Get-AzRoleDefinition | Where-Object { $_.Name -eq $roleuniquename }

    if ($null -eq $existingRole) {
        $role = New-Object -TypeName Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition
        $role.Name = "$roleuniquename"
        $role.Description = $roledescription
        $role.IsCustom = $true
        $role.Actions = @()
        $role.NotActions = @()
        $role.AssignableScopes = @("/providers/Microsoft.Management/managementGroups/$($mg.managementGroupParent_displayName)")

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

        New-AzRoleDefinition -Role $role -Verbose
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

        $existingRole.AssignableScopes = @("/providers/Microsoft.Management/managementGroups/$($mg.managementGroupParent_displayName)")
        Set-AzRoleDefinition -Role $existingRole -Verbose
    }

    Get-AzRoleDefinition "$rolename" | ConvertTo-Json | Out-File "C:\temp\$rolename.json"
}



















