Function Install-Drivers(){
    Param(
        [Parameter(Mandatory=$True)]
            [System.IO.FileInfo]$Path
    )
    $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    Get-ChildItem (Join-Path $Path "*.cer") -Recurse | ForEach-Object { $Cert.Import($_.FullName); If (!(Test-Path "Cert:\\LocalMachine\\TrustedPublisher\\$($Cert.Thumbprint)")) { Import-Certificate $_.FullName -CertStoreLocation Cert:\\LocalMachine\\TrustedPublisher; } }
    Get-ChildItem (Join-Path $Path "*.inf") -Recurse | ForEach-Object { PnPUtil.exe /add-driver "$($_.FullName)" /install /subdirs }
}