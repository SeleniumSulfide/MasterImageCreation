<#----------------------------
Sets TLSVersion used to 1.2, necessary for NuGet
-----------------------------#>
Function Set-TLSVersion()
{
    Param([Parameter(Mandatory=$False)]
            [Net.SecurityProtocolType]$TlsVer="Tls12")
    [Net.ServicePointManager]::SecurityProtocol = [enum]::parse([Net.SecurityProtocolType], $TlsVer)
}