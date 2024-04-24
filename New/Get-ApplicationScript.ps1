Function Get-ApplciationScript() {
    Param(
        [Parameter(Madatory=$True)]
        $Application,
        
        [Parameter(Mandatory=$True)]
        [System.IO.FileInfo]$Path
    )

    ForEach ($Module in $Application.Modules) {
        Install-Module $Module -Force -ErrorAction Stop
    }

    ForEach ($ScriptBlock in $Application.ScriptBlocks) {
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }
}