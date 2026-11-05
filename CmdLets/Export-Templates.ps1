Function Export-Templates() {
<#
.SYNOPSIS
    Exports the basics files that enables the bootstrapping of a Windows Deskop

.DESCRIPTION


.PARAMETER Path
    Folder where files will be copied

.PARAMETER Version
    Version of the files that will be copied. Default is latest.

.PARAMETER Force
    Force will overwrite any existing files

.INPUTS
    None

.OUTPUTS
    None

.EXAMPLE
    PS> Export-Templates -Path \\fs.contoso.com\Horizon\Master

.EXAMPLE
    PS> Export-Templates -Path \\fs.contoso.com\Horizon\Master -Force

.EXAMPLE
    PS> Export-Templates -Path \\fs.contosoc.om\Horizon\Master -Version v1 -Force

#>
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
    $Source = Join-Path $PSScriptRoot "..\Samples\$Version\*"
    Write-Verbose "Source: $Source"
    Copy-Item -Path $Source -Destination $Path -Force:$Force.IsPresent
}