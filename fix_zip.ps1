Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$cachePath = "$env:USERPROFILE\.gradle\caches"
$files = Get-ChildItem -Path $cachePath -Include *.jar, *.aar -Recurse -File

$cutoff = [datetime]"1980-01-01"
$newDate = [datetime]"2026-01-01"

foreach ($file in $files) {
    try {
        $archive = [System.IO.Compression.ZipFile]::Open($file.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
        $modified = $false
        foreach ($entry in $archive.Entries) {
            if ($entry.LastWriteTime -lt $cutoff) {
                $entry.LastWriteTime = $newDate
                $modified = $true
            }
        }
        $archive.Dispose()
        if ($modified) {
            Write-Host "Fixed $($file.Name)"
        }
    } catch {
        Write-Host "Error processing $($file.Name): $_"
    }
}
