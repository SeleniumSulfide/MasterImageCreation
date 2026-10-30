Param(
    [Parameter(Mandatory=$True)]
        [System.IO.FileInfo]$PackageFile
)

$Elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
If (!$Elevated) {
    Throw "Please run with Elevated permissions"
}

If (!(Get-Module MasterImageCreation -ListAvailable)) {
    Install-Module MasterImageCreation -Scope AllUsers -Force
}

$Services = @("ClickToRunSvc","wuauserv","edge*","MicrosoftEdge*","*adobe*","*chrome*","*google*")
$Services | ForEach-Object {
    Get-Service -Name $_ | Set-Service -StartupType Disabled
    Get-Service -Name $_ | Stop-Service
}

$Package = Get-Content $PackageFile | ConvertFrom-Json

Start-LibraryCapture -Package $Package