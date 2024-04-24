Function Get-VCRedist() {
    Param(
        [Parameter(Mandatory=$true)]
            [System.IO.FileInfo]$DownloadPath
    )
    $VCRedistPath = Join-Path $DownloadPath "VCRedist"
    New-ItemWrapper $VCRedistPath
    Get-VCList | Save-VCRedist -Path $VCRedistPath
}