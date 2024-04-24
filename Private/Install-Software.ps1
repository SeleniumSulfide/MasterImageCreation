Function Install-Software() {
    Param(
        [Parameter(Mandatory=$True)][String]$Path,
        [Parameter(Mandatory=$False)][String]$Arguments
    )
    Get-ChildItem $Path | %{
        Write-Host $_.FullName
        If ($Arguments) {
            Start-Process -FilePath $_.FullName -ArgumentList "$Arguments" -wait -PassThru | out-null
        } else {
            Start-Process -FilePath $_.Fullname -wait -PassThru | out-null
        }
    } 
}