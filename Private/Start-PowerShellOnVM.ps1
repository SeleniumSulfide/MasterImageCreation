Function Start-PowerShellOnVm {
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]$Base
    )
    $VMView = $Base.VM | Get-View #-Server $Base.Server
    Send-VMKeys -VM $VMView -StringInput "r" -LeftGUI
    Send-VMKeys -VM $VMView -StringInput "cmd" -SpecialKeyInput "Enter"
    Start-Sleep -Seconds 1
    Send-VMKeys -VM $VMView -StringInput "powershell" -SpecialKeyInput "Enter"
    Start-Sleep -Seconds 5
    Send-VMKeys -VM $VMView -StringInput "Set-ExecutionPolicy Bypass -Scope LocalMachine -Force" -SpecialKeyInput "Enter" 
}