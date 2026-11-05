Function Confirm-LibraryApplicationInstall() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
            $Application
    )
    Begin {

        $64Keys = "hklm:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | `
            Get-Childitem | `
            Where-Object { 
                $_.Property -Contains "DisplayName" -and `
                $_.Property -NotContains "SystemComponent"
            }

        $32Keys = "hklm:\\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | `
            Get-Childitem | `
            Where-Object { 
                $_.Property -Contains "DisplayName" -and `
                $_.Property -NotContains "SystemComponent"
            }
        $Results = @()
    }
    Process{
        ForEach ($Item in $Application) {
            $Result = $null
            Write-Host "Validating Install: $($Item.Name)"
            ForEach ($Name in $Item.Detection.Displayname) {
                Switch ($Name.Architecture) {
                    "x64" {
                        $Key = $64Keys | Where-Object {($_ | Get-ItemPropertyValue -Name Displayname) -Like $Name.Name }
                    }
                    "x32" {
                        $Key = $32Keys | Where-Object {($_ | Get-ItemPropertyValue -Name Displayname) -Like $Name.Name }
                    }
                    Default {
                        Throw "Value $($Name.Architecture) invalid. Use x32 or x64."
                    }
                }
                If ($Null -eq $Key) {
                    Write-Verbose "Not Found: $($Name.Architecture)-$($Name.Name)"
                    $Result = $False
                } elseif ($Null -eq $Result) {
                    Write-Verbose "Found: $($Name.Architecture)-$($Name.Name)"
                    $Result = $True
                }
            }

            ForEach ($Property in $Item.Detection.Registry) {
                $Value = Get-ItemPropertyValue -Path $Property.Path -Name $Property.Name -ErrorAction SilentlyContinue
                If ($Value -ne $Property.Value) {
                    Write-Verbose "Not Found: $($Property.Path)-$($Property.Name)"
                    $Result = $False
                } elseif ($Null -eq $Result) {
                    Write-Verbose "Found: $($Property.Path)-$($Property.Name)"
                    $Result = $true
                }
            }

            ForEach ($Path in $Item.Detection.File) {
                $Value = Test-Path $Path -ErrorAction SilentlyContinue
                If (!($Value)) {
                    Write-Verbose "Not Found: $Path"
                    $Result = $False
                } elseif ($Null -eq $Result) {
                    Write-Verbose "Found: $Path"
                    $Result = $True
                }
            }

            $Results += [PSCustomObject]@{
                Name = $Item.Name
                Found = $Result
            }
        }
    }
    End{
        $Results
    }
}