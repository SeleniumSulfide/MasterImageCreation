$Credential = Get-Credential #This needs to be a domain account
$VIServer = "<vCenter>"
Connect-VIServer -Server $VIServer -Credential $Credential
$VMName = "<Name of Master>"
$VM = Get-VM $VMName
$GuestCred = Get-Credential #The local account that was setup
$Drive = "<Path to share where scripts are>" #Meaning, the root of the share \\<server>\<share>

$Script = @"
`$User = "$($Credential.GetNetworkCredential().Username)"
`$Pass = $($Credential.GetNetworkCredential().Password)"
[SecureString]`$secStringPassword = ConvertTo-SecureString `$Pass -AsPlainText -Force
[psCredential]`$cred = New-Object System.Management.Automation.PSCredential(`$user,`$secStringPassword)

New-PSDrive -Name "H" -PSProvider FileSystem -Root "$Drive" -Credential `$Cred
(Join-Path "$Drive" "<rest of path to>\Start-BaseCreation.PS1") -DC "<DC>"
"@

Invoke-VMScript -VM $VM -ScriptText $Script -GuestCredential $GuestCred -RunAsync