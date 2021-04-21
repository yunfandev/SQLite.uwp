function CheckForUpdate {
    $url = "https://www.sqlite.org/download.html"
    $currentVersion = Get-Content "VERSION"
    $page = (Invoke-WebRequest -Uri $url).Content
    $versionPattern = "version (.*)\.<br>"
    $vsixPattern = "(\d{4}\/sqlite-uwp-.+\.vsix)'"
    if ($page -match $versionPattern) {
        $version = $Matches[1]
        if ($version -gt $currentVersion) {
            if ($page -match $vsixPattern) {
                return $version, ("https://www.sqlite.org/" + $Matches[1])
            } else {
                Write-Host "Prase package failed"
            }
        }
        return $version
    } else {
        throw "Parse failed"
    }
}

function CreateUpdate {
    param (
        [String]$version,
        [String]$downloadUrl
    )
    $versionFile = "VERSION"
    $fileName = [System.IO.Path]::GetFileName($downloadUrl)
    $folderName = [System.IO.Path]::GetFileNameWithoutExtension($downloadUrl)
    $nuspecFile = "SQLite.uwp.nuspec"
    $currentVersion = Get-Content $versionFile
    # Download file
    Invoke-WebRequest -Uri $downloadUrl  -OutFile $fileName
    # Update SQLite.uwp.nuspec
    ((Get-Content -Path $nuspecFile -Raw) -replace $currentVersion, $version) | Set-Content -Path $nuspecFile
    # Update VERSION
    Set-Content -Path $versionFile -value $version -NoNewline
    # Unzip file
    Expand-Archive -Path $fileName -Force
    # Copy SQLite.uwp.nuspec
    Copy-Item -Path $nuspecFile ($folderName + "/Redist/Retail")
    # Save current location
    $currentLocation = (Get-Location).Path
    Set-Location ($folderName + "/Redist/Retail")
    # Create new package
    nuget pack $nuspecFile
    # Push new package
    nuget push *.nupkg -ApiKey $env:APIKEY -Source https://api.nuget.org/v3/index.json
    Set-Location $currentLocation
    # Delete useless files
    Remove-Item -Recurse -Force $folderName
    Remove-Item -Recurse -Force $fileName
}

Set-Location $PSScriptRoot
$result = CheckForUpdate
if ($result.Count -le 1) {
    Write-Host "No update"
} else {
    Write-Host ("New version found " + $result[0])
    CreateUpdate $result[0] $result[1]
}