Function Get-ApplicationPath() {
    Param(
        [Parameter(Mandatory=$True)]
        $Application,
        
        [Parameter(Mandatory=$True)]
        [System.IO.FileInfo]$Path
    )
}