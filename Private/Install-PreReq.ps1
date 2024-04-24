function Install-PreReq() {
    Param(
        [Parameter(Mandatory=$true)][String]$PreReq,
        [Parameter(Mandatory=$true)][Boolean]$Package
    )
    Write-Host "Installing $PreReq"
    if (!$Package) {
        Install-Module $PreReq -Scope AllUsers -Force | Import-Module $PreReq
    } else {
        $pkg = (Install-Package $PreReq -ProviderName NuGet -Scope CurrentUser -Force -SkipDependencies).Payload.Directories[0]
        Add-Type -Path (Get-ChildItem (Split-Path ($Pkg.location) -Parent) -Filter "$PreReq.dll" -Recurse -File)[0].FullName
    } 
}