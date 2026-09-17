Function Initialize-Library() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline)]
            [System.IO.FileInfo[]]$Library,
        [Parameter(Mandatory=$False)]
            [Switch]$Append
    )
    Begin {
        If (!$Append.IsPresent) {
            $Global:AppLibrary = @()
        }
    }
    Process {
        $Applications = $Library | Get-Content | ConvertFrom-JSON | Where-Object { $_.Name -NotIn $Global:AppLibrary.Name }
        $Global:AppLibrary += $Applications | ForEach-Object { $_ }
    }
}

Function Get-LibraryApplication() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            [String[]]$Name
    )
    Begin {
        If (!($Global:AppLibrary)) {
            Throw "Application Library has not been intitialized. Please run Initialize-Library"
        }
        $Applications = @()
    }
    Process {
        $Application = $Global:AppLibrary | Where-Object { $_.Name -eq $Name}
        If (!($Application)) {
            Throw "Application $Name not found"
        }

        $Applications += $Application
    }
    End {
        $Applications
    }
}

Function Find-LibraryApplication() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            [String[]]$Name
    )
    Begin {
        If (!($Global:AppLibrary)) {
            Throw "Application Library has not been intitialized. Please run Intitialize-Library"
        }
        $Applications = @()
    }
    Process {
            $Applications += $Global:AppLibrary | Where-Object { $_.Name -like $Name}
    }
    End {
        $Applications | Select-Object -Property Name
    }
}

Function Save-LibraryApplication() {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            $Application,
        [Parameter(Mandatory=$True)]
            [System.IO.FileInfo]$Path,
        [Parameter(Mandatory=$False)]
            [Switch]$Force
    )
    Begin {
        Update-Evergreen -Force
    }
    Process {
        $ProgressPreference = 'SilentlyContinue'

        ForEach ($ScriptBlock in $Application.Source.PreScriptBlocks) {
            Write-Verbose "Executing: $ScriptBlock"
            Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
        }
        
        $Destination = Join-Path -Path $Path -ChildPath $Application.Name
        Write-Verbose "Using Destination: $Destination"

        if (!(Test-Path $Destination)) { 
            Write-Verbose "Creating Destination"
            If ($PSCmdlet.ShouldProcess($Destination,"Creating Destination Folder")) {
                New-ItemWrapper -Path $Destination
            }
        }

        ForEach ($Item in $Application.Source.Copy) {
            ForEach ($ScriptBlock in $Item.PreScriptBlocks) {
                Write-Verbose "Executing: $ScriptBlock"
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
            }
            Write-Host "Copy: $($Application.Name)"
            
            If ($Item.Source -like "\\*") { 
                $Item | Connect-LibraryApplicationShare 
            }

            Write-Verbose "Source: $($Item.Source)"
            If ($PSCmdlet.ShouldProcess($Item.Source,"Copying from")) {
                Copy-ItemWrapper -Path $Item.Source -Destination $Destination
            } Else {
                Test-Path $Item.Source
            }

            ForEach ($ScriptBlock in $Item.PostScriptBlocks) { 
                Write-Verbose "Executing: $ScriptBlock"
                If ($PSCmdlet.ShouldProcess($ScriptBlock,"Execute")) {
                    Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
                }
            }
        }

        ForEach ($Item in $Application.Source.Download) {
            ForEach ($ScriptBlock in $Item.PreScriptBlocks) {
                Write-Verbose "Executing: $ScriptBlock"
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
            }
            
            Write-Host "Download: $($Application.Name)"

            if ($Item.FileName) {
                $OutFile = Join-Path $Destination $Item.FileName
            } else {
                $OutFile = Join-Path $Destination (Split-Path $Item.URI -Leaf)
            }
            Write-Verbose "OutFile: $OutFile"

            If (!(Test-Path $OutFile) -or $Force.IsPresent ) {
                Write-Verbose "URI: $($Item.URI)"
                If ($PSCmdlet.ShouldProcess($OutFile,"Download")) {
                    Invoke-WebRequest -UseBasicParsing -Uri $Item.URI -OutFile $OutFile
                    If (!(Test-Path $OutFile)) {
                        Throw "File Not Found: $Outfile"
                    }
                } else {
                    Write-Host "From" $Item.URI
                }
            }

            ForEach ($ScriptBlock in $Item.PostScriptBlocks) { 
                Write-Verbose "Executing: $ScriptBlock"
                If ($PSCmdlet.ShouldProcess($ScriptBlock,"Execute")) {
                    Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
                }
            }
        }

        ForEach ($Item in $Application.Source.Evergreen) {
            ForEach ($ScriptBlock in $Item.PreScriptBlocks) {
                Write-Verbose "Executing: $ScriptBlock"
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
            }
            Write-Host "Evergreen: $($Item.Name)"

            $EvergreenApp = Get-EvergreenApp -Name $Item.Name
            If ($Item.Filter -ne "") {
                Write-Verbose "Filtering: $($Item.Filter)"
                $Filter = [ScriptBlock]::Create($Item.Filter)
                $EvergreenApp = ($EvergreenApp | Where-Object -FilterScript $Filter)[0]
            }

            ForEach ($App in $EvergreenApp) {
                If ($Item.FileName){
                    $File = $Item.Filename
                } Else {
                    $File = [system.uri]::UnescapeDataString((Split-Path -Path $App.Uri -Leaf))
                }

                Write-Verbose "File: $File"
                $OutFile = Join-Path -Path $Destination -ChildPath ($File)
                Write-Verbose "OutFile: $OutFile"

                if (!(Test-Path $OutFile) -or $Force.IsPresent) {
                    Write-Verbose "Downloading: $($App.URI)"
                    If ($PSCmdlet.ShouldProcess($OutFile,"Download")) {
                        Invoke-WebRequest -UseBasicParsing -Uri $App.uri -OutFile $OutFile
                        If (!(Test-Path $OutFile)) {
                            Throw "Failed to download $Outfile"
                        }
                    } Else {
                        Write-Host "From" $App.URI
                    }
                }
            }

            ForEach ($ScriptBlock in $Item.PostScriptBlocks) { 
                Write-Verbose "Executing: $ScriptBlock"
                If ($PSCmdlet.ShouldProcess($ScriptBlock,"Execute")) {
                    Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
                }
            }
        }

        ForEach ($Item in $application.Source.WinGet) {
            ForEach ($ScriptBlock in $Item.PreScriptBlocks) {
                Write-Verbose "Executing: $ScriptBlock"
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
            }

            $WinGet = Get-Item (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\WinGet.exe")
            If ($PSCmdlet.ShouldProcess($Item.Name,"WinGet")) {
                $Process = Start-Process -FilePath $WinGet.FullName -ArgumentList "download $($Item.Name) --download-directory `"$Destination`" --skip-license" -PassThru
            } else {
                $Process = Start-Process -FilePath $WinGet.Fullname -ArgumentList "search $($Item.Name)" -PassThru
            }
            Watch-Process -Process $Process

            ForEach ($ScriptBlock in $Item.PostScriptBlocks) { 
                Write-Verbose "Executing: $ScriptBlock"
                If ($PSCmdlet.ShouldProcess($ScriptBlock,"Execute")) {
                    Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
                }
            }
        }

        ForEach ($ScriptBlock in $Application.Source.PostScriptBlocks) { 
            Write-Verbose "Executing: $ScriptBlock"
            If ($PSCmdlet.ShouldProcess($ScriptBlock,"Execute")) {
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
            }
        }
    }
    End {}
}

Function Install-LibraryApplication() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            $Application,
        [Parameter(Mandatory=$True)]
            [System.IO.FileInfo]$Path
    )
    Begin {
        
    }
    Process{
        ForEach ($Item in $Application.Install) {
            Write-Progress -ID 0 -Activity "Installing Applications" -Status "Installing: $($Application.Name)"
            #This Replace is here while the Json contains both Relative paths and not, the goal is to have relative paths
            $Item.Path = $Item.Path.Replace("[SoftwarePath]",$Path).Replace("[Name]",$Application.Name).Replace("\\","")
            $Item.Arguments = $Item.Arguments.Replace("[SoftwarePath]",$Path).Replace("[Name]",$Application.Name).Replace("\\","")
            #The above line assumes relative and NON-UNC paths, so replace \\ with \

            ForEach ($ScriptBlock in $Item.PreScriptBlocks) { 
                Write-Verbose "Executing: $Scriptblock"
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
            }

            If ($Item.Path){
                $Files = Get-ChildItem $Item.Path -Recurse:$Item.Recurse
            }

            ForEach($File in $Files) {
                Write-Host $File.FullName
                If ($Item.Arguments) {
                    $Process = Start-Process -FilePath $File.FullName -ArgumentList "$($Item.Arguments)" -PassThru
                } else {
                    $Process = Start-Process -FilePath $File.Fullname -PassThru
                }

                Watch-Process -Process $Process
                Start-Sleep -Seconds 1
            }

            ForEach ($ScriptBlock in $Item.PostScriptBlocks) { 
                Write-Verbose "Executing: $Scriptblock"
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
            }
        }
    }
    End{
        Write-Progress -ID 0 -Activity "Installing Applications" -Completed
    }
}

Function Connect-LibraryApplicationShare() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            $Applications
    )
    Begin {}
    Process {
        $Paths = $Applications | Where-object {$_.Source.Copy.Source -like "\\*" } | ForEach-Object { 
            $URI = [System.URI]$_.Source.Copy.Source
            $Path = "\\"+(Join-Path $URI.Host $URI.Segments[1].Replace("/",""))
            $Path
        } | Sort-Object -Unique

        ForEach ($Path in $Paths){
            Do {
                If (Get-SMBMapping $Path -ErrorAction SilentlyContinue){
                    $Connect = $true
                } else {
                    Write-Host "Please provide SMB Share Credentials" -ForegroundColor DarkYellow
                    Write-Host "`t$Path" -ForegroundColor Blue
                    $cred = Get-Credential
                    New-SMBMapping -RemotePath $Path -UserName $Cred.UserName -Password $Cred.GetNetworkCredential().Password
                }
            } While (!($Connected))
        }
    }
    End {}
}

Function Sync-LibraryApplicationRegistry() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            [ValidateNotNullOrEmpty()]
            $Application
    )
    Begin {}
    Process{
        ForEach ($RegistrySetting in $Application.Registry) {
            Write-Progress -ID 0 -Activity "Syncing Registry Settings" -Status "Syncing: $($RegistrySetting.Name)"
            ForEach ($ScriptBlock in $RegistrySettings.PreScriptBlocks) { 
                Write-Verbose "Executing: $Scriptblock"
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
            }

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

            ForEach ($ScriptBlock in $RegistrySettings.PostScriptBlocks) { 
                Write-Verbose "Executing: $Scriptblock"
                Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope 
            }
        }
    }
    End{
        Write-Progress -ID 0 - Activity "Syncing Registry Settings" -Completed
    }
}


Function Test-LibraryPackage() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            [ValidateNotNullOrEmpty()]
                [System.IO.FileInfo[]]$PackageFile,
        [Parameter(Mandatory=$false)]
            [System.IO.FileInfo]$ScriptRoot = "C:\Temp\Scripts"
    )
    Begin {}
    Process{
        Write-Host "Package File: $($PackageFile.FullName)"
        $Package = Get-Content $PackageFile | ConvertFrom-Json

        Write-Host "Package Name: $($Package.Name)"
        Write-Verbose $Package

        Write-verbose "Initializing Variables" -ForegroundColor Cyan
        Initialize-Variables $Package.Variables

        $Libraries = Get-Childitem (Join-Path $LibraryPath "*.json")
        Write-Host "Libraries Found: $($Libraries.Count)"

        Write-Verbose "Analyzing Applications"
        $Applications = @()
        $Unfound = @()
        ForEach ($Name in $Package.Applications) {
            Write-Verbose "`tFinding: $Name"
            $Application = Find-LibraryApplication $Name
            if ($Application) {
                $Applications += $Application
            } else {
                $Unfound += $Name
            }
        }

        Write-Host "Found Applications: $($Applications.Count)" -ForegroundColor Cyan
        $Applications.Name
        Write-Host "Unfound Applications: $($Unfound.Count)" -ForegroundColor Magenta
        $Unfound


        Read-Host "Press Enter to start Application Source Testing"
        $Applications | Test-LibraryApplication -Path $SoftwarePath
    }
    End{}
}

Function Test-LibraryApplication() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            [ValidateNotNullOrEmpty()]
                $Application,
        [ParaMeter(Mandatory=$True)]
            [System.IO.FileInfo]$Path
    )
    Begin {}
    Process {
        $Application | Save-LibraryApplication -Path $Path -WhatIf
    }
    End {}
}

Function ConvertTo-LibraryCapture() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
            [System.Management.Automation.PSCredential]$LocalUser
    )
    New-LocalUser -name $LocalUser.UserName -password $LocalUser.Password -PasswordNeverExpires -UserMayNotchangePassword
    Add-LocalGroupMember -group "Administrators" -Member $LocalUser.UserName

    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*Teams*"} | Remove-AppxPackage -AllUsers
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*Teams*" } | Remove-AppxProvisionedPackage -Online

    $Paths = @(
        "hklm:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "hklm:\\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $Keys = $Paths | Get-Childitem | Where-Object { $_.Property -Contains "DisplayName" -and $_.Property -NotContains "SystemComponent" }
    
    $Uninstall = @()

    $MSIs = @(
        "Omnissa Horizon Agent",
        "Omnissa Dynamic Environment Manager Enterprise"
    )

    ForEach ($MSI in $MSIs) {
        $Command = $Keys | Where-Object { ($_ | Get-ItemPropertyValue -Name DisplayName) -eq $MSI } | Get-ItemPropertyValue -Name UninstallString
        If ($Command) {
            $Command = $Command.Split(" ")
            $Uninstall += [PSCustomObject]@{
                Name = $MSI
                FilePath = "c:\Windows\System32\"+$Command[0]
                ArgumentList = $Command[1].Replace('/I','/X')+" /qn /norestart REBOOT=R"
            }
        }
    }

    $OneDrive = (Get-ChildItem (Join-Path $env:LocalAppData "Microsoft\OneDrive\*\OneDriveSetup.exe")).FullName
    If ($OneDrive) {
        $Uninstall+= [PSCustomObject]@{
            Name = "OneDrive"
            FilePath = $OneDrive
            ArgumentList = "/uninstall"
        }
    }

    $FSLogix = $Keys | Where-Object { ($_ | Get-ItemPropertyValue -Name DisplayName) -eq "Microsoft FSlogix Apps" } | Get-ItemPropertyValue -Name UninstallString
    If ($FSLogix) { 
        $Command = $FSLogix.Split('"')
        $Uninstall += [PSCustomObject]@{
            Name = "FSLogix"
            FilePath = $Command[1]
            ArgumentList = $Command[2].Trim()+" /quiet /norestart"
        }
    }

    Write-Host "Begining Uninstalls" -ForegroundColor Cyan
    $Uninstall | ForEach-Object {
        $_ | Format-List
        Watch-Process -Process (Start-Process -FilePath $_.FilePath -ArgumentList $_.ArgumentList -PassThru)
        Start-Sleep -Seconds 1
    }

}