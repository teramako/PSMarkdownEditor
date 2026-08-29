
$webViewPackageUrl = 'https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/1.0.4191.47'

$webView2UserDataDir = Join-Path $PSScriptRoot webview2_userdata
if (-not (Test-Path -PathType Container -Path $webView2UserDataDir)) {
    New-Item -ItemType Directory -Path $webView2UserDataDir -Verbose
}

$libsDir = Join-Path $PSScriptRoot libs
if (-not (Test-Path -Path $libsDir -PathType Container)) {
    New-Item -ItemType Directory -Path $libsDir -Verbose

    $fileName = Join-Path $PSScriptRoot 'Microsoft.Web.WebView2.nupkg'
    if (-not (Test-Path -Path $fileName)) {
        Invoke-WebRequest -Uri $webViewPackageUrl -OutFile $fileName
    }
    $pkgFile = Get-Item $fileName
    try {
        $fs = $pkgFile.OpenRead()
        $zip = [System.IO.Compression.ZipArchive]::new($fs, [System.IO.Compression.ZipArchiveMode]::Read)

        $loaderFile = 'runtimes/{0}/native/WebView2Loader.dll' -f [System.Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier
        $count = 0
        foreach ($zipEntry in $zip.Entries) {
            if ($zipEntry.FullName -like 'lib_manual/netcoreapp3.0/*.dll' -or $zipEntry.FullName -eq $loaderFile ) {
                $outFile = Join-Path $libsDir $zipEntry.Name
                try {
                    $sr = $zipEntry.Open()
                    $fileStream = [IO.File]::OpenWrite($outFile)
                    $buf = [byte[]]::new(4096)
                    while ($true) {
                        $read = $sr.Read($buf, 0, $buf.Length)
                        if ($read -eq 0) { break; }
                        $fileStream.Write($buf, 0, $read)
                    }
                    $count++;
                    Write-Progress -Activity "Extract DLLs" -Status $zipEntry.Name -PercentComplete ([int]($count*100/4))
                } finally {
                    $fileStream.Dispose()
                    $sr.Dispose()
                }
            }
        }
        Get-ChildItem $libsDir
    } finally {
        Write-Progress -Activity "Extract DLLs" -Completed
        $zip.Dispose()
        $fs.Dispose()
    }
}

$shortcutFile = Join-Path $PSScriptRoot MDView.lnk
if (-not (Test-Path $shortcutFile)) {
    $conhost = "${env:windir}\system32\conhost.exe"
    $ps1File = Join-Path $PSScriptRoot MDView.ps1
    Write-Host ("Shortcut TargetPath: {0}" -f $targetPath)

    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutFile)
    $shortcut.TargetPath = $conhost
    $shortcut.Arguments = '--headless pwsh -WindowStyle Hidden -NoProfile -File "{0}"' -f $ps1File
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Save()
}