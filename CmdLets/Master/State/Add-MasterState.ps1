Function Set-MasterState {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            $State
    )
    
    $Value = $State | ConvertTo-JSON
    $Path = "HKLM:\system\CurrentControlSet\Control\Session Manager\Environment"

    If ((Get-Item $Path).Property.Contains("State")) {
        Set-MasterState -State $State
    } else {
        New-ItemProperty -Path $Path -Name "State" -Value $Value -PropertyType "MultiString" | Out-Null
    }
}