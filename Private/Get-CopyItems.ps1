Function Get-CopyItems() {
    Param(
        [Parameter(Mandatory=$True)]
            $Items
    )
    $Items | ForEach-Object { Copy-ItemWrapper -Path $_.Source -Destination $_.Destination }
}