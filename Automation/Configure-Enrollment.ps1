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


vdmUtil --authAs dan --authDomain dgriffin.local --authPassword P@ss2026! --truesso --environment --add --enrollmentServer dgenrl01.dgriffin.local
vdmUtil --authAs dan --authDomain dgriffin.local --authPassword P@ss2026! --truesso --environment --list --enrollmentServer dgenrl01.dgriffin.local --domain dgriffin.local
vdmUtil --authAs dan --authDomain dgriffin.local --authPassword P@ss2026! --truesso --create --connector --domain dgriffin.local --template Omnissa_Horizon --primaryEnrollmentServer dgenrl01.dgriffin.local --certificateServer dgenrl01 --mode enabled
