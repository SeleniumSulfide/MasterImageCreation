<#
    This accepts an Array of RegistrySettings as defined in the JSON
    If the Property doesn't exist it is created with the specified value
    If the Property DOES exist, it is set to the value specified
    If there are ScriptBlocks specified they are ran. SBs are used here to modify the setting dynamically for things like AppVol Managers
#>
Function Sync-RegistrySettings() {
    Param(
        [Parameter(Mandatory=$True)]
            $RegistrySettings
    )

    ForEach ($RegistrySetting in $RegistrySettings) {
        ForEach ($ScriptBlock in $RegistrySettings.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        if (!(Test-Path $RegistrySetting.Path )) {
            New-ItemWrapper $RegistrySetting.Path 
        }
        Write-host $RegistrySetting.Name
        If ((Get-Item $RegistrySetting.Path).Property -Contains $RegistrySetting.Name) {
            Set-ItemProperty `
                -Path $RegistrySetting.Path `
                -Name $RegistrySetting.Name `
                -Value $RegistrySetting.Value
        } else {
            New-ItemProperty `
                -Path $RegistrySetting.Path `
                -Name $RegistrySetting.Name `
                -Value $RegistrySetting.Value `
                -PropertyType $RegistrySetting.Type | out-null
        }
        ForEach ($ScriptBlock in $RegistrySettings.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }
}