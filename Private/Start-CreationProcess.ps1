Function Start-CreationProcess() {
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]$Base,
        [Parameter(Mandatory=$True)]$Path
    )
    $VMView = $Base.VM | Get-View #-Server $Base.Server
    $OfficeArch = Switch ($Base.Arch) { "8"{"x86";} "6"{"x64";} "vb6"{"VB6";}}
    $DC = Switch ($Base.DC) { "i"{"in";} "c"{"co";}}
    Send-VMKeys -VM $VMView -String "& '$Path' -OfficeArch $OfficeArch -DC $DC" -SpecialKeyInput "Enter" 
}