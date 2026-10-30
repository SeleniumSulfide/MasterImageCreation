Function Get-MasterState {
    <#
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            [String[]]$Name
    )
    #>
    $Path = "HKLM:\system\CurrentControlSet\Control\Session Manager\Environment"
    If ((Get-Item $Path).Property.Contains("State")) {
        $State = (Get-ItemPropertyValue -Path $Path -Name "State") | ConvertFrom-Json
        Write-Verbose "Found $State"
    }
    $State
}