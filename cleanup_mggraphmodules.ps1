<#
    Local administration rights are required for the "-Scope AllUsers" option to work. Otherwise, remove that option from the commandlets to do a per user refresh.
#>
try
{
    $Scope = "AllUsers";

    # Enumerate the currently-installed modules from the AllUsers scope.
    $Modules = (Get-Module -ListAvailable -Name "Microsoft.Graph.*" -ErrorAction:Stop).Name | Select-Object -Unique;

    # Output the list to the pipeline as a "just in case".
    Write-Warning -Message "Modules detected:";
    $Modules;

    # Now, chuck 'em all in the bin.
    $Modules |
        ForEach-Object {
            Uninstall-Module -Name $_ -AllVersions -Force -ErrorAction:Stop;
        }

    # The authentication module is a prerequisite for all the other Graph modules (which throw a warning on installation if this one isn't already present), hence breaking it out to be first to be re-installed.
    Install-Module -Name "Microsoft.Graph.Authentication" -Scope $Scope -Force -ErrorAction:Stop;

    # Re-install the rest, excluding the authentication module from above.
    $Modules |
        ForEach-Object {
            if ($_ -ne "Microsoft.Graph.Authentication")
            {
                Install-Module -Name $_ -Scope $Scope -Force -ErrorAction:Stop;
            }
        }
}
catch
{
    throw;
}


   
  
  'Az.Accounts','Az.Resources','Az.Compute','az', 'Az.Storage', 'az.resourcegraph' | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
         update-module $_ -force
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
        install-module -name $_ -allowclobber
        import-module -name $_ -force
    }
   #  Get-InstalledModule
}
  
