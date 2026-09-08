Param(
    [Parameter(Mandatory=$True)][System.IO.FileInfo]$PackageFile,
    [Parameter(Mandatory=$false)][System.IO.FileInfo]$ScriptRoot = "C:\Temp\Scripts",
    [Parameter(Mandatory=$False)][Switch]$Confirm
)
$Elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
If (!$Elevated) {
    Throw "Please run with Elevated permissions"
}
$Services = @("ClickToRunSvc","wuauserv","edge*","MicrosoftEdge*","*adobe*","*chrome*","*google*")
$Services | ForEach-Object {
    Get-Service -Name $_ | Set-Service -StartupType Disabled
    Get-Service -Name $_ | Stop-Service
}

Get-ChildItem (Join-Path $ScriptRoot "*.psm1") | Import-Module

$Package = Get-Content $PackageFile | ConvertFrom-Json

Initialize-Variables $Package.Variables

Get-ChildItem (Join-Path $LibraryPath "*.json") | Initialize-Library

Invoke-ScriptBlocks $Package.PreScriptBlocks

$Applications = $Package.Applications | Get-LibraryApplication

$Applications | Save-LibraryApplication -Path $SoftwarePath

$Applications | Install-LibraryApplication -Path $SoftwarePath

$Applications | Sync-LibraryApplicationRegistry

Invoke-ScriptBlocks $Package.PostScriptBlocks

Remove-Item $SoftwarePath -Recurse -Force

Remove-Item "C:\Users\*\Desktop\*.lnk" -Force
<#
ForEach ($App in $Package.Applications) {
    Write-Host "Processing: $App" -ForegroundColor Cyan
    $Application = Get-LibraryApplication $App
    $Application | Save-LibraryApplication -Path $SoftwarePath
    $Application | Install-LibraryApplication -Path $SoftwarePath
    $Application | Sync-LibraryApplicationRegistry
}

    $Package.Applications | `
        Get-LibraryApplication | `
        Save-LibraryApplication -Path $SoftwarePath | `
        Install-LibraryApplication -Path $SoftwarePath | `
        Sync-LibraryApplicationRegistry
#>
