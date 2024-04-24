Function Start-ApplicationInstall() {
    Parm(
        [Parameter(Mandatory=$True)]
            $Applications
    )

    $ApplicationLibrary = Import-ApplicationLibrary

    ForEach ($Applciation in $Applications) {
        
        $ApplicationSettings = $ApplicationLibrary | Where-Object { $_.Name -eq $_ }
        If (!($ApplicationSettings)) {
            Throw "Application $_ not found in library"
        }

        $ApplicationPath = (Join-Path $Script:Environment.Paths.Software "$_").Replace("[Software]", $Script:Environment.Paths.Software)
        If (!(Test-Path $ApplicationPath)) {
            New-ItemWrapper -Path $ApplicationPath
        }

        Switch ($ApplicationSettings.Source) {
            "Evergreen" {
                Get-ApplicationEvergreen -Application $ApplicationSettings -Path $ApplicationPath
            }

            "Download" {
                Get-ApplicationDownload -Application $ApplicationSettings -Path $ApplicationPath
            }

            "Path" {
                Get-ApplicationPath -Application $ApplicationSettings -Path $ApplicationPath
            }

            "Script" {
                Get-ApplicationScript -Application $ApplicationSettings -Path $ApplicationPath
            }
        }
    }
}