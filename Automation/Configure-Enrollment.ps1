Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
Install-WindowsFeature RSAT-AD-PowerShell
$CAParams = @{
    CAType              = EnterpriseRootCa
    CACommonName        =
    ValidityPeriod      = Years
    ValidityPeriodUnits = 10
}

Install-AdcsCertificationAuthority @CAParams
Install-Module ADCSTemplate -Force
New-ADCSTemplate -DisplayName "Horizon True SSO" -JSON $JSON
Set-ADCSTemplateACL -DisplayName "Horizon True SSO" -Identity "dgenrl01$" -Enroll


vdmUtil --authAs  --authDomain .local --authPassword P@! --truesso --environment --add --enrollmentServer ..local
vdmUtil --authAs  --authDomain .local --authPassword P@! --truesso --environment --list --enrollmentServer ..local --domain .local
vdmUtil --authAs  --authDomain .local --authPassword P@! --truesso --create --connector --domain .local --template Omnissa_Horizon --primaryEnrollmentServer dgenrl01.dgriffin.local --certificateServer dgenrl01 --mode enabled
