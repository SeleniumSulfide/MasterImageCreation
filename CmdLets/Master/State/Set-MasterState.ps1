Function Set-MasterState {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            $State
    )
    
    $Value = $State | ConvertTo-JSON
    $Path = "HKLM:\system\CurrentControlSet\Control\Session Manager\Environment"

    If ((Get-Item $Path).Property.Contains("State")) {
        Write-Verbose "Setting State"
        Write-Verbose $Value
        Set-ItemProperty -Path $Path -Name "State" -Value $Value
    } else {
        Add-MasterState -State $State
    }
}