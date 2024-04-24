<#
    This accepts an array of PowerShell Commands and executes them in sequence
    Unfortunately you can't use this within other functions as doing so changes the scope which doesn't allow for variable manipulation
#>
Function Invoke-ScriptBlocks() {
    Param(
        [Parameter(Mandatory=$true)]$ScriptBlocks
    )

    ForEach ($ScriptBlock in $ScriptBlocks) {
        Write-Host $ScriptBlock
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }
}