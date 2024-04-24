Function Import-ApplicationLibrary() {
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
            [System.IO.FileInfo]$Path = $Script:Environment.Paths.ApplicationLibrary
    )

    $Files = Get-childItem (Join-Path $Path "*.json")
    $Script:ApplicationLibrary = @()
    ForEach ($File in $Files) { 
        $ApplicationLibrary += Get-Content $file.Fullname | ConvertFrom-Json
    }
}