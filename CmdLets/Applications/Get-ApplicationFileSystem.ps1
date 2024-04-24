Function Get-ApplicationFileSystem() {
    Param(
        [Parameter(Mandatory=$True)]
        $Application,
        
        [Parameter(Mandatory=$True)]
        [System.IO.FileInfo]$Path
    )

    ForEach ($ScriptBlock in $Application.PreScriptBlocks) {
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }

    Copy-Item -Path $Application.Path -Destination $Path -Recurse -Force

    ForEach ($ScriptBlock in $Application.PostScriptBlocks) {
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }
}