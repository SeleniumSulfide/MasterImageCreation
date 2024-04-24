<#
    This consumes the Evergreen section of the Environment.JSON and downloads the software specified
    Evergreen is an Opensource Powershell module
    https://stealthpuppy.com/evergreen/
#>
Function Get-AppsEvergreen() {
    Param(
        [Parameter(Mandatory=$True)]
            $Applications,
        [Parameter(Mandatory=$True)]
            [System.IO.FileInfo]$DownloadPath
    )

    ForEach ($Application in $Applications) {
        ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        $EvergreenApp = Get-EvergreenApp -Name $Application.EverGreenApp
        If ($Application.Filter -ne "") { 
            $Filter = [ScriptBlock]::Create($Application.Filter)
            $EvergreenApp = ($EvergreenApp | Where-Object -FilterScript $Filter)[0]
        }

        $File = Split-Path -Path $EvergreenApp.Uri -Leaf
        $Destination = Join-Path -Path $DownloadPath -ChildPath $Application.EvergreenApp
        $OutFile = Join-Path -Path $Destination -ChildPath ([system.uri]::UnescapeDataString($File))
        if (!(Test-Path $Destination)) { New-ItemWrapper -Path $Destination }

        if (!(Test-Path $OutFile)) {
            Write-Host "Evergreen: $($Application.EvergreenApp)"
            Invoke-WebRequest -UseBasicParsing -Uri $EvergreenApp.uri -OutFile $OutFile
        }
        ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }
}