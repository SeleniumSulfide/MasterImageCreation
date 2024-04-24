Function Install-Chocolatey() {
     if (!(test-path C:\ProgramData\chocolatey\bin\choco.exe)) {
         Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
     } }
