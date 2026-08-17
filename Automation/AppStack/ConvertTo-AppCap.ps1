<#
Uninstall
    Cortex XDR - 6Ri108Ce#tuwuzun
    Microsoft OneDrive
    Teams Machine-Wide Installer
    Horizon Agent
    DEM

Install
    DEM Profiler
    Repair VMWare Tools - \\smcusa.com\files\it\vdi\<The Tools .ISO>

Misc
    Create Local Admin account
        AppCap - D@ffyduck82
    Disable ClickToRun service
#>

#Disable Cortex
    $WShell = New-Object -ComObject WScript.Shell
    Start-Process cmd.exe '/k cd "C:\program files\Palo Alto Networks\Traps"'
    Start-Sleep -Seconds 3
    $WShell.SendKeys("cytool.exe protect disable{enter}")
    Start-Sleep -Seconds 1
    $WShell.SendKeys("6Ri108Ce#tuwuzun{enter}")
    $WShell.SendKeys("Exit{enter}")
    #Run Installer

#Teams
    #MsiExec.exe /I{731F6BAA-A986-45A4-8936-7C3AAAAA760B}
    & "C:\Program Files (x86)\Microsft\Teams\Update.exe" --uninstall
    Get-Service -Name ClickToRunSvc | Set-Service -StartupType Disabled
    
#Create AppCap user, set password, add to Local Admins
#Create Computer account at VDI > <DC> > VMs
#Join Domain - Reboot
#Shutdown - Snap