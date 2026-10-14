$UAG = [PSCustomObject]@{
    Source="\\tmwdtahou702.tmw.com\horizon\Server\2603\UAG\euc-unified-access-gateway-26.03.0.0-24155660089_OVF10.ova"
    Name="tbapluagdmz201"
    vCenter="tmwaplvmvc401.tmw.com"
    Datacenter="UNXDMZ-DAL"
    ResourcePool = "RP.Gold.ud.401"
    Target="vi://tmwaplvmvc401.tmw.com/UNXDMZ-DAL/Resources/RP.Gold.ud.401"
    DS="DMZdsc002_IBM1_OS"
    defaultGateway="198.246.250.131"
        netInternet="192.246.250"
        ip0="198.246.250.15"
        netmask0="255.255.255.0"
        routes0=""
        netBackendNetwork="010.100.200"
        ip1="10.100.200.115"
        netmask1="255.255.255.0"
        routes1="10.100.200.0/24 10.210.128.201,172.16.0.0/12 10.100.200.201" #IP/CIDR GTWY,<repeat>
    DNS="172.26.1.60 172.26.1.160"
    proxyDestinationUrl="https://vdi.tmw.com" #CS
    proxyDestinationUrlThumbprints="Sha256:9f5609dda3f0fbd77307eef11b01627b894a70661cc3cfce9278682eaa287d11"
    tunnelExternalUrl="https://uag01.tmw.com:443"
    blastExternalUrl="https://uag01.tmw.com:443"
}

$Content = Get-Content "\\tmwdtahou702.tmw.com\horizon\Server\2603\UAG\UAG-Template.ini"
$UAG | Get-Member -MemberType NoteProperty | %{
    $_.Name
    $Content = $Content -replace "\[$($_.Name)\]", "$($UAG.($_.Name))"
}