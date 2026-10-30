Function Export-Templates() {
        [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            [System.IO.FileInfo]$Path,
        [Parameter(Mandatory=$false)]
            [ValidateSet("v1","v2")]
            $Version="v2",
        [Parameter(Mandatory=$False)]
            [Switch]$Force
    )
    $Module = Get-Module MasterImageCreation -ListAvailable
    Write-Verbose "Found Module"
    Write-Verbose $Module
    $Source = Join-Path (Split-Path $Module.Fullname -Parent) "Samples\$Version\*"
    Write-Verbose "Source: $Source"
    
    Copy-Item -Path $Source -Destination $Path -Force:$Force.IsPresent
}