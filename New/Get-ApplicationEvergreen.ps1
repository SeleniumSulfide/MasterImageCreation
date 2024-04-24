Function Get-ApplicationEvergreen() {
    Param(
        [Parameter(Madatory=$True)]
        $Application,
        
        [Parameter(Mandatory=$True)]
        [System.IO.FileInfo]$Path
    )

    ForEach ($ScriptBlock in $Application.PreScriptBlocks) { 
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }

    $EvergreenApp = Get-EvergreenApp -Name $Application.EverGreenApp

    If ($Application.Filter -ne "") { 
        $Filter = [ScriptBlock]::Create($Application.Filter)
        $EvergreenApp = ($EvergreenApp | Where-Object -FilterScript $Filter)[0]
    }

    $File = Join-Path -Path $Path -ChildPath ([System.Uri]::UnescapeDataString((Split-Path -Path $EvergreenApp.Uri -Leaf)))

    if (!(Test-Path $File)) {
        Write-Host "Evergreen: $($Application.EvergreenApp)"
        Invoke-WebRequest -UseBasicParsing -Uri $EvergreenApp.uri -OutFile $File
    }
    
    ForEach ($ScriptBlock in $Application.PostScriptBlocks) { 
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }

}