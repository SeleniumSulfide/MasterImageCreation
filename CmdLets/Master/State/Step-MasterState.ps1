Function Step-MasterState() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            $State
    )

    $State.Phase++
    Write-Verbose "Phase: $($State.Phase)"
    Set-MasterState -State $State
}