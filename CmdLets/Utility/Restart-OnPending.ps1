<#
    This checks for PendingFileRenames and reboots if any are found
    Important for: Horizon Agent, SolidWorks
#>
Function Restart-OnPending() {
    $ControlSets = Get-ChildItem "hklm:\system\*control*"
    foreach ($ControlSet in $ControlSets) {
        $Path = (join-path $ControlSet "Control\Session Manager").Replace("HKEY_LOCAL_MACHINE","HKLM:")
        $Manager = Get-Item $Path
        If ($Manager.Property -Contains "PendingFileRenameOperations" -or $Manager.Property -Contains "FileRenameOperations") {
            for ($i=0; $i -lt 30; $i++){
                Write-Progress -Activity "Pending File Rename operations detected" -Status "Rebooting in $(30-$i) seconds"
                start-sleep -seconds 1
            }
            Restart-Computer
        }
    } 
}