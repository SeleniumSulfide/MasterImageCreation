Function Start-ApplicationInstall() {
    Parm(
        [Parameter(Mandatory=$True)]
            $Applications
    )

    Import-ApplicationLibrary

    ForEach ($Application in $Applications) {
        $ApplicationSettings = $ApplicationLibrary | Where-Object { $_.Name -eq $Application }
        If (!($ApplicationSettings)) {
            Throw "Application $Application not found in library"
        }

        $ApplicationPath = (Join-Path $Script:Environment.Paths.Software $Application)
        If (!(Test-Path $ApplicationPath)) {
            New-ItemWrapper -Path $ApplicationPath
        }

        Switch ($ApplicationSettings.Source) {
            "Evergreen" {
                Get-ApplicationEvergreen -Application $ApplicationSettings.Evergreen -Path $ApplicationPath
            }

            "Download" {
                Get-ApplicationDownload -Application $ApplicationSettings.Download -Path $ApplicationPath
            }

            "FileSystem" {
                If ($ApplicationSettings.Copy) {
                    Get-ApplicationPath -Application $ApplicationSettings.FileSystem -Path $ApplicationPath
                } else {
                    $ApplicationPath = $ApplicationSettings.FileSystem.Path.Replace("[Software]", $Script:Environment.Paths.Software)
                }
            }

            "Script" {
                Get-ApplicationScript -Application $ApplicationSettings.Script -Path $ApplicationPath
            }
        }

        Install-Application -Application $ApplicationSettings.Installation -Path $ApplicationPath
    }
}