# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Add Win32 API functions for window control
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinAPI {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@

<#
    Checks for and, if neccessary, installs prereqs eg Modules/Packages and PackageSources (Nuget, PSGallery)
#>
Function Initialize-PreReqs() {
    $PackageSources = @(
        @{
            Name="nuget.org"
            Location="https://www.nuget.org/api/v2/"
            ProviderName="Nuget"
            Debug=$False
            Trusted=$True
        },
        @{
            Name="PSGallery"
            Location="https://www.powershellgallery.com/api/v2"
            ProviderName="PowerShellGet"
            Debug=$False
            Trusted=$True
        }
    )

    Set-TLSVersion

    $PackageSources | ForEach-Object {
        if(!(get-packagesource -Name $_.Name -ErrorAction SilentlyContinue)){
            Register-PackageSource -Name $_.Name `
                -Location $_.Location `
                -ProviderName $_.ProviderName `
                -Debug:$_.Debug `
                -Trusted:$_.Trusted `
                -force `
                -ForceBootstrap | Out-Null
        } else {
            if ((Get-PackageSource -Name $_.Name).Trusted -ne $_.Trusted) {
                Set-PackageSource -Name $_.Name -Trusted:$_.Trusted -Force | Out-Null
            }
        }
    }

    if (!(test-path C:\ProgramData\chocolatey\bin\choco.exe)) {
        #Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }

    $Modules = @(
        @{
            Name="Evergreen"
            Package=$false
            PostScriptBlocks=@(
                "Update-Evergreen"
            )
        },
        @{
            Name="VcReDist"
            Package=$false
        }
    )
    ForEach ($Module in $Modules) { 
        if(!(Confirm-PreReq -PreReq $Module.Name -Package $Module.Package)) {
            ForEach ($ScriptBlock in $Module.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
            Install-Prereq -PreReq $Module.Name -Package $Module.Package
            ForEach ($ScriptBlock in $Module.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        }
    }

    <#
        Some Registry Settings are in HKEY_Classes_Root
        This adds the PSDrive so the rest of the script can interact with it
    #>
    If (!(Test-Path HKCR:\)){
        New-PSDrive -Name "HKCR" -PSProvider Registry -Root "HKEY_Classes_Root" | out-null
    }

    $PSModulePath = "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules"
    $Modules = Get-Childitem (Join-Path $CommandPath "*.psm1")
    $Modules | Copy-Item -Destination $PSModulePath
}


<#
    Sets TLSVersion used to 1.2, necessary for NuGet
#>
Function Set-TLSVersion() {
    Param([Parameter(Mandatory=$False)]
            [Net.SecurityProtocolType]$TlsVer="Tls12")
    [Net.ServicePointManager]::SecurityProtocol = [enum]::parse([Net.SecurityProtocolType], $TlsVer)
}


<#
    Check if the PreReq exists and returns T/F
#>
Function Confirm-PreReq() {
    Param(
        [Parameter(Mandatory=$true)][String]$PreReq,
        [Parameter(Mandatory=$true)][Boolean]$Package
    )
    if (!$Package){
        if (get-module -name $PreReq -ListAvailable){
            Write-Host "PreReq found: $PreReq"
            return $True
        }
        else { 
            Write-Host "PreReq not found: $PreReq"
            return $False
        }
    } else {
        if ((get-package | where-object -property name -eq $PreReq)) { 
            Write-Host "PreReq found: $PreReq"
            return $True
        } else { 
            Write-Host "PreReq not found: $PreReq"
            return $False
        }
    }
}


<#
    Install Pre-Reqs for the script to function based on "Initialize-Prereqs" function
#>
function Install-PreReq() {
    Param(
        [Parameter(Mandatory=$true)][String]$PreReq,
        [Parameter(Mandatory=$true)][Boolean]$Package
    )
    Write-Host "Installing $PreReq"
    if (!$Package) {
        Install-Module $PreReq -Scope AllUsers -Force | Import-Module $PreReq
    } else {
        $pkg = (Install-Package $PreReq -ProviderName NuGet -Scope AllUsers -Force -SkipDependencies).Payload.Directories[0]
        Add-Type -Path (Get-ChildItem (Split-Path ($Pkg.location) -Parent) -Filter "$PreReq.dll" -Recurse -File)[0].FullName
    }
}

<#
    Over engineered copy-item from when I was having issues, could probably be removed
#>
Function Copy-ItemWrapper() {
    Param([Parameter(Mandatory=$True)][String]$Path,
            [Parameter(Mandatory=$True)][String]$Destination)
    $Path = $Path.Replace("[LocalRoot]",$LocalRoot).Replace("[RemoteRoot]",$RemoteRoot)
    $Destination = $Destination.Replace("[LocalRoot]",$LocalRoot).Replace("[RemoteRoot]",$RemoteRoot)
    if (!(test-path $Destination)) {
        New-ItemWrapper $Destination
    }
    Write-Host "Copying: $($Path)"
    Get-Item $Path | Copy-Item -Destination "$Destination" -Force -Recurse
}

<#
    This wraps New-Item and handles Registry PSProvider paths differently than FileSystem PSProvider
    Reason:
        HKLM:\SOFTWARE\This\That\Theother
            You have to create This, then That, then TheOther keys
        C:\This\That\TheOther
            New-Item will create each directory in the chain that doesn't exist
        
        Further, specifying ItemType Directory is necessary or New-Item creates a file
#>
Function New-ItemWrapper() {
    Param(
        [Parameter(Mandatory=$True)][String]$Path
    )
    
    $Parent = Split-Path $Path -Parent
    If (!(Test-path $Parent)) {
        New-ItemWrapper -Path $Parent
    }
    
    if ($Path -like "*:*"){
        $Drive = $Path.Substring(0,$Path.Indexof(":"))
        $Provider = (Get-PSDrive -Name $Drive).Provider.Name
    } elseif ($Path -like "\\*") {
        $Provider = "FileSystem"
    }
    
    Switch ($Provider) {
        "Registry" { New-Item $Path | Out-Null }
        "FileSystem" { New-Item $Path -ItemType Directory | Out-Null }
        Default { New-Item $Path | Out-Null }
    } 
}

<#
    This checks for PendingFileRenames and reboots if any are found
    Important for: Horizon Agent, SolidWorks
#>
Function Restart-OnPending() {
    Param(
        [Parameter()][Int32]$Delay=15
    )
    $ControlSets = Get-ChildItem "hklm:\system\*control*"
    foreach ($ControlSet in $ControlSets) {
        $Path = (join-path $ControlSet "Control\Session Manager").Replace("HKEY_LOCAL_MACHINE","HKLM:")
        $Manager = Get-Item $Path
        If ($Manager.Property -Contains "PendingFileRenameOperations" -or $Manager.Property -Contains "FileRenameOperations") {
            for ($i=0; $i -lt $Delay; $i++){
                Write-Progress -Activity "Pending File Rename operations detected" -Status "Rebooting in $($Delay-$i) seconds"
                start-sleep -seconds 1
            }
            Restart-Computer
        }
    } 
}

<#
    The gets all the child items based on path and runs them with the give Arguments
    This allows for wild carding MSIs that use the same install arguments to install from one command
    If any ScriptBlocks are specified to ran, they are used to modify the Arguments or similar for things like AppVol Manager
#>
Function Install-Applications() {
    Param(
        [Parameter(Mandatory=$True)]
            $Applications
        )

    ForEach ($Application in $Applications) {
        $i++; Write-Progress -ID 0 -Activity "Installing Applications" -Status "Installing: $($Application.Name)" -PercentComplete (($i/$Applications.Count)*100);
        #This Replace is here while the Json contains both Relative paths and not, the goal is to have relative paths
        $Application.Path = $Application.Path.Replace("[SoftwarePath]",$SoftwarePath).Replace("[Name]",$Application.Name).Replace("\\","\")
        $Application.Arguments = $Application.Arguments.Replace("[SoftwarePath]",$SoftwarePath).Replace("[Name]",$Application.Name).Replace("\\","\")
        #The above line assumes relative and NON-UNC paths, so replace \\ with \

        ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }

        If ($Application.Path) {
            If ($Application.NonRecurse) {
                $Files = Get-ChildItem $Application.Path
            } else {
                $Files = Get-ChildItem $Application.Path -Recurse     
            }
            
            ForEach($File in $Files) {
                Write-Host $File.FullName
                If ($Application.Arguments) {
                    $Process = Start-Process -FilePath $File.FullName -ArgumentList "$($Application.Arguments)" -PassThru
                } else {
                    $Process = Start-Process -FilePath $File.Fullname -PassThru
                }

                Watch-Process -Process $Process
                Start-Sleep -Seconds 1
            }
        }
        ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }
    Write-Progress -ID 0 -Activity "Installing Applications" -Completed
}

Function Watch-Process() {
    Param(
        [Parameter(Mandatory=$True)]
            $Process
    )
    if ($Process) {
        $LastWrite = Get-Date
        $WriteEvery = 5
        Do {
            if ((New-TimeSpan -Start $LastWrite -end (Get-Date)).Seconds -ge $WriteEvery) {
                $LastWrite = Get-Date
                Write-Host "`tProcess Running: $($Process.Name)" -ForegroundColor Yellow
                if ($WriteEvery -lt 30) { $WriteEvery++ }
            }
            Start-Sleep -Seconds 1
        } while (Get-Process -id $Process.ID -ErrorAction SilentlyContinue)
        Write-Host "`tProcess Complete: $($Process.Name)" -ForegroundColor Green
    } else {
        Write-Host "`tProcess Complete:" -ForegroundColor Cyan
    }
}

<#
    This accepts an Array of RegistrySettings as defined in the JSON
    If the Property doesn't exist it is created with the specified value
    If the Property DOES exist, it is set to the value specified
    If there are ScriptBlocks specified they are ran. SBs are used here to modify the setting dynamically for things like AppVol Managers
#>
Function Sync-RegistrySettings() {
    Param(
        [Parameter(Mandatory=$True)]
            [PSCustomObject[]]$RegistrySettings
    )

    ForEach ($RegistrySetting in $RegistrySettings) {
        $i++; Write-Progress -ID 0 -Activity "Synching Registry Settings" -Status "Synching: $($RegistrySetting.Name)" -PercentComplete (($i/$RegistrySettings.Count)*100);
        ForEach ($ScriptBlock in $RegistrySettings.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        if (!(Test-Path $RegistrySetting.Path )) {
            New-ItemWrapper $RegistrySetting.Path 
        }
        Write-host $RegistrySetting.Name
        If ((Get-Item $RegistrySetting.Path).Property -Contains $RegistrySetting.Name) {
            Set-ItemProperty `
                -Path $RegistrySetting.Path `
                -Name $RegistrySetting.Name `
                -Value $RegistrySetting.Value
        } else {
            New-ItemProperty `
                -Path $RegistrySetting.Path `
                -Name $RegistrySetting.Name `
                -Value $RegistrySetting.Value `
                -PropertyType $RegistrySetting.Type | out-null
        }
        ForEach ($ScriptBlock in $RegistrySettings.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }
    Write-Progress -ID 0 -Activity "Synching Registry Settings"  -Completed

}

<#
    This accepts an array of PowerShell Commands and executes them in sequence
    Unfortunately you can't use this within other functions as doing so changes the scope which doesn't allow for variable manipulation
#>
Function Invoke-ScriptBlocks() {
    Param(
        [Parameter(Mandatory=$true)]$ScriptBlocks
    )

    ForEach ($ScriptBlock in $ScriptBlocks) {
        Write-Host $ScriptBlock
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }
}

<#
    Installs Drivers from the $DriverPath
#>
Function Install-Drivers() {
    Param(
        [Parameter(Mandatory=$True)]$Path
    )
    #Import Publisher Certificates if they exist
    Get-ChildItem (Join-Path $DriverPath "*.cer") -Recurse | ForEach-Object { 
        $Cert.Import($_.FullName)
        If (!(Test-Path "Cert:\LocalMachine\TrustedPublisher\$($Cert.Thumbprint)")) { 
            Import-Certificate $_.FullName -CertStoreLocation Cert:\LocalMachine\TrustedPublisher; 
        } 
    }

    #Install Driver
    $INFs = Get-ChildItem (Join-Path $Path *.inf) -Recurse
    $INFs | ForEach-Object { 
        $i++; Write-Progress -ID 0 -Activity "Installing Drivers" -Status "Installing $i of $($INFs.Count): $($_.Name)" -PercentComplete (($i/$INFs.Count)*100);
        PnPUtil.exe /add-driver "$($_.FullName)" /install /subdirs
    }
    Write-Progress -ID 0 -Activity "Installing Drivers" -Completed
}

<#
    For print drivers to not need to be installed, they have to be "activated" with Add-PrintDriver
    This accepts the list specified in the main Environment.JSON
    To generate the list, run Get-PrinterDriverList.PS1 -Server <ServerName>
#>
Function Initialize-PrinterDrivers(){
    Param(
        [Parameter(Mandatory=$True)]$PrinterDrivers
    )
    ForEach ($PrinterDriver in $PrinterDrivers) {
        $i++; Write-Progress -ID 0 -Activity "Initializing PrintDrivers" -Status "Initializing: $($PrinterDriver)" -PercentComplete (($i/$PrinterDrivers.Count)*100);
        If (!(Get-PrinterDriver -Name $PrinterDriver -ErrorAction SilentlyContinue)) {
            Write-Host "Adding PrinterDriver: $($PrinterDriver)"
            Add-PrinterDriver -Name $PrinterDriver
        }
    }
    Write-Progress -ID 0 -Activity "Installing Drivers" -Completed
}

<#
    Create the global variables from the Environment and Overlay files
#>
Function Initialize-Variables(){
    Param(
        [Parameter(Mandatory=$True)]$Variables
    )
    ForEach ($Variable in $Variables) {
        ForEach ($ScriptBlock in $Variable.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        $Variable.Value = Convert-PlaceholderVariables -Value $Variable.Value -Variables $Variables
        if (Get-Variable -Name $Variable.Name -ErrorAction SilentlyContinue) {
            Write-Host "Setting Variable: $($Variable.Name)"
            Set-Variable -Name $Variable.Name -Value $Variable.Value -Scope Global
        } else {
            Write-Host "Creating Variable: $($Variable.Name)"
            New-Variable -Name $Variable.Name -Value $Variable.Value -Scope Global
        }
        ForEach ($ScriptBlock in $Variable.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }
}

Function Convert-PlaceholderVariables() {
    Param(
        [Parameter(Mandatory=$False)]
            [String]$Value,
        [Parameter(Mandatory=$False)]
            $Variables=$Global:Variables
    )

    ForEach ($Variable in $Variables) {
        If (Get-Variable -Name $Variable.Name -ErrorAction SilentlyContinue) {
            $Variable = Get-Variable -Name $Variable.Name -ErrorAction SilentlyContinue
            $Value = $Value.Replace("[$($Variable.Name)]", $Variable.Value)
        }
    }
    Return $Value
}

<#
    As Zebra Print drivers are difficult, you have to use a different method to make them work
    This Function accepts the ZebraPrinters from the Environment.JSON
    List of Drivers can be obtained from the printerserver using Get-PrinterDriverList.psa -Server <servname> -Filterscript {$_.DriverName -like "Zebra*"}
        
#>
Function Initialize-ZebraDrivers(){
    Param(
        [Parameter(Mandatory=$True)]$PrinterDrivers
    )
    $DriverWizard = Get-ChildItem (Join-Path $SoftwarePath "Zebra\*\DriverWizard.exe") -ErrorAction SilentlyContinue
    
    ForEach ($PrinterDriver in $PrinterDrivers) {
        $i++; Write-Progress -ID 0 -Activity "Initializing Driver" -Status "Driver: $($PrinterDriver)" -PercentComplete (($i/$PrinterDrivers.Count)*100);
        Write-Host "Adding PrinterDriver: $PrinterDriver"
        Start-Process -FilePath $DriverWizard.FullName -ArgumentList "install /name:`"$($PrinterDriver)`" /model:`"$($PrinterDriver)`" /port:`"FILE:`"" -WAIT
    }
    Remove-Printer -Name "Zebra*"
    Write-Progress -ID 0 -Activity "Initializing Driver" -Completed
}

<#
    This consumes the Evergreen section of the Environment.JSON and downloads the software specified
    Evergreen is an Opensource Powershell module
    https://stealthpuppy.com/evergreen/
#>
Function Get-AppsEvergreen() {
    Param(
        [Parameter(Mandatory=$True)]
            $Applications,
        [Parameter(Mandatory=$True)]
            [System.IO.FileInfo]$DownloadPath,
        [Parameter(Mandatory=$False)]
            [Switch]$Force
    )
    
    ForEach ($Application in $Applications) {
        $i++; Write-Progress -ID 0 -Activity "Downloading Applications" -Status "Downloading: $($Application.Name)" -PercentComplete (($i/$Applications.Count)*100);
        ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        $EvergreenApp = Get-EvergreenApp -Name $Application.EverGreenApp
        If ($Application.Filter -ne "") { 
            $Filter = [ScriptBlock]::Create($Application.Filter)
            $EvergreenApp = ($EvergreenApp | Where-Object -FilterScript $Filter)[0]
        }

        $File = Split-Path -Path $EvergreenApp.Uri -Leaf
        $Destination = Join-Path -Path $DownloadPath -ChildPath $Application.EvergreenApp
        $OutFile = Join-Path -Path $Destination -ChildPath ([system.uri]::UnescapeDataString($File))
        if (!(Test-Path $Destination)) { New-ItemWrapper -Path $Destination }

        if (!(Test-Path $OutFile) -or $Force.IsPresent) {
            Write-Host "Evergreen: $($Application.EvergreenApp)"
            Invoke-WebRequest -UseBasicParsing -Uri $EvergreenApp.uri -OutFile $OutFile
        }
        ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }
    Write-Progress -ID 0 -Activity "Downloading Applications" -Completed
}

<#
    This consumes the Download section of the Environment.JSON
    The URIs specified are used to download specific files and are manual scraped from their website
    if a FileName is specified, that filename will be used
    Otherwise, the URI will be used to get the file name
    If an Application has a specified ScriptBlock, that is ran prior to downloading. The SBs are used to parse a main URI for a download link
#>
Function Get-AppsDownload() {
     Param(
        [Parameter(Mandatory=$True)]
            $Applications,
        [Parameter(Mandatory=$True)]
            [System.IO.FileInfo]$DownloadPath,
        [Parameter(Mandatory=$False)]
            [Switch]$Force
    )
    
    ForEach ($Application in $Applications) {
        $i++; Write-Progress -ID 0 -Activity "Downloading Applications" -Status "Downloading: $($Application.Name)" -PercentComplete (($i/$Applications.Count)*100);
        $Destination = Join-Path $DownloadPath $Application.Name
        If (!(Test-Path $Destination)) { New-ItemWrapper -Path $Destination }
        ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        ForEach ($URI in $Application.URIs) {
            ForEach ($ScriptBlock in $URI.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
            if ($URI.FileName) {
                $OutFile = Join-Path $Destination $URI.FileName
            } else {
                $OutFile = Join-Path $Destination (Split-Path $URI.URI -Leaf)
            }

            If (!(Test-Path $OutFile) -or $Force.IsPresent ) {
                Write-Host "Download: $($Application.Name)"
                Invoke-WebRequest -UseBasicParsing -Uri $URI.URI -OutFile $OutFile
            }
            ForEach ($ScriptBlock in $URI.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        }
        ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }
    Write-Progress -ID 0 -Activity "Downloading Applications" -Completed
}

<#
    Downloads Visual C++ Redistributables using VCRedist powershell module
#>
Function Get-AppsVCRedist() {
    Param(
        [Parameter(Mandatory=$True)]$Releases,
        [Parameter(Mandatory=$True)]$Path
    )
    
    If (!(Test-Path $Path)) { New-ItemWrapper $Path }

    ForEach ($Release in $Releases) {
        $i++; Write-Progress -ID 0 -Activity "Downloading VCredist" -Status "Downloading: $($Release)" -PercentComplete (($i/$Releases.Count)*100);
        Write-Host "Downloading VCRedist $Release"
        $VC = Get-VCList -Export All | Where-Object { $_.Architecture -ne "ARM64" -and $_.Release -eq $Release}
        $Version = $VC.Version | Sort-Object -Unique
        If ($Version.Count -gt 1) {
            $Version = $Version[-1] #When multiple versions are returned, this gets the latest
        }
        $VC | Where-Object {$_.Version -eq $Version} | Save-VCRedist -Path $Path | Out-Null
    }
    Write-Progress -ID 0 -Activity "Downloading VCredist" -Completed
}

<#
    This connects to FileShares and if the Credential is null, the code will request and then store the credential information
    The Creds are stored after the first connection so that after reboots the connection can be reestablished
#>
Function Connect-Fileshares() {
    Param(
        [Parameter(Mandatory=$False)]$FileShares
    )
    $Shares = @()

    ForEach ($FileShare in $FileShares) {
        Write-Host $FileShare.Root
        If ($FileShare.Username -ne ""){
            $Cred = New-Object System.Management.Automation.PSCredential ($FileShare.Username, (ConvertTo-SecureString $FileShare.Password -AsPlainText -Force))
        }
        Do {
            if (!$cred) {
                Write-Host "Please enter the credential to connect to the File share" -ForegroundColor Yellow
                $cred = Get-Credential -Message "<username>@<domain>" -UserName $FileShare.UserName
            }

            try {
                If (!(Get-PSDrive -Name $FileShare.Name -ErrorAction SilentlyContinue)) {
                    New-PSDrive -PSProvider FileSystem -Root $FileShare.Root -Name $FileShare.Name -Credential $Cred -Persist -Scope Global
                }
            } catch {
                Write-Error $_
            } finally {
                if (!(Get-PSDrive -Name $FileShare.Name -ErrorAction SilentlyContinue)) {$Cred = $null}
            }
        } While (!(Get-PsDrive -Name $Fileshare.Name -ErrorAction SilentlyContinue))
        $Shares += @{Name=$FileShare.Name; Root=$FileShare.Root; UserName=$Cred.Username; Password=$Cred.GetNetworkCredential().Password}
    }

    $Shares = ($Shares | ConvertTo-JSON) | ConvertFrom-Json
    If (!($State.Shares) -and $Shares.Count -gt 0) {
        $State | Add-Member -NotePropertyName "Shares" -NotePropertyValue $Shares
    } elseif ($Shares.Count -gt 0) {
        $State.Shares = $Shares
    }
}

<#
    Add Defender Antivirus Exclusions
#>
Function Add-AntivirusExclusions() {
    param(
        [Parameter(Mandatory=$False)]$FSLogixPaths
    )
    Import-Module Defender
    $Exclusions = @(
        @{ ExclusionProcess = "C:\Program Files\VMware\VMware View\Agent\bin\wsnm.exe" },
        @{ ExclusionProcess = "C:\Program Files\VMware\VMware View\Agent\bin\wsnm_jms.exe" },
        @{ ExclusionProcess = "C:\Program Files\VMware\VMware View\Agent\bin\ws_scripthost.exe" },
        @{ ExclusionProcess = "C:\Program Files\VMware\VMware View\Agent\bin\SecurityGateway.exe" },
        @{ ExclusionProcess = "C:\Program Files\VMware\VMware View\Agent\bin\tsdrvdisvc.dll" },
        @{ ExclusionProcess = "C:\Program Files\VMware\VMware View\Agent\VMware Blast\VMBlastS.exe" },
        @{ ExclusionProcess = "C:\Program Files\VMware\VMware View\Agent\VMware Blast\VMBlastW.exe" },
        @{ ExclusionProcess = "C:\Program Files (x86)\Common Files\VMware\USB\VMware-usbarbitrator64.exe" },
        @{ ExclusionProcess = "C:\Program Files\Common Files\VMware\ScannerRedirection\Scanner.exe" },
        @{ ExclusionProcess = "C:\Program Files (x86)\CloudVolumes\Agent\svservice.exe" }
    )

    If ($FSLogixPaths) {
        $Exclusions = $Exclusions + @(
            @{ ExclusionPath = "%TEMP%\*\*.VHD" },
            @{ ExclusionPath = "%TEMP%\*\*.VHDX" },
            @{ ExclusionPath = "%Windir%\TEMP\*\*.VHD" },
            @{ ExclusionPath = "%Windir%\TEMP\*\*.VHDX" },
            @{ ExclusionPath = "%ProgramFiles%\FSLogix\Apps\frxdrv.sys" },
            @{ ExclusionPath = "%ProgramFiles%\FSLogix\Apps\frxdrvvt.sys" },
            @{ ExclusionPath = "%ProgramFiles%\FSLogix\Apps\frxccd.sys" },
            @{ ExclusionPath = "%ProgramFiles%\FSLogix\Apps\frxccd.exe" },
            @{ ExclusionProcess = "%ProgramFiles%\FSLogix\Apps\frxccds.exe" },
            @{ ExclusionProcess = "%ProgramFiles%\FSLogix\Apps\frxsvc.exe" }
        )

        $FSLogixPaths | ForEach-Object {
            $Exclusions = $Exclusions + @(
                @{ ExclusionPath = "\\$_\*\*.VHD" },
                @{ ExclusionPath = "\\$_\*\*.VHD.lock" },
                @{ ExclusionPath = "\\$_\*\*.VHD.meta" },
                @{ ExclusionPath = "\\$_\*\*.VHD.metadata" },
                @{ ExclusionPath = "\\$_\*\*.VHDX" },
                @{ ExclusionPath = "\\$_\*\*.VHDX.lock" },
                @{ ExclusionPath = "\\$_\*\*.VHDX.meta" },
                @{ ExclusionPath = "\\$_\*\*.VHDX.metadata" }
            )
        }
    }
    
    $Exclusions | ForEach-Object { 
        Write-Host "Adding Exclusion: $($_.Values)"
        Add-MpPreference @_ 
    }
}

<#
    Third-party functions to download and install windows updates
#>
function Update-Windows {
    Param(
        [Parameter()][Switch]$Reboot
    )
    try {
        Write-Host "Creating Update Session"
        $Session = New-Object -Com Microsoft.Update.Session
        Write-Host "Beginning Windows Updates"
        $Updates = Get-WindowsUpdates $Session
        if ($updates.count -eq 0) {
            Write-Host "No Updates Found"
        } else {
            Write-Host "Windows Updates Found"
            Sync-WindowsUpdates -Updates $Updates -Session $Session
            $WURestart = Install-WindowsUpdates -Updates $Updates -Session $Session
        }
        if ($WURestart -and $Reboot.IsPresent) {
            Restart-Computer
        } elseif ($WURestart) {
            Write-Host "Restart Required" -ForegroundColor Red
        }
    } catch {
        Write-Host $_.tostring()
    } 
}

function Get-WindowsUpdates {
    Param(
        [Parameter(Mandatory=$True)]$Session
    )
    $Searcher = $Session.CreateUpdateSearcher()
    Write-Host "Searching for Windows Updates"
    #$searcher.serviceid = '9482f4b4-e343-43b6-b170-9a65bc822c77'
    $Criteria = "IsInstalled=0 and IsHidden=0 and Type='Software'"
    $SearchResult = $Searcher.Search($Criteria)
    $Updates = $SearchResult.Updates
    return , $Updates 
}

function Install-WindowsUpdates {
    Param (
        [Parameter(Mandatory=$True)]$Updates,
        [Parameter(Mandatory=$True)]$Session
    )
    $Reboot = $False
    $Installer = $Session.CreateUpdateInstaller()
    $Updates | ForEach-Object {
        $i++
        $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
        if ($_.isdownloaded -and $_.Title -NotLike "*Feature Update*") {
            Write-Host "Installing update $i of $($Updates.Count()): $($_.Title)"
            $UpdatesToInstall.Add($_) | out-null
            $Installer.Updates = $UpdatesToInstall
            $Result = $Installer.Install()
            if ($Result.RebootRequired) { $Reboot = $true }
        }
    }
    Return $Reboot 
}

function Sync-WindowsUpdates {
    Param (
        [Parameter(Mandatory=$True)]$Updates,
        [Parameter(Mandatory=$True)]$Session
    )
    $Downloader = $Session.CreateUpdateDownloader()
    $Updates | ForEach-Object {
        $i++
        Write-Host "Downloading $i of $($Updates.Count()): $($_.Title)"
        $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
        if ($_.Title -NotLike "*Feature Update*")
        {
            $updatesToDownload.Add($_) | out-null
        }
        $Downloader.Updates = $UpdatesToDownload
        $Downloader.Download() | out-null
    } 
}

function Send-KeyToProcess {
    param (
        [Parameter(Mandatory)]
        [string]$ProcessName,

        [Parameter(Mandatory)]
        [string]$Key
    )
    <#
        Supported Keys:
        Modifier	Symbol	Example
        Shift       +	"+A" → Shift + A
        Ctrl        ^	"^C" → Ctrl + C
        Alt         %	"%F4" → Alt + F4
        {Enter}
        {TAB}
        {ESC}
        {UP}
        {DOWN}
        {LEFT}
        {RIGHT}
        F1 to F12      -- Unsure which is correct
        {F1} to {F12}  -- Unsure which is correct

    #>
    try {
        # Get the process
        $proc = Get-Process -Name $ProcessName -ErrorAction Stop | Select-Object -First 1

        if (-not $proc.MainWindowHandle -or $proc.MainWindowHandle -eq 0) {
            Write-Error "Process '$ProcessName' has no main window."
            return
        }

        # Bring window to front
        #[WinAPI]::ShowWindowAsync($proc.MainWindowHandle, 5) | Out-Null  # 5 = SW_SHOW
        #Start-Sleep -Milliseconds 200
        [WinAPI]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 200

        # Send the key
        [System.Windows.Forms.SendKeys]::SendWait($Key)
        Write-Host "Sent key '$Key' to process '$ProcessName'."
    }
    catch {
        Write-Error "Error: $_"
    }
}

