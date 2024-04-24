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
        ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
        If ($Application.Path) {
            If ($Application.NonRecurse) {
                $Files = Get-ChildItem $Application.Path
            } else {
                $Files = Get-ChildItem $Application.Path -Recurse     
            }
            
            $Files | `
                ForEach-Object {
                    Write-Host $_.FullName
                    If ($Application.Arguments) {
                        $Process = Start-Process -FilePath $_.FullName -ArgumentList "$($Application.Arguments)" -PassThru
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
        ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
    }
}