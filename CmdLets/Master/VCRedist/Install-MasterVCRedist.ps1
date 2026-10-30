Function Install-MasterVCRedist() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline)]
            $Releases,
        [Parameter(Mandatory=$True)]
            $Path
    )
    Begin{
        If (!(Test-Path $Path)) { 
            New-ItemWrapper $Path 
        }
    }
    Process{
        $Redists = Get-VCList -Export All | Where-Object { $_.Architecture -ne "ARM64" -and $_.Release -in $Releases }
        $Versions = ForEach ($Release in $Releases) {
                ($Redists | `
                    Where-Object { $_.Release -eq $Release } | `
                    Select-Object -Property Version | `
                    Sort-Object -Property Version -Unique)[-1].Version
            }
        $Redists | `
            Where-Object { $_.Version -in $Versions } | `
            Save-VcRedist -Path $Path | `
            Install-VcRedist -Silentinstall
        
    }
    End{
        
    }
}