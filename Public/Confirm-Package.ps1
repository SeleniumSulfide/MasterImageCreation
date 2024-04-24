Function Confirm-PreReq() {
    Param(
        [Parameter(Mandatory=$true)][String]$Package,
        [Parameter(Mandatory=$true)][String]$ProviderName
    )

    if ((get-package | where-object -property name -eq $Package)) {
        Write-Host "Package found: $Package"
        return $True
    } else {
        Write-Host "Installing Package: $Package"
        $pkg = (Install-Package $Package -ProviderName $ProviderName -Scope AllUsers -Force -SkipDependencies).Payload.Directories[0]
        Add-Type -Path (Get-ChildItem (Split-Path ($Pkg.location) -Parent) -Filter "$PreReq.dll" -Recurse -File)[0].FullName
    }
}