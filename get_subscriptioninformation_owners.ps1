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

#> 
  Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'

Connect-AzAccount 

$subscriptions  = get-azsubscription   
$subscriptions 

$subinfo  = ''

$subsallfields = $subscriptions | Select-Object *


Foreach ($sub in $subsallfields)
{
    Set-AzContext -Subscription $($sub.Name) -Tenant $sub.TenantId

    foreach($mtentnat in $($sub.ManagedByTenantIds))
    {
        
        $managedbytenantidrec += $($sub.ManagedByTenantIds)

    }

       $ownerlist =  get-AzRoleAssignment    -Scope "/subscriptions/$($sub.ID)"    -RoleDefinitionName owner
 
       $owners = $($ownerlist.SignInName)
 

        foreach($owner in $owners)
        {

            $ownerobj = new-object PSObject 
            if($($owner) -ne $null)
            {
                 
                $ownerobj | add-member -MemberType NoteProperty -Name ownername -value "'$($owner)'"
            }
      

            [Array]$ownerrec += $ownerobj



        }

 


        $subobj = New-Object PSObject 

         $subobj | Add-Member -MemberType NoteProperty -Name Name   -value $($sub.Name) 
        $subobj | Add-Member -MemberType NoteProperty -Name State   -value $($sub.State) 
        $subobj | Add-Member -MemberType NoteProperty -Name SubscriptionId   -value $($sub.SubscriptionId) 
        $subobj | Add-Member -MemberType NoteProperty -Name HomeTenantId   -value $($sub.HomeTenantId) 
        $subobj | Add-Member -MemberType NoteProperty -Name ManagedByTenantIds   -value $managedbytenantidrec
         $subobj | Add-Member -MemberType NoteProperty -Name Owners   -value  "$($ownerrec.ownername)"
 
          [array]$subinfo += $subobj 
 
        
        
         $managedbytenantidrec= ''
         $ownerrec = ''

}


$subinfo




     $CSS = @"
<Title>Subscription Detail information :$(Get-Date -Format 'dd MMMM yyyy' )</Title>
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



$subinfo | select name,  state, SubscriptionId, HomeTenantId, ManagedByTenantIds, owners  |`
 ConvertTo-Html -Head $CSS    | out-file  "c:\temp\subscriptioninformation.html"

invoke-item  "c:\temp\subscriptioninformation.html"
 


