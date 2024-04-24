<#----------------------------
Checks for and, if neccessary, installs prereqs eg Modules/Packages
-----------------------------#>
Function Initialize-PreReqs()
{
    Param(
        [Parameter(Mandatory=$True)]
            $PreReqs
        )

    $PreReqs.Powershell.PackageSources | ForEach-Object {
        if(!(get-packagesource -Name $_.Name -ErrorAction SilentlyContinue)){
            Write-Host "Adding PackageSrouce: $($_.ProviderName)"
            Set-TLSVersion $_.TlsVer
            Register-PackageSource -Name $_.Name `
                -Location $_.Location `
                -ProviderName $_.ProviderName `
                -Debug:$_.Debug `
                -Trusted:$_.Trusted `
                -force `
                -ForceBootstrap
        } else {
            if ((Get-PackageSource -Name $_.Name).Trusted -ne $_.Trusted) {
                Set-PackageSource -Name $_.Name -Trusted:$_.Trusted -Force
            }
        }
    }

    $PreReqs.Powershell.Modules | ForEach-Object {
        if (Get-Module $_.Name) {
            Write-Host "Updating Module: $($_.Name)"
            Update-Module -Name $_.Name -Force
        } else {
            Write-Host "Installing Module: $($_.Name)"
            Install-Module -Name $_.Name -AllowClobber -Force -Scope AllUsers
        }
    }

    $PreReqs.Powershell.Packages | ForEach-Object {
        if (!(get-package | where-object -property name -eq $_.Name)) {
            Write-host "Installing Package: $($_.Name)"
            $pkg = (Install-Package $_.Name -ProviderName $_.ProviderName -Scope AllUsers -Force -SkipDependencies).Payload.Directories[0]
            Add-Type -Path (Get-ChildItem (Split-Path ($Pkg.location) -Parent) -Filter "$($_.AddTypeFilter)" -Recurse -File)[0].FullName
        }
    }

    $PreReqs.Other | ForEach-Object {
        $_.DetectionScriptBlocks | ForEach-Object {
            Invoke-Command -ScriptBlock ([ScriptBlock]::Create($_)) -NoNewScope 
        }
        
        If (!($Result)) {
            Write-Host "Installing: $($_.Name)"
        }

        $_.InstallScriptBlocks | ForEach-Object {
            Invoke-Command -ScriptBlock ([ScriptBlock]::Create($_)) -NoNewScope
        }
    }
}