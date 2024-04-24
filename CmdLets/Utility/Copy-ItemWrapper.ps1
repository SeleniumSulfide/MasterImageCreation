<#
    Over engineered copy-item from when I was having issues, could probably be removed
#>
Function Copy-ItemWrapper() {
    Param([Parameter(Mandatory=$True)][String]$Path,
            [Parameter(Mandatory=$True)][String]$Destination)
    if (!(test-path $Destination)) {
        New-ItemWrapper $Destination
    }
    Write-Host "Copying: $($Path)"
    Get-Item $Path | Copy-Item -Destination "$Destination" -Force -Recurse
}