Function Step-Phase() {
    $State.Phase++
    Set-ItemProperty -Path $EnvironmentVariables -Name "State" -value ($State | ConvertTo-Json)
}