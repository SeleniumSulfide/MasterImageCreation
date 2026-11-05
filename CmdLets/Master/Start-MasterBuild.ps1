Function Start-MasterBuild() {
<#
.SYNOPSIS
    Orchestrates the master build pipeline by loading configuration files, mapping network shares, and executing deployment phases.

.DESCRIPTION
    The Start-MasterBuild function acts as the core controller for automated build and deployment processes. 
    It ingests a state tracking object containing paths to base and overlay configuration JSON files, merges 
    their settings (file shares, variables, phases, applications, and registry settings), establishes prerequisites, 
    maps network shares, and delegates execution based on the environment version (running legacy tasks or library-driven workflows).

.PARAMETER State
    A mandatory custom object containing build configuration and execution states. Typically includes:
    - BaseFile: Path to the base JSON configuration file.
    - OverlayFile: (Optional) Path to an overlay/override JSON configuration file.
    - Phase: The current execution phase string.
    - Shares: Pre-configured file share objects.
    - Pause: A switch parameter to prompt for manual confirmation before proceeding with the phase.

.EXAMPLE
    $BuildState = [PSCustomObject]@{
        BaseFile    = "C:\Config\base.json"
        OverlayFile = "C:\Config\overlay.json"
        Phase       = "Phase1"
        Pause       = [System.Management.Automation.SwitchParameter]::Present
    }
    Start-MasterBuild -State $BuildState
    
    Description:
    Loads the base and overlay JSON configurations, pauses for user confirmation, and runs the master build pipeline for Phase1.

.NOTES
    Prerequisites:
    - Relies on several supporting functions in the session, such as Initialize-PreReqs, Initialize-Variables, 
      Connect-FileShares, Invoke-ScriptBlocks, Install-Applications, and Sync-RegistrySettings.

.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/developer/help/writing-comment-based-help
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            $State
    )

    $ProgressPreference = 'SilentlyContinue'
    $Global:Environment = $State.BaseFile | Get-Content | ConvertFrom-Json
    If ($State.OverlayFile) {
        $Global:Config = $State.OverlayFile | Get-Content | ConvertFrom-Json
    }


    $FileShares       = If ($State.Shares) { $State.Shares } else { @($Config.FileShares + $Environment.FileShares) }
    $Global:Variables = @($Config.Variables                              + $Environment.Variables)
    $PreScriptBlocks  = @($Config.Phases.($State.Phase).PreScriptBlocks  + $Environment.Phases.($State.Phase).PreScriptBlocks)
    $Applications     = @($Config.Phases.($State.Phase).Applications     + $Environment.Phases.($State.Phase).Applications)
    $RegistrySettings = @($Config.Phases.($State.Phase).RegistrySettings + $Environment.Phases.($State.Phase).RegistrySettings)
    $PostScriptBlocks = @($Config.Phases.($State.Phase).PostScriptBlocks + $Environment.Phases.($State.Phase).PostScriptBlocks)

    If ($State.Pause.IsPresent) {Read-Host "Pausing before Phase: $($State.Phase), Press Enter to continue"}

    Initialize-PreReqs
    Initialize-Variables  -Variables        $Global:Variables
    Connect-FileShares    -FileShares       $FileShares

    Switch ($Environment.Version) {
        Default {
            Invoke-ScriptBlocks   -ScriptBlocks     $PreScriptBlocks
            Install-Applications  -Applications     $Applications
            Sync-RegistrySettings -RegistrySettings $RegistrySettings
            Invoke-ScriptBlocks   -ScriptBlocks     $PostScriptBlocks
        }
        2 {
            Invoke-ScriptBlocks   -ScriptBlocks     $PreScriptBlocks

            Initialize-Library    -Library          (Get-Childitem (Join-Path $LibraryPath "*.json") -Recurse)
            
            $Applications | Get-LibraryApplication | Save-LibraryApplication -Path $SoftwarePath
            $Applications | Get-LibraryApplication | Install-LibraryApplication -Path $SoftwarePath
            $Applications | Get-LibraryApplication | Sync-LibraryApplicationRegistry

            Sync-RegistrySettings -RegistrySettings $RegistrySettings
            Invoke-ScriptBlocks   -ScriptBlocks     $PostScriptBlocks
        }
    }
}