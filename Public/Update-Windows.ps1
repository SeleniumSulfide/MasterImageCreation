function Update-Windows {
    Param(
        [Parameter()][Switch]$Reboot,
        [Parameter()][Switch]$IncludeDrivers,
        [Parameter()][Switch]$IncludeFeatureUpdate,
        [Parameter()][Switch]$Confirm
    )
    try {
        Write-Host "Creating Update Session"
        $Session = New-Object -Com Microsoft.Update.Session
        Write-Host "Beginning Windows Updates"
        $Updates = Get-WindowsUpdates $Session -IncludeDrivers:$IncludeDrivers.IsPresent

        if ($updates.count -eq 0) {
            Write-Host "No Updates Found"
        } else {
            if ($Confirm.IsPresent) {
                $Updates | Select-Object -Property Title
                Do {
                    $Response = (Read-Host "Proceed with install (Y/N)").ToUpper()
                } While ($Respone -ne "Y" -or $Response -ne "N")
                If ($Response -eq "N") { Break }
            }
            Write-Host "Updates Found"
            Sync-WindowsUpdates -Updates $Updates -Session $Session -IncludeFeatureUpdate:$IncludeFeatureUpdate.IsPresent
            
            $Restart = Install-WindowsUpdates -Updates $Updates -Session $Session -IncludeFeatureUpdate:$IncludeFeatureUpdate.IsPresent
        }

        if ($Restart -and $Reboot.IsPresent) {
            Restart-Computer
        } elseif ($Restart) {
            Write-Host "Restart Required" -ForegroundColor Red
        }
    } catch {
        Write-Host $_.tostring()
    } 
}
