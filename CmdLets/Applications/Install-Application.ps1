Function Install-Application() {
    Param(
        [Parameter(Mandatory=$True)]
            $Application,
        [Parameter(Mandatory=$True)]
        [System.IO.FileSystemInfo]
            $Path
    )

    ForEach ($ScriptBlock in $Application.PreScriptBlocks) { 
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }

    If ($Application.Recurse) {
        $Files = Get-ChildItem (Join-Path $Path $Application.InstallerMask)
    } else {
        $Files = Get-ChildItem (Join-Path $Path $Application.InstallerMask) -Recurse     
    }

    $Files | `
        ForEach-Object {
            Write-Host $_.FullName
            If ($Application.Arguments -ne "") {
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

    ForEach ($ScriptBlock in $Application.PostScriptBlocks) { 
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope
    }
}