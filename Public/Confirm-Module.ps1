Function Confirm-Module() {
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
            [String]$Module
    )

    $Module | ForEach-Object {
        if (Get-Module $_) {
            Update-Module -Name $_ -Force
        } else {
            Install-Module -Name $_ -AllowClobber -Force -Scope AllUsers
        }
    }
}