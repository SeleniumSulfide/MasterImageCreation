Function Start-MasterCreation() {
    Param(
        [Parameter]
        [Switch]$IN,
        [Parameter]
        [Switch]$CO,
        [Parameter]
        [Switch]$x86,
        [Parameter]
        [Switch]$x64,
        [Parameter]
        [Switch]$VB6,
        [Parameter]
        [Switch]$AllDC,
        [Parameter]
        [Switch]$AllArch,
        [Parameter]
        [Switch]$All,
        [Parameter]
        [Switch]$Test,
        [Parameter]
        [PSCredential]$VCSACred,
        [Parameter]
        [PSCredential]$FSCred,
        [Parameter]
        [PSCredential]$VMCred
    )
    Begin {
        $DCS = @()
        If ($All.IsPresent -or $AllDC.IsPresent -or $IN.IsPresent) {
            $DCS+="i"
        }
        If ($All.IsPresent -or $AllDC.IsPresent -or $CO.IsPresent) {
            $DCS+="c"
        }
        $ARCHS = @()
        If ($All.IsPresent -or $AllArch.IsPresent -or $x86.IsPresent) {
            $ARCHS+="8"
        }
        If ($All.IsPresent -or $AllArch.IsPresent -or $x64.IsPresent) {
            $ARCHS+="6"
        }
        If ($All.IsPresent -or $AllArch.IsPresent -or $VB6.IsPresent) {
            $ARCHS+="VB6"
        }
        if (!(Test-AdCredential $VCSACred)) {
            Do {
                $VCSACred = get-credential -Message "Please enter VCSA Credentials"
            } until (Test-AdCredential $VCSACred)
        }
        if (!(Test-AdCredential $FSCred)) {
            Do {
                $FSCred = get-credential -Message "Please enter File Share Credentials"
            } until (Test-AdCredential $FSCred)
        }
        if ($Test.IsPresent) {
            $NameTemplate = "[DC]ta-[ARCH]-$(Get-Date -Format "MM")"
        } else {
            $NameTemplate = "[DC]pa-[ARCH]-$(Get-Date -Format "MM")"
        }
        Set-PowerCLIConfiguration -ParticipateInCeip $False -InvalidCertificateAction Ignore -Scope User
        $Bases = @()
        ForEach ($DC in $DCs) {
            Switch ($DC) {
                "c" { $server = "cpv-horizonvcsa.fhlbi.com" }
                "i" { $server = "wpv-horizonvcsa.fhlbi.com"}
            }
            $VCSA = Connect-VIServer -Server $Server -Credential $VCSACred
            ForEach ($ARCH in $ARCHs) {
                $Base = @{
                    Server=$Server
                    VCSACred = $VCSACred
                    VIServer=$VCSA
                    DC=$DC
                    ARCH=$ARCH
                    Name=$NameTemplate.Replace("[DC]",$dc).Replace("[ARCH]",$ARCH)
                    FSCred=$FSCred
                    Task=$Null
                    VM=$Null
                }
                $Bases += $Base
            }
        }
        $Bases = $Bases
    }
    Process {
        For ($i = 0; $i -lt $Bases.Count; $i++) {
            $Bases[$i].Task = Clone-VDIMaster -CloneName $Bases[$i].Name -Server $Bases[$i].VIServer
        }
        Watch-CloneTasks -Bases $Bases
        For ($i = 0; $i -lt $Bases.Count; $i++) {
            $Bases[$i].VM = Get-VM $Bases[$i].Name -Server $Bases[$i].VIServer
        }
        
        ForEach ($Base in $Bases) {
            if(!(Get-AdvancedSetting -Entity $Base.VM -Name "ctkEnabled" -Server $Base.Server)){
                New-AdvancedSetting -name "ctkEnabled" -value "TRUE" -Entity $Base.VM -Server $Base.VIServer -Confirm:$False -Force | Out-Null
            }

            if(!(Get-AdvancedSetting -Entity $Base.VM -Name "guestinfo.vmhost" -Server $Base.Server)){
                New-AdvancedSetting -name "guestinfo.vmhost" -Value $Base.Name -Entity $Base.VM -Server $Base.VIServer -Confirm:False -Force | Out-Null
            }

            $Base.VM | Start-VM -Server $Base.VIServer
        }
        Start-Sleep -Seconds 120
        <#Foreach ($Base in $Bases) {
            $Base.VM | Send-VMKeys -SpecialKeyInput "Enter"
        }
        Start-Sleep -Seconds 15#>
        Foreach ($Base in $Bases) {
            Start-PowerShellOnVm $Base
            Connect-VMToFileShare $Base -Path "\\wpv-mssccm1\application sources"
            Start-CreationProcess $Base -Path "\\wpv-mssccm1\application sources\vmware\temp\powershell\Install-MasterPreReqs.ps1"
        }
        Watch-VMPowerState $Bases
        $SnapName = (Get-Date -format "yy.MM.dd")+"-01"
        $Bases | %{
            Remove-VMCDDrives $_
            New-Snapshot -Name $SnapName -Server $_.VCSA -VM $_.VM
        }
    }
}