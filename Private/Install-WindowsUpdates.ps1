function Install-WindowsUpdates {
    Param (
        [Parameter(Mandatory=$True)]$Updates,
        [Parameter(Mandatory=$True)]$Session,
        [Parameter(Mandatory=$false)][Switch]$IncludeFeatureUpdate
    )
    $Reboot = $False
    $Installer = $Session.CreateUpdateInstaller()
    $Updates | ForEach-Object {
        $i++
        $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
        
        if ($IncludeFeatureUpdate.IsPresent -and $_.isdownloaded) { # 
            Write-Host "Installing update $i of $($Updates.Count()): $($_.Title)"
            $UpdatesToInstall.Add($_) | out-null
            $Installer.Updates = $UpdatesToInstall
            $Result = $Installer.Install()
            if ($Result.RebootRequired) { $Reboot = $true }

        } elseif ($_.isdownloaded -and $_.Title -NotLike "*Feature Update*") {
            Write-Host "Installing update $i of $($Updates.Count()): $($_.Title)"
            $UpdatesToInstall.Add($_) | out-null
            $Installer.Updates = $UpdatesToInstall
            $Result = $Installer.Install()
            if ($Result.RebootRequired) { $Reboot = $true }

        } else {
            Write-Host "Skipping update $i of $($Updates.Count()): $($_.Title)"
        }
    }
    Return $Reboot 
}
