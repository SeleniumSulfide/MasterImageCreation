<#
    For print drivers to not need to be installed, they have to be "activated" with Add-PrintDriver
    This accepts the list specified in the main Environment.JSON
    To generate the list, run Get-PrinterDriverList.PS1 -Server <ServerName>
#>
Function Initialize-PrinterDrivers(){
    Param(
        [Parameter(Mandatory=$True)]$PrinterDrivers
    )
    ForEach ($PrinterDriver in $PrinterDrivers) {
        If (!(Get-PrinterDriver -Name PrinterDriver -ErrorAction SilentlyContinue)) {
            Write-Host "Adding PrinterDriver: $($PrinterDriver)"
            Add-PrinterDriver -Name $PrinterDriver
        }
    }
}