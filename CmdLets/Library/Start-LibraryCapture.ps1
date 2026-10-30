Function Start-LibraryCapture() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            $Package
    )
    $ProgressPreference = 'SilentlyContinue'

    Initialize-Variables $Package.Variables
    Get-ChildItem (Join-Path $LibraryPath "*.json") | Initialize-Library

    Invoke-ScriptBlocks $Package.PreScriptBlocks
    
    $Package.Applications | Get-LibraryApplication | Connect-LibraryApplicationShare
    $Package.Applications | Get-LibraryApplication | Save-LibraryApplication -Path $SoftwarePath
    $Package.Applications | Get-LibraryApplication | Install-LibraryApplication -Path $SoftwarePath
    $Package.Applications | Get-LibraryApplication | Sync-LibraryApplicationRegistry

    Invoke-ScriptBlocks $Package.PostScriptBlocks

    Remove-Item $SoftwarePath -Recurse -Force
    Remove-Item "C:\Users\*\Desktop\*.lnk" -Force
}