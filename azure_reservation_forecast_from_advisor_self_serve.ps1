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


    Script Summary
        This PowerShell script generates a detailed Azure reservation instance savings plan report based on Azure 
        Advisor recommendations. It connects to an Azure account, retrieves cost-related recommendations, calculates 
        potential savings, and generates an HTML report summarizing the findings.

        Key Actions Performed by the Script
        Azure Account Connection:

        Connects to the Azure account using device authentication for a specific tenant and subscription.
        Set Subscription Context:

        Retrieves the subscriptions for the specified tenant and sets the context to the desired subscription.
        Retrieve Azure Advisor Recommendations:

        Executes a query to fetch cost-related Azure Advisor recommendations for each subscription.
        Extracts and formats additional information from the recommendations.
        Define Calculation Functions:

        Calculate-Savings
        : Calculates savings over different periods (e.g., 30, 60, 90, 365, and 1095 days) based on the term of the recommendation.
        Process and Format Recommendations:

        Initializes an array to hold the formatted recommendation objects.
        Iterates through each recommendation to extract relevant details and calculate potential savings.
        Formats the recommendation data into a structured object.
        Generate HTML Report:

        Creates an HTML report with detailed styling, including the recommendation details and calculated savings.
        Saves the HTML report to a specified path and opens it for viewing.
        Steps in the Script
        Connect to Azure:

        Authenticates and sets the context for the specified subscription.
        Retrieve Advisor Recommendations:

        Executes a query to fetch cost-related recommendations from Azure Advisor.
        Processes the query results to extract and format additional information.
        Calculate Savings:

        Defines a function to calculate potential savings over different periods.
        Iterates through the recommendations to calculate and format the savings data.
        Generate Reports:

        Aggregates the formatted recommendation data.
        Creates and styles an HTML report.
        Saves and opens the HTML report for easy access and review.
        The script provides a comprehensive view of potential cost savings through Azure reservation instances,
         making it easier to identify cost-saving opportunities and optimize Azure expenditures.

        #> 

## install-module -name az.resourcegraph -allowclobber 

import-module az.resourcegraph -force
 

# Connect to Azure account
 connect-azaccount  -identity
 
 $account | fl *

# Set the subscription context if you have multiple subscriptions
$subscriptions = Get-AzSubscription  


 $advisorsavingsreport = ''


 
    $QUERY =  'advisorresources
| where type == "microsoft.advisor/recommendations"
| where tostring (properties.category) has "Cost"
| where properties.impactedField has "Microsoft.Subscriptions/subscriptions" 
| project name, AffectedResource=tostring(properties.resourceMetadata.resourceId),Recommendation=tostring(properties.shortDescription.problem),Impact=tostring(properties.impact),resourceGroup,AdditionaInfo=properties.extendedProperties,subscriptionId'
	

 
    $reservationrecommendations = ''

foreach($sub in $subscriptions) 
{
    Set-azcontext -Subscription $sub.Name | out-null

    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
try
{
    $AzureLogin = Get-AzSubscription
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken 
    if($Token.ExpiresOn -lt $(get-date))
    {
        "Logging you out due to cached token is expired for REST AUTH.  Re-run script"
        $null = Disconnect-AzAccount        
    } 
}
catch
{
    $null = Login-AzAccount
    $AzureLogin = Get-AzSubscription
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken

}





    
    $queryresults1 =  Search-AzGraph -Query $QUERY -Subscription $SUB.id

    $($queryresults1.AdditionaInfo) | FL *
 

        # Function to calculate savings for different periods
    function Calculate-Savings {
        param (
            [float]$NetSavings,
            [string]$Term,
            [int]$Days
        )

        if ($Term -eq 'P1Y') {
            $termtotalsavings = $NetSavings
        } elseif ($Term -eq 'P3Y') {
            $termtotalsavings = $NetSavings / 3
        } else {
            $termtotalsavings = 0
        }

        $dailySavings = $termtotalsavings / 365
        return $dailySavings * $Days
    }



     


      $($queryresults1) | FL *

      foreach($reservationitem in $($queryresults1) )
      {
        

            $reservobj = new-object PSObject
            $($reservationitem.name)

            $netSavings = $($reservationitem.AdditionaInfo.annualSavingsAmount)

                $reservobj | add-member -MemberType NoteProperty  -name Recommendationname     -value  $($reservationitem.name)
                $reservobj | add-member -MemberType NoteProperty  -name AffectedResource     -value  $($reservationitem.AffectedResource)
                $reservobj | add-member -MemberType NoteProperty  -name Recommendation     -value  $($reservationitem.Recommendation)
                $reservobj | add-member -MemberType NoteProperty  -name Impact     -value  $($reservationitem.Impact)
                $reservobj | add-member -MemberType NoteProperty  -name resourceGroup     -value  $($reservationitem.resourceGroup)                
                $reservobj | add-member -MemberType NoteProperty  -name AdditionaInfo     -value  $($reservationitem.AdditionaInfo)
                $reservobj | add-member -MemberType NoteProperty  -name subscriptionId     -value  $($reservationitem.subscriptionId)
 
                $reservobj | Add-Member -MemberType NoteProperty -Name region -Value $($reservationitem.AdditionaInfo.region)
                $reservobj | Add-Member -MemberType NoteProperty -Name reservedResourceType -Value $($reservationitem.AdditionaInfo.reservedResourceType)
                $reservobj | Add-Member -MemberType NoteProperty -Name annualSavingsAmountbyterm -Value $($reservationitem.AdditionaInfo.annualSavingsAmount)
                $reservobj | Add-Member -MemberType NoteProperty -Name savingsCurrency -Value $($reservationitem.AdditionaInfo.savingsCurrency)
                $reservobj | Add-Member -MemberType NoteProperty -Name lookbackPeriod -Value $($reservationitem.AdditionaInfo.lookbackPeriod)
                $reservobj | Add-Member -MemberType NoteProperty -Name savingsAmount -Value $($reservationitem.AdditionaInfo.savingsAmount)
                $reservobj | Add-Member -MemberType NoteProperty -Name targetResourceCount -Value $($reservationitem.AdditionaInfo.targetResourceCount)
                $reservobj | Add-Member -MemberType NoteProperty -Name displaySKU -Value $($reservationitem.AdditionaInfo.displaySKU)
                $reservobj | Add-Member -MemberType NoteProperty -Name displayQty -Value $($reservationitem.AdditionaInfo.displayQty)
                $reservobj | Add-Member -MemberType NoteProperty -Name location -Value $($reservationitem.AdditionaInfo.location)
                $reservobj | Add-Member -MemberType NoteProperty -Name vmSize -Value $($reservationitem.AdditionaInfo.vmSize)
                $reservobj | Add-Member -MemberType NoteProperty -Name subId -Value $($reservationitem.AdditionaInfo.subId)
                $reservobj | Add-Member -MemberType NoteProperty -Name scope -Value $($reservationitem.AdditionaInfo.scope)
                $term = $($reservationitem.AdditionaInfo.term) 

                $reservobj | Add-Member -MemberType NoteProperty -Name term -Value $($reservationitem.AdditionaInfo.term)   
                $reservobj | Add-Member -MemberType NoteProperty -Name sku -Value $($reservationitem.AdditionaInfo.sku)
                 $reservobj | Add-Member -MemberType NoteProperty -Name subscriptionname -Value (Get-azsubscription -subscriptionid $($reservationitem.AdditionaInfo.subId)).name
                $netSavings30Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 30
                $netSavings60Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 60
                $netSavings90Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 90
                $netSavings365Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 365
                $netSavings1095Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 1095



                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings30Days  -Value $netSavings30Days    
                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings60Days  -Value $netSavings60Days
                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings90Days  -Value $netSavings90Days
                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings365Days  -Value $netSavings365Days
                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings1095Days  -Value $netSavings1095Days


                        
                [array]$reservationrecommendations += $reservobj 

                }
}

                
        # Generate HTML report
$date = Get-Date -Format 'dd MMMM yyyy'
$CSS = @"
<Title> Azure reservation instance Plan Forecast Report from Advisor: $date </Title>
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

$htmlContent = @"
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Total cost of additional hours to zero overages: $$totalCostToZeroOverages</p>
"@ + ( $reservationrecommendations | select Recommendationname,`
AffectedResource,`
Recommendation,`
Impact ,`
#resourceGroup,`
AdditionaInfo,`
subscriptionId,`
subscriptionname, `
region,`
reservedResourceType,`
term,`
annualSavingsAmountbyterm,`
savingsCurrency,`
lookbackPeriod,`
savingsAmount,`
targetResourceCount,`
displaySKU,`
displayQty,`
location,`
vmSize,`
subId,`
scope,`
sku,`
  netSavings30Days,`    
  netSavings60Days,`
  netSavings90Days,`
  netSavings365Days,`
  netSavings1095Days | ConvertTo-Html -Head $CSS)

$outputHtmlPath = "c:\temp\reservation_plan_from_advisor.html"
$htmlContent | Out-File -FilePath $outputHtmlPath

Write-Output "HTML report has been saved to $outputHtmlPath"

 

# Open the HTML report
Invoke-Item -Path $outputHtmlPath

## Save to csv format 
$reservationrecommendations | Where-Object { $_ -ne "" } | select Recommendationname,`
AffectedResource,`
Recommendation,`
Impact ,`
#resourceGroup,`
AdditionaInfo,`
subscriptionId,`
subscriptionname, `
region,`
reservedResourceType,`
term,`
annualSavingsAmountbyterm,`
savingsCurrency,`
lookbackPeriod,`
savingsAmount,`
targetResourceCount,`
displaySKU,`
displayQty,`
location,`
vmSize,`
subId,`
scope,`
displaySKU,`
  netSavings30Days,`    
  netSavings60Days,`
  netSavings90Days,`
  netSavings365Days,`
  netSavings1095Days | export-csv -Path "C:\temp\reservation_plan_from_advisor.csv" -NoTypeInformation

############### summary 
# Group the data by AffectedResource, reservedResourceType, term, sku, vmsize, region, and subscriptionname
$groupedData = $reservationrecommendations | where-object {$_ -ne ""} | Group-Object -Property AffectedResource, reservedResourceType, term, sku, vmsize, region, subscriptionname

# Create an array to store the summary results
$summaryResults = @()

# Loop through each group and create a custom object for each summary result
foreach ($group in $groupedData) {
    # Initialize variables for total savings
    $totalNetSavings30Days = 0
    $totalNetSavings60Days = 0
    $totalNetSavings90Days = 0
    $totalNetSavings365Days = 0
    $totalNetSavings1095Days = 0

    # Check if the properties exist and calculate the total savings for each group
    if ($group.Group[0].PSObject.Properties['netSavings30Days']) {
        $totalNetSavings30Days = ($group.Group | Measure-Object -Property netSavings30Days -Sum).Sum
    }
    if ($group.Group[0].PSObject.Properties['netSavings60Days']) {
        $totalNetSavings60Days = ($group.Group | Measure-Object -Property netSavings60Days -Sum).Sum
    }
    if ($group.Group[0].PSObject.Properties['netSavings90Days']) {
        $totalNetSavings90Days = ($group.Group | Measure-Object -Property netSavings90Days -Sum).Sum
    }
    if ($group.Group[0].PSObject.Properties['netSavings365Days']) {
        $totalNetSavings365Days = ($group.Group | Measure-Object -Property netSavings365Days -Sum).Sum
    }
    if ($group.Group[0].PSObject.Properties['netSavings1095Days']) {
        $totalNetSavings1095Days = ($group.Group | Measure-Object -Property netSavings1095Days -Sum).Sum
    }

    # Extract the fields correctly
    $fields = $group.Name.Split(',')
    $affectedResource = $fields[0].Trim()
    $reservedResourceType = $fields[1].Trim()
    $term = $fields[2].Trim()
    $sku = $fields[3].Trim()
  try{
        if($($fileds[4]) -ne $null) 
        {
            $vmsize = $fields[4].Trim()
        }
    }
    catch
    {
        write-host 'skipping empty field vmsize' -ForegroundColor Cyan
    }
 

 

   # $region = $fields[5].Trim()

    try{
        if($($fileds[6]) -ne $null) 
        {
            $subscriptionname = $fields[6].Trim()
        }
    }
    catch
    {
        write-host 'skipping empty field Subscriptionname' -ForegroundColor Cyan
    }
     # Check if vmsize is blank or null and replace with sku if necessary
    if ([string]::IsNullOrEmpty($vmsize)) { 
        $vmsize = if ([string]::IsNullOrEmpty($group.Group[0].displaysku) -and [string]::IsNullOrEmpty($group.Group[0].location)  ) { 
        $sku = $group.Group[0].sku 
        $term = $fields[1].Trim()
        $vmsize = "All"
        $region = 'All'
        } 
    }
     
    # Handle the case where displaysku is Compute_Savings_Plan
    if ($group.Group[0].displaysku -eq "Compute_Savings_Plan" -or $group.Group[0].displaysku -eq $null) {
        $reservedResourceType = "Compute_Savings_Plan"
        $term = $fields[1].Trim()
        $vmsize = "All"
        $sku = "Compute_Savings_Plan"
        $region = 'All'
    }

    # Debugging output to check values
    Write-Host "AffectedResource: $affectedResource"
    Write-Host "reservedResourceType: $reservedResourceType"
    Write-Host "term: $term"
    Write-Host "sku: $sku"
    Write-Host "vmsize: $vmsize"
    Write-Host "region: $region"
    Write-Host "subscriptionname: $subscriptionname"

    $summaryResult = [PSCustomObject]@{
        AffectedResource      = $affectedResource
        reservedResourceType  = $reservedResourceType
        term                  = $term
        sku                   = $sku
        vmsize                = $vmsize
        region                = $region
        subscriptionname      = $subscriptionname
        Count                 = $group.Count
        netSavings30Days      = $totalNetSavings30Days
        netSavings60Days      = $totalNetSavings60Days
        netSavings90Days      = $totalNetSavings90Days
        netSavings365Days     = $totalNetSavings365Days
        netSavings1095Days    = $totalNetSavings1095Days
        displaysku            = $group.Group[0].sku
    }
    $summaryResults += $summaryResult
}

# Output the summary results in a table format
$summaryResults | Format-Table -AutoSize

# Optionally, export the summary results to a new CSV file
$summaryResults | Select-Object subscriptionname, AffectedResource, reservedResourceType, term, sku, vmsize, displaysku, region, Count, netSavings30Days, netSavings60Days, netSavings90Days, netSavings365Days, netSavings1095Days | Export-Csv -Path "c:\temp\summary_reservation_plan.csv" -NoTypeInformation

$summaryhtmlContent = @"
<h2>Azure Reservations Forecast Summary Report</h2>
<p>Date: $date</p>
<p>Total cost of additional hours to zero overages: $$totalCostToZeroOverages</p>
"@ + ( $summaryResults | Select-Object subscriptionname, AffectedResource, reservedResourceType, term, sku, vmsize, displaysku, region, Count, netSavings30Days, netSavings60Days, netSavings90Days, netSavings365Days, netSavings1095Days | ConvertTo-Html -Head $CSS)

$summaryoutputHtmlPath = "c:\temp\reservation_plan_from_advisor_summary.html"
$summaryhtmlContent | Out-File -FilePath $summaryoutputHtmlPath

# Open the HTML report
Invoke-Item -Path $summaryoutputHtmlPath










  