Param(
    [Parameter(Mandatory=$True)][System.IO.FileInfo]$ConfigFile,
    [Parameter(Mandatory=$False)][Switch]$Confirm
)

Function Install-AppStack () {
    Param(
        [Parameter(Mandatory=$True)][System.IO.FileInfo]$ConfigFile,
        [Parameter(Mandatory=$False)][Boolean]$Confirm
    )
    Function Install-Software() {
        Param([Parameter(Mandatory=$True)][String]$Path,
                [Parameter(Mandatory=$False)][String]$Arguments)

        Get-ChildItem $Path | `
            ForEach-Object {
                Write-Host $_.FullName
                If ($Arguments) {
                    $Process = Start-Process -FilePath $_.FullName -ArgumentList "$Arguments" -PassThru
                } else {
                    $Process = Start-Process -FilePath $_.Fullname -PassThru
                }
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
            }
    }

    Function New-ItemWrapper() {
        Param(
            [Parameter(Mandatory=$True)][String]$Path
        )
        $Parent = Split-Path $Path -Parent
        If (!(Test-path $Parent)) {
            New-ItemWrapper -Path $Parent
        }
        $Drive = $Path.Substring(0,$Path.Indexof(":"))
        $Provider = (Get-PSDrive -Name $Drive).Provider.Name
        Switch ($Provider) {
            "Registry" { New-Item $Path | Out-Null }
            "FileSystem" { New-Item $Path -ItemType Directory | Out-Null }
            Default { New-Item $Path | Out-Null }
        } 
    }

    Function Invoke-ScriptBlocks() {
        Param(
            [Parameter(Mandatory=$true)]$ScriptBlocks
        )
    
        ForEach ($ScriptBlock in $ScriptBlocks) {
            Write-Host $ScriptBlock
            Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
        }
    }

    Function Sync-RegistrySettings() {
        Param(
            [Parameter(Mandatory=$True)]
                $RegistrySettings
        )
    
        ForEach ($RegistrySetting in $RegistrySettings) {
            If ($RegistrySetting.PreScriptBlocks) { $RegistrySetting.PreScriptBlocks | ForEach-Object { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($_)) -NoNewScope }}
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
            If ($RegistrySetting.PostScriptBlocks) { $RegistrySetting.PostScriptBlocks | ForEach-Object { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($_)) -NoNewScope }}
        }
    }

    Function Get-AppsEvergreen() {
        Param(
            [Parameter(Mandatory=$True)]
                $Applications,
            [Parameter(Mandatory=$True)]
                [System.IO.FileInfo]$DownloadPath
        )

        ForEach ($Application in $Applications) {
            ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
            $EvergreenApp = Get-EvergreenApp -Name $Application.EverGreenApp
            If ($Application.Filter -ne "") { 
                $Filter = [ScriptBlock]::Create($Application.Filter)
                $EvergreenApp = $EvergreenApp | Where-Object -FilterScript $Filter 
            }

            $File = Split-Path -Path $EvergreenApp.Uri -Leaf
            $Destination = Join-Path $DownloadPath $Application.EvergreenApp
            $OutFile = Join-Path $Destination ([system.uri]::UnescapeDataSTring($File))
            if (!(Test-Path $Destination)) { New-ItemWrapper -Path $Destination }

            if (!(Test-Path $OutFile)) {
                Write-Host "Evergreen: $($Application.EvergreenApp)"
                Invoke-WebRequest -UseBasicParsing -Uri $EvergreenApp.uri -OutFile $OutFile
            }
            ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        }
    }

    Function Get-AppsDownload() {
         Param(
            [Parameter(Mandatory=$True)]
                $Applications,
            [Parameter(Mandatory=$True)]
                [System.IO.FileInfo]$DownloadPath
        )
        ForEach ($Application in $Applications) {
            $Destination = Join-Path $DownloadPath $Application.Name
            If (!(Test-Path $Destination)) { New-ItemWrapper -Path $Destination }
            ForEach ($URI in $Application.URI) {
                #Don't use Invoke-ScriptBlocks as that changes the scope
                ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
                if ($Application.FileName) {
                    $OutFile = Join-Path $Destination $Application.FileName
                } else {
                    $OutFile = Join-Path $Destination (Split-Path $URI -Leaf)
                }

                If (!(Test-Path $OutFile)) {
                    Write-Host "Download: $($Application.Name)"
                    Invoke-WebRequest -UseBasicParsing -Uri $URI -OutFile $OutFile
                }
                ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
            }
        }
    }

    Function Get-AppsCopy() {
        Param(
            [Parameter(Mandatory=$True)]
                $Applications,
            [Parameter(Mandatory=$True)]
                [System.IO.FileInfo]$DownloadPath
        )
        ForEach ($Application in $Applications) {
            ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
            $Destination = Join-Path $DownloadPath $Application.Name
            if (!(Test-Path $Application.Path)) {
                Throw "Path not found: $($Application.Path)"
            }
            If (!(Test-Path $Destination) -or $Application.Force) {
                Write-Host "Copy: $($Application.Path)"
                Copy-Item -Path $Application.Path -Destination $Destination -Force -Recurse
            }
            ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        }
    }

    $AppStack = Get-Content $ConfigFile | Convertfrom-Json
    $Script:DownloadPath = $AppStack.DownloadPath
    If (!(Test-Path $AppStack.DownloadPath)) {
        New-ItemWrapper -Path $AppStack.DownloadPath | Out-Null
    }
    Write-Host "Download Path: $($AppStack.DownloadPath)"

    Get-AppsEvergreen -Applications $AppStack.Evergreen -DownloadPath $AppStack.DownloadPath
    Get-AppsDownload -Applications $AppStack.Download -DownloadPath $AppStack.DownloadPath
    Get-AppsCopy -Applications $AppStack.Copy -DownloadPath $AppStack.DownloadPath

    If ($Confirm) { Read-Host "Press Enter to begin Installation..." }

    Invoke-ScriptBlocks -ScriptBlocks $AppStack.PreScriptBlocks
    
    ForEach ($Application in $AppStack.Install) { 
        ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        If ($Application.Path) { Install-Software -Path (Join-Path $AppStack.DownloadPath $Application.Path) -Arguments $Application.Arguments }
        ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }

    Sync-RegistrySettings -RegistrySettings $AppStack.RegistrySettings

    $PostScriptBlocks = @(
        "Get-Childitem `"C:\Users\Public\Desktop\*.lnk`" | Remove-Item -Force",
        "Remove-Item `"$DownloadPath`" -Recurse -Force"
    )
    
    Invoke-ScriptBlocks -ScriptBlocks ($AppStack.PostScriptBlocks + $PostScriptBlocks)

}

$Services = @("ClickToRunSvc","wuauserv","edge*","MicrosoftEdge*","*adobe*","*chrome*","*google*")
$Services | ForEach-Object {
    Get-Service -Name $_ | Set-Service -StartupType Disabled
    Get-Service -Name $_ | Stop-Service
}

Install-Appstack -ConfigFile $ConfigFile -Confirm $Confirm.IsPresent