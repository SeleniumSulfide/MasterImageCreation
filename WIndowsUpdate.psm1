function Update-Windows {
    Param(
        [Parameter()][Switch]$Reboot
    )
    try {
        Write-Host "Creating Update Session"
        $Session = New-Object -Com Microsoft.Update.Session
        Write-Host "Beginning Windows Updates"
        $Updates = Get-WindowsUpdates $Session
        if ($updates.count -eq 0) {
            Write-Host "No Updates Found"
        } else {
            Write-Host "Windows Updates Found"
            Sync-WindowsUpdates -Updates $Updates -Session $Session
            $WURestart = Install-WindowsUpdates -Updates $Updates -Session $Session
        }
        if ($WURestart -and $Reboot.IsPresent) {
            Restart-Computer
        } elseif ($WURestart) {
            Write-Host "Restart Required" -ForegroundColor Red
        }
    } catch {
        Write-Host $_.tostring()
    } 
}

function Get-WindowsUpdates {
    Param(
        [Parameter(Mandatory=$True)]$Session
    )
    $Searcher = $Session.CreateUpdateSearcher()
    Write-Host "Searching for Windows Updates"
    #$searcher.serviceid = '9482f4b4-e343-43b6-b170-9a65bc822c77'
    $Criteria = "IsInstalled=0 and IsHidden=0 and Type='Software'"
    $SearchResult = $Searcher.Search($Criteria)
    $Updates = $SearchResult.Updates
    return , $Updates 
}

function Install-WindowsUpdates {
    Param (
        [Parameter(Mandatory=$True)]$Updates,
        [Parameter(Mandatory=$True)]$Session
    )
    $Reboot = $False
    $Installer = $Session.CreateUpdateInstaller()
    $Updates | ForEach-Object {
        $i++
        $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
        if ($_.isdownloaded -and $_.Title -NotLike "*Feature Update*") {
            Write-Host "Installing update $i of $($Updates.Count()): $($_.Title)"
            $UpdatesToInstall.Add($_) | out-null
            $Installer.Updates = $UpdatesToInstall
            $Result = $Installer.Install()
            if ($Result.RebootRequired) { $Reboot = $true }
        }
    }
    Return $Reboot 
}

function Sync-WindowsUpdates {
    Param (
        [Parameter(Mandatory=$True)]$Updates,
        [Parameter(Mandatory=$True)]$Session
    )
    $Downloader = $Session.CreateUpdateDownloader()
    $Updates | ForEach-Object {
        $i++
        Write-Host "Downloading $i of $($Updates.Count()): $($_.Title)"
        $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
        if ($_.Title -NotLike "*Feature Update*")
        {
            $updatesToDownload.Add($_) | out-null
        }
        $Downloader.Updates = $UpdatesToDownload
        $Downloader.Download() | out-null
    } 
}