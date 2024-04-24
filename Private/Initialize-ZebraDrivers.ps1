<#
    As Zebra Print drivers are difficult, you have to use a different method to make them work
    This Function accepts the ZebraPrinters from the Environment.JSON
    List of Drivers can be obtained from the printerserver using Get-PrinterDriverList.psa -Server <servname> -Filterscript {$_.DriverName -like "Zebra*"}
        
#>
Function Initialize-ZebraDrivers(){
    Param(
        [Parameter(Mandatory=$True)]$PrinterDrivers
    )
    $DriverWizard = Get-ChildItem $Script:Environment.ZebraDrivers.DriverWizard
    $PrinterDrivers | ForEach-Object {
        Write-Host "Adding PrinterDriver: $_"
        Start-Process -FilePath $DriverWizard.FullName -ArgumentList "install /name:`"$($_)`" /model:`"$($_)`" /port:`"FILE:`"" -WAIT
    }
    Remove-Printer -Name "Zebra*"
}

