Param(
    [Parameter()]
        #Only use for the Supplemental, expected is none
        [String]$ConfigFile,

    [Parameter()]
        [ValidateSet("Dallas","Ashburn")]
        [String]$DC,

    [Parameter()]
        [Switch]$JoinAAD,
    
    [Parameter()]
        [Switch]$Pause,

    [Parameter()]
        [String]$Global:LocalRoot="C:\Temp",

    [Parameter()]
        [String]$Global:RemoteRoot="\\contoso.com\horizon\Master"
)
<#
    #To configure this script highlight and run the BELOW section with appropriate values
        
        $Global:State = {
            ConfigFile = ""
            DC = "SRVVIEWC01"
            JoinAAD = $False
            Pause = [Switch]::Present
        }
    #To configure this script highlight and run the ABOVE section with appropriate values

    Then highlight the rest of the script and press F8
#>




<#
    Set the path to the Environment Variables
    If there is not a State Environment Variable, this is Phase 0
        Create "Run" property so script runs on boot
        Create "State" Environment variable to read
#>
$Global:EnvironmentVariables = "HKLM:\system\CurrentControlSet\Control\Session Manager\Environment"
if (!(Get-Item $EnvironmentVariables).Property.Contains("State")) {
    $Value = @{
        ConfigFile = $ConfigFile
        DC = $DC
        Phase = 0
        JoinAAD = $JoinAAD.IsPresent
        Pause = $Pause.IsPresent
    } | ConvertTo-Json
    New-ItemProperty -Path $EnvironmentVariables -Name "State" -Value $Value -PropertyType "MultiString" | Out-Null

    $Run = "hklm:\software\microsoft\windows\currentversion\run"
    New-ItemProperty -path $Run -Name "*Image" -Value "C:\Temp\Scripts\Start-BaseCreation.bat" -PropertyType String | Out-Null
}

If (!$Global:State) {
    $Global:State = (Get-ItemPropertyValue -Path $EnvironmentVariables -Name "State") | ConvertFrom-Json
}

<#
    Logs Commands ran in the PS Session should they need reviewed later
#>
Start-Transcript -Path (Join-Path $LocalRoot "Phase-$($State.Phase).log") -Append -Force

<#
    Change the Execution Policy to allow custom code
    Import the Creation-Base.PSM1
#>
Set-ExecutionPolicy Bypass -Scope LocalMachine -Force
If ($MyInvocation.MyCommand.Path) {
    $Global:CommandPath = Split-Path $MyInvocation.MyCommand.Path -Parent
} elseIf (Test-Path "c:\Temp\Scripts") {
    $Global:CommandPath = "C:\Temp\Scripts"
} else {
    $Global:CommandPath = "contoso.com\Horizon\Master\Scripts"
}
Import-Module (Join-Path $CommandPath "Creation-Base.psm1") -ErrorAction Stop

<#
    Read the Environment.JSON that is stored with the PowerShell Script
    If specified, reads the ConfigFile stored with the PowerShell Script
#>
$Global:Environment = Get-Content (Join-Path $CommandPath "Environment.json") | ConvertFrom-Json
If ($State.ConfigFile) { $Global:Config = Get-Content -Path (Join-Path $CommandPath $State.ConfigFile) | ConvertFrom-Json }

#Merges global settings from the Environment and Overlay files
$Global:Variables = @($Config.Variables + $Environment.Variables)
$FileShares       = If ($State.Shares) { $State.Shares } else { @($Config.FileShares + $Environment.FileShares) }

#Merges Phase specific commands for Each step of the Phase from the Base Environment config and any overlay Configs
$PreScriptBlocks  = @($Config.Phases.($State.Phase).PreScriptBlocks  + $Environment.Phases.($State.Phase).PreScriptBlocks)
$Applications     = @($Config.Phases.($State.Phase).Applications     + $Environment.Phases.($State.Phase).Applications)
$RegistrySettings = @($Config.Phases.($State.Phase).RegistrySettings + $Environment.Phases.($State.Phase).RegistrySettings)
$PostScriptBlocks = @($Config.Phases.($State.Phase).PostScriptBlocks + $Environment.Phases.($State.Phase).PostScriptBlocks)

<#
    Process the resultant set of entries from the JSONs
#>
If ($State.Pause) {Read-Host "Pausing before Phase: $($State.Phase), Press Enter to continue"}

Initialize-PreReqs                                        #Ensures the PSSession has all necessary components initialized
Initialize-Variables  -Variables        $Variables        #Creates or sets all variables
Connect-FileShares    -FileShares       $FileShares       #Connects any fileshares necessary for later phases
Invoke-ScriptBlocks   -ScriptBlocks     $PreScriptBlocks  #Executes the PreScriptBlocks for the current phase
Install-Applications  -Applications     $Applications     #Installs applications for thed Phase
Sync-RegistrySettings -RegistrySettings $RegistrySettings #Sets registry settings for the current phase
Invoke-ScriptBlocks   -ScriptBlocks     $PostScriptBlocks #Executes the PostScriptBlocks for the current phase