<#
     .SYNOPSIS
         Evergreen script to initiate the module 
#> 

[CmdletBinding(SupportsShouldProcess = $False)] param ()  
#region Get CmdLets for import
$Root = Join-Path -Path $PSScriptRoot -ChildPath "Automation"
$CmdLets = Get-ChildItem -Recurse -Path (Join-Path $Root "*.psm1") -ErrorAction "SilentlyContinue"

# Dot source the files 
foreach ($CmdLet in $CmdLets) {
    try {
        #write-host $import.fullname
        . $CmdLet.FullName
    }
    catch {
        throw $_
    } 
}  # Export the public modules and aliases 
#Export-ModuleMember -Function $CmdLets.Basename -Alias * 
#endregion  
# Get module strings 
#$script:resourceStrings = Get-ModuleResource
