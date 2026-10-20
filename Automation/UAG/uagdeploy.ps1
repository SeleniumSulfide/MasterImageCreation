#
# Copyright (c) 2015-2024 Omnissa, LLC. All rights reserved.
# This product is protected by copyright and intellectual property laws in the
# United States and other countries as well as by international treaties.
# -- Omnissa Public
#


<#
    .SYNOPSIS
     Sample Powershell script to deploy a UAG virtual appliance using ovftool.
    .EXAMPLE
     .\uagdeploy.ps1 -iniFile uag1.ini
#>


param(
    [string] $iniFile = "uag.ini", 
    [string] $rootPwd, 
    [string] $adminPwd, 
    [switch] $disableVerification, 
    [switch] $noSSLVerify, 
    [string] $ceipEnabled,
    [string] $awAPIServerPwd, 
    [string] $awTunnelGatewayAPIServerPwd, 
    [string] $awCGAPIServerPwd, 
    [string] $awSEGAPIServerPwd,
    [string] $newAdminUserPwd
)

#
# Load the dependent PowerShell Module
#

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath
$apDeployModule=$ScriptDir+"\uagdeploy.psm1"

if (!(Test-path $apDeployModule)) {
	Write-host "Error: PowerShell Module $apDeployModule not found." -foregroundcolor red -backgroundcolor black
	Exit
}

import-module $apDeployModule -Force -ArgumentList $awAPIServerPwd, $awTunnelGatewayAPIServerPwd, $awCGAPIServerPwd, $awSEGAPIServerPwd

Write-host "Unified Access Gateway (UAG) virtual appliance deployment script"

Write-host "Note: Please make sure to use the latest script that came with the build"

Write-host "If this ini file is exported from UAG instance and if any URL and/or IP addresses were changed in it, please edit/delete the OriginHeaderDetails[index] present in the ini file, as required. Other option to change this is at Admin UI -> Edge Service Settings -> Horizon Settings -> Allowed Origins"  -ForegroundColor DarkGreen -BackgroundColor White

Start-Sleep -Seconds 3

if (!(Test-path $iniFile)) {
	WriteErrorString "Error: Configuration file ($iniFile) not found."
	Exit
}

$settings = ImportIni $iniFile

$apName=$settings.General.name

$logfile="log-$apName.txt"
$winOvftoolPath="\\tmwdtahou702.tmw.com\horizon\Server\2603\UAG\ovftool\ovftool.exe"
$unixOvftoolPath="/usr/bin/ovftool"

Remove-item -path $logfile -ErrorAction SilentlyContinue

$ds=$settings.General.ds

if (!$ds) {
	WriteErrorString "Error: ds in the [General] section of $iniFile is missing. Set ds= followed by the data store name."
	Exit
}

$diskMode=$settings.General.diskMode

#
# Assign and validate network settings
#

$dns=$settings.General.dns
$defaultGateway=$settings.General.defaultGateway
$v6DefaultGateway=$settings.General.v6DefaultGateway
$forwardrules=$settings.General.forwardrules
$netInternet=$settings.General.netInternet
$ip0=$settings.General.ip0
$routes0=$settings.General.routes0
$policyRouteGateway0=$settings.General.policyRouteGateway0
$netmask0=$settings.General.netmask0

$netManagementNetwork=$settings.General.netManagementNetwork
$ip1=$settings.General.ip1
$routes1=$settings.General.routes1
$policyRouteGateway1=$settings.General.policyRouteGateway1
$netmask1=$settings.General.netmask1

$netBackendNetwork=$settings.General.netBackendNetwork
$ip2=$settings.General.ip2
$routes2=$settings.General.routes2
$policyRouteGateway2=$settings.General.policyRouteGateway2
$netmask2=$settings.General.netmask2
$rootPasswordExpirationDays=$settings.General.rootPasswordExpirationDays
$passwordPolicyMinLen=$settings.General.passwordPolicyMinLen
$passwordPolicyMinClass=$settings.General.passwordPolicyMinClass
$passwordPolicyDifok=$settings.General.passwordPolicyDifok
$passwordPolicyUnlockTime=$settings.General.passwordPolicyUnlockTime
$passwordPolicyFailedLockout=$settings.General.passwordPolicyFailedLockout
$enabledAdvancedFeatures=$settings.General.enabledAdvancedFeatures
$adminPasswordMinLen=$settings.General.adminPasswordPolicyMinLen
$adminPasswordLockoutTime=$settings.General.adminPasswordPolicyUnlockTime
$adminPasswordFailedLockoutCount=$settings.General.adminPasswordPolicyFailedLockoutCount
$adminSessionIdleTimeoutMinutes=$settings.General.adminSessionIdleTimeoutMinutes
$configURL = $settings.General.configURL
$configKey = $settings.General.configKey
$configURLThumbprints = $settings.General.configURLThumbprints
$configURLHttpProxy = $settings.General.configURLHttpProxy
$adminCsrSubject = $settings.General.adminCsrSubject
$adminCsrSAN = $settings.General.adminCsrSAN
$additionalDeploymentMetadata = $settings.General.additionalDeploymentMetadata

if ((!$ip0) -And (!$ip1) -And (!$ip2)) {

	#
	# No IP addresses specified so we will use DHCP for address allocation
	#

	$ipAllocationPolicy = "dhcpPolicy"

} else {

	$ipAllocationPolicy = "fixedPolicy"

}

$deploymentOption=GetDeploymentSettingOption $settings

if ($Env:OS -like 'win*') {
   Write-Host "OS: Windows"
   $ovftool = $winOvftoolPath
} else {
    $osType = "Linux"
    if ($IsMacOs) {
	   $osType = "MacOS"
     }
	Write-Host "OS: $osType"
    $ovftool = $unixOvftoolPath
}

if (!(Test-path $ovftool)) {
	WriteErrorString "Error: ovftool command not found ($ovftool)"
	Exit
}

$source = $settings.General.source
$target = $settings.General.target
$vmFolder = $settings.General.folder


if ([string]::IsNullOrWhiteSpace($source))  {
	WriteErrorString "Error: Source locator '[General] source' is blank"
	Exit
}

$verifyOptions = @("--verifyOnly")
if ($noSSLVerify) {
	$verifyOptions += "--noSSLVerify"
}

$sourceVerifyOutput = & $ovftool $verifyOptions $source 2>&1
$sourceVerifyPattern = "File:\s+euc-unified-access-gateway-.*\.vmdk"
if (-not ($sourceVerifyOutput -match $sourceVerifyPattern))  {
	WriteErrorString "Error: Source locator '[General] source' should point to a valid OVA image"
	Exit
}

if ([string]::IsNullOrWhiteSpace($target))  {
	WriteErrorString "Error: Target locator '[General] target' is blank"
	Exit
}

if ($apName.length -gt 32) {
	WriteErrorString "Error: Virtual machine name must be no more than 32 characters in length"
	Exit
}

if (!$apName) {
	$apName = GetAPName
}

$osLoginUsername = ReadOsLoginUsername $settings
if ($osLoginUsername.length -eq 0) {
    $osLoginUsername = "root"
}

if ($settings.General.dsComplianceOS -eq "true") {
    updatePasswordPolicyForDsComplianceOS $settings
}

if (!$rootPwd) {
    $rootPwd = GetRootPwd  $apName $settings $osLoginUsername
}

if (!$adminPwd) {
    $adminPwd = GetAdminPwd $apName $settings
}

if (!$ceipEnabled) {
    $ceipEnabled = GetCeipEnabled $apName
}

$settingsJSON=GetJSONSettings $settings $newAdminUserPwd
$jsonString=GetSettingsJSONProperty $settingsJSON
# Write-host $jsonString

$omnissaDir = SetUp
# Set this variable so that we can clear it in error scenario
Set-Variable -Name "ovfFile" -Value (Join-Path "$omnissaDir" "$apName.cfg") -Scope global
# Any permissions issues with config file, deployment gets stopped
$jsonString | Set-Content -Path $ovfFile -ErrorAction Stop

$ovfOptions = @(
    "--X:enableHiddenProperties"
	"--X:waitForIp"
	"--X:logFile=$logfile"
	"--X:logLevel=verbose"
	"--powerOffTarget"
	"--powerOn"
	"--overwrite"
	"--configFile=$ovfFile"
 )

# ESX datastore name
$ovfOptions += "-ds=$ds"

$ovfOptions += "--name=$apName"
$ovfOptions += "--prop:rootPassword=$rootPwd"
if ($osLoginUsername -ne "root") {
    $ovfOptions += "--prop:osLoginUsername=$osLoginUsername"
}

$osMaxLoginLimit = ReadOsMaxLoginLimit $settings
if ($osMaxLoginLimit.length -gt 0) {
	$ovfOptions += "--prop:osMaxLoginLimit=$osMaxLoginLimit"
}

if ($adminPwd.length -gt 0) {
	$ovfOptions += "--prop:adminPassword=$adminPwd"
}

switch -Wildcard ($deploymentOption) {

	'onenic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += $netOptions0
    }
	'twonic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += $netOptions0
        $netOptions1 = GetNetOptions $settings "1"
        $ovfOptions += $netOptions1
    }
	'threenic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += $netOptions0
        $netOptions1 = GetNetOptions $settings "1"
        $ovfOptions += $netOptions1
        $netOptions2 = GetNetOptions $settings "2"
        $ovfOptions += $netOptions2
    }
}

#$ovfOptions += " --ipAllocationPolicy=$ipAllocationPolicy"
$ovfOptions += "--deploymentOption=$deploymentOption"

if ($dns.length -gt 0) {
	$ovfOptions += "--prop:DNS=$dns"
}

if ($rootPasswordExpirationDays.length -gt 0) {
	$ovfOptions += "--prop:rootPasswordExpirationDays=$rootPasswordExpirationDays"
}

if ($passwordPolicyMinLen.length -gt 0) {
	$ovfOptions += "--prop:passwordPolicyMinLen=$passwordPolicyMinLen"
}

if ($passwordPolicyMinClass.length -gt 0) {
	$ovfOptions += "--prop:passwordPolicyMinClass=$passwordPolicyMinClass"
}

if ($passwordPolicyDifok.length -gt 0) {
	$ovfOptions += "--prop:passwordPolicyDifok=$passwordPolicyDifok"
}

if ($passwordPolicyUnlockTime.length -gt 0) {
	$ovfOptions += "--prop:passwordPolicyUnlockTime=$passwordPolicyUnlockTime"
}

if ($passwordPolicyFailedLockout.length -gt 0) {
	$ovfOptions += "--prop:passwordPolicyFailedLockout=$passwordPolicyFailedLockout"
}

#Admin Password policy settings
if ($adminPasswordFailedLockoutCount.length -gt 0){
	$ovfOptions += "--prop:adminPasswordPolicyFailedLockoutCount=$adminPasswordFailedLockoutCount"
}

if ($adminPasswordMinLen.length -gt 0){
	$ovfOptions += "--prop:adminPasswordPolicyMinLen=$adminPasswordMinLen"
}

if ($adminPasswordLockoutTime.length -gt 0){
	$ovfOptions += "--prop:adminPasswordPolicyUnlockTime=$adminPasswordLockoutTime"
}

if ($adminSessionIdleTimeoutMinutes.length -gt 0){
    $ovfOptions += "--prop:adminSessionIdleTimeoutMinutes=$adminSessionIdleTimeoutMinutes"
}

$adminMaxConcurrentSessions = ValidateAdminMaxConcurrentSessions $settings
if ($adminMaxConcurrentSessions.length -gt 0){
    $ovfOptions += "--prop:adminMaxConcurrentSessions=$adminMaxConcurrentSessions"
}

$rootSessionIdleTimeoutSeconds = ValidateRootSessionIdleTimeoutSeconds $settings
if ($rootSessionIdleTimeoutSeconds.length -gt 0){
	$ovfOptions += "--prop:rootSessionIdleTimeoutSeconds=$rootSessionIdleTimeoutSeconds"
}

$commandsFirstBoot = ValidateCustomBootTimeCommands $settings "commandsFirstBoot"
if ($commandsFirstBoot.length -gt 0) {
    $ovfOptions += "--prop:commandsFirstBoot=$commandsFirstBoot"
}
$commandsEveryBoot = ValidateCustomBootTimeCommands $settings "commandsEveryBoot"
if ($commandsEveryBoot.length -gt 0) {
    $ovfOptions += "--prop:commandsEveryBoot=$commandsEveryBoot"
}

if ($defaultGateway.length -gt 0) {
	$ovfOptions += "--prop:defaultGateway=$defaultGateway"
}

if ($v6DefaultGateway.length -gt 0) {
	$ovfOptions += "--prop:v6DefaultGateway=$v6DefaultGateway"
}

if ($forwardrules.length -gt 0) {
	$ovfOptions += "--prop:forwardrules=$forwardrules"
}

if ($routes0.length -gt 0) {
	$ovfOptions += "--prop:routes0=$routes0"
}

if ($routes1.length -gt 0) {
	$ovfOptions += "--prop:routes1=$routes1"
}

if ($routes2.length -gt 0) {
	$ovfOptions += "--prop:routes2=$routes2"
}

if ($policyRouteGateway0.length -gt 0) {
	$ovfOptions += "--prop:policyRouteGateway0=$policyRouteGateway0"
}

if ($policyRouteGateway1.length -gt 0) {
	$ovfOptions += "--prop:policyRouteGateway1=$policyRouteGateway1"
}

if ($policyRouteGateway2.length -gt 0) {
	$ovfOptions += "--prop:policyRouteGateway2=$policyRouteGateway2"
}

#
# .ovf definition defaults this to True so on vSphere we only need to set it if False.
#

if ($ceipEnabled -eq $false) {
    $ovfOptions += "--prop:ceipEnabled=False"
}

if ($settings.General.dsComplianceOS -eq "true") {
    updatePasswordPolicyForDsComplianceOS $settings
	$ovfOptions += "--prop:dsComplianceOS=True"
}

if ($settings.General.tlsPortSharingEnabled -eq "true") {
	$ovfOptions += "--prop:tlsPortSharingEnabled=True"
}

if ($settings.General.sshEnabled -eq "true") {
	$ovfOptions += "--prop:sshEnabled=True"
}

if ($settings.General.sshPasswordAccessEnabled -eq "false") {
        $ovfOptions += "--prop:sshPasswordAccessEnabled=False"
}

if ($settings.General.sshKeyAccessEnabled -eq "true") {
        $ovfOptions += "--prop:sshKeyAccessEnabled=True"
}

$sshBannerText=ReadLoginBannerText $settings
if ($sshBannerText.length -gt 0) {
	$ovfOptions += "--prop:sshLoginBannerText=$sshBannerText"
}

$sshInterface = validateSSHInterface $settings
if (($sshInterface.length -gt 0)) {
    $ovfOptions += "--prop:sshInterface=$sshInterface"
}

$sshPort = $settings.General.sshPort
if ($sshPort.length -gt 0 -and ($sshPort -match '^[0-9]+$')) {
    $ovfOptions += "--prop:sshPort=$sshPort"
}

$secureRandomSrc=ReadSecureRandomSource $settings
if ($secureRandomSrc.length -gt 0) {
	$ovfOptions += "--prop:secureRandomSource=$secureRandomSrc"
}

if ($netInternet.length -gt 0) {
	$ovfOptions += "--net:Internet=$netInternet"
}

if ($netManagementNetwork.length -gt 0) {
	$ovfOptions += "--net:ManagementNetwork=$netManagementNetwork"
}

if ($netBackendNetwork.length -gt 0) {
	$ovfOptions += "--net:BackendNetwork=$netBackendNetwork"
}

if ($diskMode.length -gt 0) {
    $ovfOptions += "--diskMode=$diskMode"
}

if ($disableVerification) {
    $ovfOptions += "--disableVerification"
}

if ($noSSLVerify) {
    $ovfOptions += "--noSSLVerify"
}

if ($vmFolder.length -gt 0) {
    $ovfOptions += "--vmFolder=$vmFolder"
}

if($enabledAdvancedFeatures.length -gt 0){
	$ovfOptions += "--prop:enabledAdvancedFeatures=$enabledAdvancedFeatures"
}

$gatewaySpec = getGatewaySpec $settings
if($gatewaySpec.length -gt 0) {
    $ovfOptions += "--prop:gatewaySpec=$gatewaySpec"
}

if($configURL.length -gt 0){
	$ovfOptions += "--prop:configURL=$configURL"
}

if($configKey.length -gt 0){
	$ovfOptions += "--prop:configKey=$configKey"
}

if($configURLThumbprints.length -gt 0){
	$ovfOptions += "--prop:configURLThumbprints=$configURLThumbprints"
}

if($configURLHttpProxy.length -gt 0){
	$ovfOptions += "--prop:configURLHttpProxy=$configURLHttpProxy"
}

if($adminCsrSubject.length -gt 0){
	$ovfOptions += "--prop:adminCsrSubject=$adminCsrSubject"
}

if($adminCsrSAN.length -gt 0){
	$ovfOptions += "--prop:adminCsrSAN=$adminCsrSAN"
}

if($additionalDeploymentMetadata.length -gt 0){
	$ovfOptions += "--prop:additionalDeploymentMetadata=$additionalDeploymentMetadata"
}
#Write-host $ovfOptions
& $ovftool $ovfOptions $source $target

if ($? -eq "0") {
	if ($ipAllocationPolicy -eq "fixedPolicy") {
		Write-host "Note that the IP addresses will be set to the specified IP addresses for each NIC"
	}
	Write-host "UAG virtual appliance $apName deployed successfully"
} else {
	Write-host "UAG deployment failed. Further information may be found in the log file $logfile"
}

if (Test-path $ovfFile) {
   Remove-item -path $ovfFile -Force
}

