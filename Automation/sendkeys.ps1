

# Function to send a key to a process by name
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

# Example: Send ENTER to Notepad
Send-KeyToProcess -ProcessName "notepad" -Key "{ENTER}"
