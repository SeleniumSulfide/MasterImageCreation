<#
    This connects to FileShares and if the Credential is null, the code will request and then store the credential information
    The Creds are stored after the first connection so that after reboots the connection can be reestablished
#>
Function Connect-Fileshares() {
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline)]$FileShares
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
                $cred = Get-Credential -Message "<username>@smcusa.com" -UserName $FileShare.UserName
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
    If (!($State.Shares) -and $Shares) {
        $State | Add-Member -NotePropertyName "Shares" -NotePropertyValue $Shares
    } elseif ($Shares) {
        $State.Shares = $Shares
    }
}
