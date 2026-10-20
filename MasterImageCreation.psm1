<#
     .SYNOPSIS
         Evergreen script to initiate the module 
#> 

[CmdletBinding(SupportsShouldProcess = $False)] param ()  
#region Get CmdLets for import
$Root = Join-Path -Path $PSScriptRoot -ChildPath "CMDLets"
$CmdLets = Get-ChildItem -Recurse -Path (Join-Path $Root "*.ps1")

# Dot source the files 
foreach ($CmdLet in $CmdLets) {
    try {
        . $CMdlet.FullName        
    } catch {
        throw $_
    } 
}  # Export the public modules and aliases 
#Export-ModuleMember -Function $CmdLets.Basename -Alias * 
#endregion  
# Get module strings 
#$script:resourceStrings = Get-ModuleResource
Export-ModuleMember -Function *