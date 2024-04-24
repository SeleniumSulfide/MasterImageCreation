function Sync-WindowsUpdates {
    Param (
        [Parameter(Mandatory=$True)]$Updates,
        [Parameter(Mandatory=$True)]$Session,
        [Parameter(Mandatory=$false)][Switch]$IncludeFeatureUpdate
    )

    $Downloader = $Session.CreateUpdateDownloader()
    $Updates | ForEach-Object {
        $i++
        Write-Host "Downloading $i of $($Updates.Count()): $($_.Title)"
        $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
        if ($_.Title -NotLike "*Feature Update*" -or $IncludeFeatureUpdate.IsPresent -eq $False)
        {
            $updatesToDownload.Add($_) | out-null
        }
        $Downloader.Updates = $UpdatesToDownload
        $Downloader.Download() | out-null
    } 
}