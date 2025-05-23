# ReportSPOSiteStorageUsage.PS1
# Uses SharePoint Online and Exchange Online PowerShell modules
# Session must be connected to an admin account
# https://github.com/12Knocksinna/Office365itpros/blob/master/ReportSPOSiteStorageUsage.PS1


install-module -name ExchangeOnlineManagement -allowclobber
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -RequiredVersion 16.0.8029.0

Import-Module ExchangeOnlineManagement
import-module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
 
 $cred = Get-Credential

Connect-AzAccount -Credential $cred

Connect-MsolService -Credential $cred
 $spo = Connect-SPOService -Url "https://mngenvmcap741258-admin.sharepoint.com/" -Credential $cred 

  



Function ReturnO365GroupOwners([String]$SiteURL) {
# Function to return the owners of an Office 365 Group identified by the group GUID
$Owners = $Null; $DeletedGroup = $False; $i = 0; $SiteOwners = $Null
# Get the site properties. We need a separate call here because Get-SPOSite doesn't return all properties when it fetches a set of sites
$GroupId = (Get-SPOSite -Identity $SiteURL) 
If ($GroupId.Template -eq  "TEAMCHANNEL#0") { # If Teams private channel, we use the Related Group Id
   $GroupId = $GroupId | Select-Object -ExpandProperty RelatedGroupId }
Else { # And for all other group-enabled sites, we use the GroupId
   $Groupid = $GroupId | Select-Object -ExpandProperty GroupId }

If ($GroupId.Guid -eq "00000000-0000-0000-0000-000000000000") { # Null group id stored in site
       $SiteOwners = "Deleted group"; $DeletedGroup = $True }
If ($DeletedGroup -eq $False) {      
     Try { 
       $Owners = (Get-UnifiedGroupLinks -Identity $GroupId.Guid -LinkType Owners -ErrorAction SilentlyContinue) }
    Catch 
       { $SiteOwners = "Possibly deleted Office 365 Group"; $DeletedGroup = $True }}

If ($Null -eq $Owners) { # Got nothing back, maybe because of an error
      $SiteOwners = "Possibly deleted Office 365 Group"}
    Else { # We have some owners, now format them
      $Owners = $Owners | Select-Object -ExpandProperty DisplayName
      ForEach ($Owner in $Owners)  {
        If ($i -eq 0) 
         { $SiteOwners = $Owner; $i = 1 } 
       Else { $SiteOwners = $SiteOwners + "; " + $Owner}}}

Return $SiteOwners }

# Check that we are connected to Exchange Online and SharePoint Online
$ModulesLoaded = Get-Module | Select Name
If (!($ModulesLoaded -match "ExchangeOnlineManagement")) {Write-Host "Please connect to the Exchange Online Management module and then restart the script"; break}
If (!($ModulesLoaded -match "Microsoft.Online.Sharepoint.PowerShell")) {Write-Host "Please connect to the SharePoint Online Management module and then restart the script"; break}

# Get all SPO sites
CLS
Write-Host "Fetching site information..."
[array]$Sites = Get-SPOSite -Limit All | Select Title, URL, StorageQuota, StorageUsageCurrent, Template | Sort StorageUsageCurrent -Desc
If ($Sites.Count -eq 0) { Write-Host "No SharePoint Online sites found.... exiting..." ; break }
$TotalSPOStorageUsed = [Math]::Round(($Sites.StorageUsageCurrent | Measure-Object -Sum).Sum /1024,2)

CLS
$ProgressDelta = 100/($Sites.count); $PercentComplete = 0; $SiteNumber = 0
$Report = [System.Collections.Generic.List[Object]]::new() 
ForEach ($Site in $Sites) {
  $SiteOwners = $Null ; $Process = $True; $NoCheckGroup = $False
  $SiteNumber++
  $SiteStatus = $Site.Title + " ["+ $SiteNumber +"/" + $Sites.Count + "]"
  Write-Progress -Activity "Processing site" -Status $SiteStatus -PercentComplete $PercentComplete
  $PercentComplete += $ProgressDelta
  Switch ($Site.Template) {  #Figure out the type of site and if we should process it - this might not be an exhaustive set of site templates
   "RedirectSite#0"            {$SiteType = "Redirect"; $Process = $False }
   "GROUP#0"                   {$SiteType = "Group-enabled team site"}
   "TEAMCHANNEL#0"             {$SiteType = "Teams Private Channel" }
   "REVIEWCTR#0"               {$SiteType = "Review Center"; $Process = $False}
   "APPCATALOG#0"              {$SiteType = "App Catalog"; $Process = $False}
   "STS#3"                     {$SiteType = "Team Site"; $NoCheckGroup = $True; $SiteOwners = "System"}
   "SPSMSITEHOST#0"            {$SiteType = "Unknown"; $Process = $False}
   "SRCHCEN#0"                 {$SiteType = "Search Center"; $Process = $False}
   "EHS#1"                     {$SiteType = "Team Site - SPO Configuration"; $NoCheckGroup = $True; $SiteOwners = "System"}
   "EDISC#0"                   {$SiteType = "eDiscovery Center"; $Process = $False}
   "SITEPAGEPUBLISHING#0"      {$SiteType = "Site page"; $NoCheckGroup = $True; $SiteOwners = "System"}
   "POINTPUBLISHINGHUB#0"      {$SiteType = "Communications Site"; $NoCheckGroup = $True; $SiteOwners = "System" }
   "POINTPUBLISHINGPERSONAL#0" {$SiteType = "OneDrive for Business"; $Process = $False}
   "POINTPUBLISHINGTOPIC#0"    {$SiteType = "Office 365 Video"; $NoCheckGroup = $True; $SiteOwners = "System"} }

  If ($NoCheckGroup -eq $False) { # Get owner information if it's an Office 365 Group
     $SiteOwners = ReturnO365GroupOwners($Site.URL) }

$UsedGB = [Math]::Round($Site.StorageUsageCurrent/1024,2) 
$PercentTenant = ([Math]::Round($Site.StorageUsageCurrent/1024,4)/$TotalSPOStorageUsed).tostring("P")           

# And write out the information about the site
  If ($Process -eq $True) {
      $ReportLine = [PSCustomObject]@{
         URL           = $Site.URL
         SiteName      = $Site.Title
         Owner         = $SiteOwners
         Template      = $SiteType
         QuotaGB       = [Math]::Round($Site.StorageQuota/1024,0) 
         UsedGB        = $UsedGB
         PercentUsed   = ([Math]::Round(($Site.StorageUsageCurrent/$Site.StorageQuota),4).ToString("P")) 
         PercentTenant = $PercentTenant}
     $Report.Add($ReportLine)}}

# Now generate the report
$Report | Export-CSV -NoTypeInformation c:\temp\SPOSiteConsumption.CSV
Write-Host "Current SharePoint Online storage consumption is" $TotalSPOStorageUsed "GB. Report is in C:\temp\SPOSiteConsumption.CSV"

### Outgridview if desired uncomment
 # $report | ogv -Title " Sharepoint usage info:" -PassThru | select *



 ####################  html report 

 $CSS = @"

<Title>Sharepoint storage usage : $(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Sharepoint storage usage :$(Get-Date -Format 'dd MMMM yyyy')  </H2>

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





( $report | select URL ,SiteName,Owner, Template, QuotaGB, UsedGB, PercentUsed,PercentTenant `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\Sharepoint_storage_usage.html"


invoke-item "c:\temp\Sharepoint_storage_usage.html"










