Function Start-MasterBuild() {
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

            Initialize-Library    -Library          (Get-Childitem (Join-Path $LibraryPath "*.json"))
            
            $Applications | Get-LibraryApplication | Save-LibraryApplication -Path $SoftwarePath
            $Applications | Get-LibraryApplication | Install-LibraryApplication -Path $SoftwarePath
            $Applications | Get-LibraryApplication | Sync-LibraryApplicationRegistry

            Sync-RegistrySettings -RegistrySettings $RegistrySettings
            Invoke-ScriptBlocks   -ScriptBlocks     $PostScriptBlocks
        }
    }
}