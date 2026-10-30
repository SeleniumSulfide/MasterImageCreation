Param(
    [Parameter()]
        #Only use for the Supplemental, expected is none
        [System.IO.FileSystemInfo]$BaseFile,
    [Parameter()]
        #Only use for the Supplemental, expected is none
        [System.IO.FileSystemInfo]$OverlayFile,

    [Parameter()]
        [ValidateSet("Dallas","Ashburn")]
        [String]$DC,

    [Parameter()]
        [Switch]$JoinAAD,
    
    [Parameter()]
        [Switch]$Pause,

    [Parameter()]
        [String]$LocalRoot="C:\Temp",

    [Parameter()]
        [String]$RemoteRoot="\\contoso.com\horizon\Master"
)

Start-Transcript -Path (Join-Path $LocalRoot "Phase-$($State.Phase).log") -Append -Force
Set-ExecutionPolicy Bypass -Scope LocalMachine -Force
If (!(Get-Module MasterImageCreation -ListAvailable)) {
    Install-Module MasterImageCreation -Scope AllUsers -Force
}

$State = Get-MasterState
if ($Null -eq $State) {
    $PSBoundParameters.Add("Phase",0)
    $State = $PSBoundParameters
    Set-MasterState -State $State

    $Run = "hklm:\software\microsoft\windows\currentversion\run"
    New-ItemProperty -path $Run -Name "*Image" -Value (Join-Path $LocalRoot "Scripts\Start-BaseCreation.bat") -PropertyType String | Out-Null
}

Start-MasterBuild -State $State
