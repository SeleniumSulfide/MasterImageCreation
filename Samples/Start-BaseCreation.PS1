Param(
    [Parameter()]
        #[ValidateSet("x86","x64")]
        [String]$ConfigFile,

    [Parameter()]
        [ValidateSet("Pod1","Pod2")]
        [String]$Pod,

    [Parameter()]
        [Switch]$JoinAAD
)
<#-
To configure this script, set the HorizonAgent, OfficeArch, OfficeVer, DataCenter (POD), etc
    to the desired values, highlight all, Press F8 or click the "Run Selection (F8)" button 
    in the ribbon
#>
<#
    Set the path to the Environment Variables
    If there is a State environment variable, use it
    Otherwise, use what was passed into the script
#>
$Script:EnvironmentVariables = "HKLM:\system\CurrentControlSet\Control\Session Manager\Environment"
if ((Get-Item $EnvironmentVariables).Property.Contains("State")) {
    $Json = Get-ItemPropertyValue -Path $EnvironmentVariables -Name "State"
    $Script:State = $Json | ConvertFrom-Json
} else {
<#
    Add Script to Run so that it will continue after reboot
#>
    $Run = "hklm:\software\microsoft\windows\currentversion\run"
    New-ItemProperty -path $Run -Name "*Image" -Value "Powershell.exe C:\Maint\powershell\Start-BaseCreation.ps1" -PropertyType String

    $Script:State = @{
        ConfigFile = $ConfigFile
        POD = $Pod
        Phase = 0
    }
    $Json = $State | ConvertTo-Json
    New-ItemProperty -Path $EnvironmentVariables -Name "State" -Value $Json -PropertyType "MultiString"
}

<#
    Some Registry Settings are in HKEY_Classes_Root
    This adds the PSDrive so the rest of the script can interact with it
#>
If (!(Test-Path HKCR:\)){
    New-PSDrive -Name "HKCR" -PSProvider Registry -Root "HKEY_Classes_Root"
}



<#
    Change the Execution Policy to allow custom code
    Import the Windows Update
#>
Set-ExecutionPolicy Bypass -Scope LocalMachine -Force

<#
    Uncomment If/Else statements for execution outside of calling the .PS1
#>
#If ($MyInvocation.MyCommand.Path) {
    $CommandPath = Split-Path $MyInvocation.MyCommand.Path -Parent
#} else {
#    $CommandPath = "\\domain.local\files\it\vdi\maint\powershell\"
#}
Import-Module (join-path $CommandPath "WindowsUpdate.PSM1")

<#
    Read the Environment.JSON that is stored with the PowerShell Script
    If specified, reads the ConfigFile stored with the PowerShell Script
#>
$Script:Environment = Get-Content (Join-Path $CommandPath "Environment.json") | ConvertFrom-Json
If ($State.ConfigFile) { $Script:Config = Get-Content -Path (Join-Path $CommandPath $State.ConfigFile) | ConvertFrom-Json }

<#
    Logs Commands ran in the PS Session should they need reviewed later
#>
Start-Transcript -Path (Join-Path $Environment.Paths.Working "BuildTranscript.log") -Append -Force

<#
    Set the location of where to find/download software to the path specified in Environment.JSON
#>
$Script:SoftwarePath = $Environment.Paths.Software
$Script:FontPath = $Environment.Paths.FontPath

<#
    This sets FileShares to what's been stored in $State if it exists, otherwise uses the Environment/ConfigFile JSONs
    Only Phase 0 should use the values from Config and Environment
#>
if ($State.Shares) {
    $FileShares = $State.Shares
} else {
    $FileShares = @($Config.FileShares + $Environment.FileShares)
}

<#
    If a ConfigFile is being used to add to the standard environment, the sections are combined prior to being ran
#>
$Script:PreReqs   = @($Config.PreReqs                                + $Environment.PreReqs)
$Script:CopyItems = @($Config.Copy                                   + $Environment.Copy)
$PreScriptBlocks  = @($Config.Phases.($State.Phase).PreScriptBlocks  + $Environment.Phases.($State.Phase).PreScriptBlocks)
$Applications     = @($Config.Phases.($State.Phase).Applications     + $Environment.Phases.($State.Phase).Applications)
$RegistrySettings = @($Config.Phases.($State.Phase).RegistrySettings + $Environment.Phases.($State.Phase).RegistrySettings)
$PostScriptBlocks = @($Config.Phases.($State.Phase).PostScriptBlocks + $Environment.Phases.($State.Phase).PostScriptBlocks)

<#
    Process the resultant set of entries from the JSONs
#>
Initialize-PreReqs    -PreReqs $PreReqs
#Process First Phase only tasks

Connect-FileShares          -FileShares         $FileShares
Invoke-PhasePreCommands     -Phase              $State.Phase
Invoke-ScriptBlocks         -ScriptBlocks       $PreScriptBlocks
Start-ApplicationInstall    -Applications       $Applications
Sync-RegistrySettings       -RegistrySettings   $RegistrySettings
Invoke-ScriptBlocks         -ScriptBlocks       $PostScriptBlocks
Invoke-PhasePostCommands    -Phase              $State.Phase