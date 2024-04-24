Function Get-ApplicationDownload() {
    Param(
        [Parameter(Mandatory=$True)]
        $Application,
        
        [Parameter(Mandatory=$True)]
        [System.IO.FileInfo]$Path
    )

    ForEach ($URI in $Application.URI) {
        #Don't use Invoke-ScriptBlocks as that changes the scope
        ForEach ($ScriptBlock in $Application.PreScriptBlocks) { 
            Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
       }
        
        if ($Application.FileName) {
            $File = Join-Path $Destination $Application.FileName
        } else {
            $File = Join-Path $Destination (Split-Path $URI -Leaf)
        }

        If (!(Test-Path $File)) {
            Write-Host "Download: $($Application.Name)"
            Invoke-WebRequest -UseBasicParsing -Uri $URI -OutFile $File
        }
        
        ForEach ($ScriptBlock in $Application.PostScriptBlocks) { 
           Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
        }
    }
}