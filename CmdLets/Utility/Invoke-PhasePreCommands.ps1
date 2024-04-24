Function Invoke-PhasePreCommands() {
    Param(
        [Parameter(Mandatory=$true)]
        [Int]$Phase
    )

    Switch ($Phase) {
        0 {
            Get-CopyItems -Items $CopyItems
            Install-Drivers $Environment.Paths.Drivers
            Initialize-PrinterDrivers $Environment.PrinterDrivers
            Initialize-ZebraDrivers $Environment.ZebraDrivers
            Get-ChildItem (Join-Path $Environment.Fonts.Path "*.?tf") -recurse | ForEach-Object { Add-Font -Path $_.Fullname }
        }
        1 {
            Update-Windows -Reboot
        }
        2 {
            Restart-OnPending
        }
        3 {
            if ((get-service W32Time).Status -ne "Running") { 
                Start-Service -Name W32Time 
            }
            C:\windows\system32\w32tm.exe /config /update /manualpeerlist:domain.local
            C:\Windows\System32\w32tm.exe /resync /rediscover
        }
        4 {}
    }
}