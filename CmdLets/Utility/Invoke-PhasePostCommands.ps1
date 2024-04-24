Function Invoke-PhasePostCommands() {
    Param(
        [Parameter(Mandatory=$true)]
        [Int]$Phase
    )

    Switch ($Phase) {
        0 {
            Get-Service -Name wuauserv | Restart-Service
            Get-WindowsCapability -Name "RSAT.*" -Online | ForEach-Object { Write-Host $_.Name; Add-WindowsCapability -Name $_.Name -Online | out-null; }
            Update-Help
            Step-Phase
            Update-Windows -Reboot
        }
        1 {
            Get-Service -Displayname *edge* | Set-Service -StartupType Disabled
            Get-Process -Name *EdgeUpdate* | Stop-Process -Force
            Rename-Item -Path "C:\Program Files (x86)\Microsoft\EdgeUpdate" -NewName "EdgeUpdate.disabled"
            Get-Item "C:\Program Files (x86)\Microsoft\Edge\Application\*\elevation_service.exe" | Rename-Item -NewName "elevation_service.disabled.exe"
            Get-ScheduledTask -TaskName *edge* | Disable-ScheduledTask
            Step-Phase
            Restart-Computer
        }
        2 {
            PowerShell.exe -NonInteractive -Command { & (Join-Path $Environment.Paths.Working "Optimization Tool\LGPO.exe") /r (Join-Path $Environment.Paths.Working "Optimization Tool\New_MachineRegPol.txt") /w "C:\Windows\System32\GroupPolicy\Machine\Registry.pol" }
            PowerShell.exe -NonInteractive -Command { & (Join-Path $Environment.Paths.Working "Optimization Tool\LGPO.exe") /r (Join-Path $Environment.Paths.Working "Optimization Tool\New_UserRegPol.txt") /w "C:\Windows\System32\GroupPolicy\User\Registry.pol" }
            PowerShell.exe -NonInteractive -Command { & (Join-Path $Environment.Paths.Working "Optimization Tool\VMwareOSOptimizationTool.exe") -v -optimize -VisualEffect Balanced -Notification disable -WindowsUpdate Disable -OfficeUpdate Disable -StoreApp remove-all --Exclude Camera Calculator Photos StickyNotes WebExtension -Firewall Disable -Antivirus Disable -SecurityCenter Disable -WindowsSearch searchboxasicon }
            PowerShell.exe -NonInteractive -Command { & (Join-Path $Environment.Paths.Working "Optimization Tool\VMwareOSOptimizationTool.exe") -g }
            Step-Phase
            Restart-Computer
        }
        3 {
            ForEach ($Package in $Environment.AppXRemoval) { 
                Get-AppXProvisionedPackage -Online | `
                    Where-Object { 
                        $_.DisplayName -eq $Package.Name 
                    } | `
                        ForEach-Object { 
                            Remove-AppXProvisionedPackage -Online -PackageName $_.PackageName 
                        } 
            }
            $Environment.AppXRemoval | `
                ForEach-Object { 
                    Get-AppXPackage -Name $_.Name | Remove-AppXPackage 
                }
            PowerShell.exe -NonInteractive -Command { & (Join-Path $Environment.Paths.Working "Optimization Tool\VMwareOSOptimizationTool.exe") -Finalize 0 1 2 3 4 5 6 }
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
            dism /online /cleanup-image /scanhealth
            dism /online /cleanup-image /checkhealth
            dism /online /cleanup-image /restorehealth
            dism /online /cleanup-image /startcomponentcleanup /resetbase
            sfc /scannow
            Step-Phase
            Restart-Computer
        }
        4 {
            Get-ChildItem "c:\users\Public\Desktop\*.lnk" | Remove-Item -Force
            Remove-Item $Environment.Paths.Software -Recurse -Force
            If (Test-Path C:\Maint\Drivers) { 
                Remove-Item (Join-Path $Environment.Paths.Working "Drivers") -Recurse -Force 
            }
            defrag C: /PrintProgress
            #New-LocalUser -name "AppCap" -password (ConvertTo-SecureString -String "" -AsPlainText -Force) -PasswordNeverExpires -UserMayNotchangePassword
            Add-LocalGroupMember -group "Administrators" -Member "AppCap"
            #Set-LocalUser -Name "Administrator" -Password (ConvertTo-SecureString -String "" -AsPlainText -Force)
            $Run = "hklm:\software\microsoft\windows\currentversion\run"
            If ((Get-Item $Run).Property -contains "*Image") { 
                Remove-ItemProperty -Path $Run -Name "*Image" 
            }
            Get-NetFirewallProfile | Where-Object -Property Enabled -eq $true | Set-NetFirewallProfile -Enabled False -Confirm:$False
            PowerShell.exe -NonInteractive -Command { & (Join-Path $Environment.Paths.Working "Optimization Tool\VMwareOSOptimizationTool.exe") -Finalize All }
            Stop-Computer
        }
    }
}