param(
)



$prevPwd = $PWD

try {
    $base = (Get-Item $PSScriptRoot)
    Set-Location ($base.Fullname)
    

    $base = "build/zmpap"

    # Delete previous builds
    Remove-Item -Recurse -Force -ErrorAction Ignore  "$base" > $null
    Remove-Item -Force -ErrorAction Ignore "$base.zip" > $null

    # Create structure
    New-Item "$base" -ItemType Directory > $null

    # Binaries
    Copy-Item "*.gscc" "$base" > $null
    Copy-Item "*.luac" "$base" > $null
    Copy-Item "*.csv" "$base" > $null
    Copy-Item "metadata.json" "$base" > $null
    # License
    Copy-Item "README.md" "$base" > $null
    Copy-Item "LICENSE" "$base" > $null

    # Compress
    Compress-Archive -LiteralPath "$base" -DestinationPath "$base.zip" > $null

    Write-Host "Packaged to '$base.zip'"
}
finally {
    $prevPwd | Set-Location
}