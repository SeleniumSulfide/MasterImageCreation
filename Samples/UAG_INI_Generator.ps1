$RP = Get-ResourcePool -Name "<name>"
$Parts = @()
$Parts += $RP.Name
$Current = $RP
While ($null -ne $Current) {
    $parts += $Current.Parent.Name
    $Current = $Current.Parent
}
[Array]::Reverse($Parts)
"vi://$vcserver"+($Parts -Join "/")



$UAG = [PSCustomObject]@{
    Source="<fullpathtoova>"
    Name=""
    vCenter=""
    Datacenter=""
    Cluster=""
    ResourcePool = ""
    Target="vi://<vcenter>/<datacenter>/host/<cluster>/Resources/<resourcepool>" #Case Sensitive
    DS=""
    defaultGateway=""
    netInternet="" #vcenter network name
    ip0=""
    netmask0="255.255.255.0"
    routes0=""
    netBackendNetwork="" #vcenter network name
    ip1=""
    netmask1="255.255.255.0"
    routes1="" #IP/CIDR GTWY,<repeat>
    DNS="" #space delimited
    proxyDestinationUrl="https://<connectionServer>" #CS
    proxyDestinationUrlThumbprints="Sha256:<thumbprint>"
    tunnelExternalUrl="https://<uag.domain.com>:443"
    blastExternalUrl="https://<uag.domain.com>:443"
}

$Content = Get-Content "<path to>\UAG-Template.ini"
$UAG | Get-Member -MemberType NoteProperty | %{
    $_.Name
    $Content = $Content -replace "\[$($_.Name)\]", "$($UAG.($_.Name))"
}