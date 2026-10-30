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

$ProgressPreference = 'SilentlyContinue'

Get-ChildItem (Join-Path $ScriptRoot "*.psm1") | Import-Module
$Package = Get-Content $PackageFile | ConvertFrom-Json
Initialize-Variables $Package.Variables
Get-ChildItem (Join-Path $LibraryPath "*.json") | Initialize-Library
Invoke-ScriptBlocks $Package.PreScriptBlocks
$Applications = $Package.Applications | Get-LibraryApplication
Connect-LibraryApplicationShare -Applications $Applications
$Applications | Save-LibraryApplication -Path $SoftwarePath

$Action = "Install"; If ($Confirm.IsPresent) { Read-Host "Press enter to begin $Action" };
$Applications | Install-LibraryApplication -Path $SoftwarePath
$Applications | Sync-LibraryApplicationRegistry
Invoke-ScriptBlocks $Package.PostScriptBlocks

$Action = "Cleanup"; If ($Confirm.IsPresent) { Read-Host "Press enter to begin $Action" };
Remove-Item $SoftwarePath -Recurse -Force
Remove-Item "C:\Users\*\Desktop\*.lnk" -Force