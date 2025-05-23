<#

.SYNOPSIS  
 Wrapper script for create_AVD_Admin_pwd_in_keyvault.ps1 
.DESCRIPTION  
Script to create a keyvault to store local VM pwds for automation - bastion can also be used in its place.
.EXAMPLE  
create_AVD_Admin_pwd_in_keyvault.ps1 -subscription <xxxxxxx> -Resourcegroup <xxxxxxx> -adminpwd <xxxxxx>
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



param(

[String]$subscription = $(throw "Value subscription name is missing"),
[String]$Resourcegroupname = $(throw "Value subscription name is missing"),
[String]$location = $(throw "Value location/region is missing"),
[String]$adminpwd = $(throw "Value subscription name is missing")
)


############  Comment out -Environmentname <xxxxxxx>  if used in commercial tenants
############ if used in Azure automation   comment out Connect-AzAccount    -Environment AzureUSGovernment
try
{
    "Logging in to Azure..."
    #Connect-AzAccount   -Identity
  Connect-AzAccount    -Environment AzureUSGovernment

}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

 
 
     $subscription = Get-AzSubscription  -SubscriptionName $subscription
       set-azcontext -Subscription $subscription
      $context = get-azcontext
       $context


  #########################################      


$keyVaultParameters = @{
    Name = "AVDkeyVault"
    ResourceGroupName = $resourceGroupName
    Location = $location
}
$keyVault = New-AzKeyVault @keyVaultParameters

$secretString = "$adminpwd"
$secretParameters = @{
    VaultName = $keyVault.VaultName
    Name= "avdadmin"
    SecretValue = ConvertTo-SecureString -String $secretString -AsPlainText -Force
}
$secret = Set-AzKeyVaultSecret @secretParameters

#####################################################
