Param(
  [string]$Version = "",
  [string]$BinDir = "",
  [switch]$Verify
)

$ErrorActionPreference = "Stop"
$githubOwner = "agentmaurice"
$githubRepo = "localmaurice"
$bin = "localmaurice"

function Get-OSArch {
  $os = "windows"
  $arch = $env:PROCESSOR_ARCHITECTURE
  switch ($arch.ToLower()) {
    "amd64" { $arch = "amd64" }
    "arm64" { $arch = "arm64" }
    default { throw "Unsupported arch: $arch" }
  }
  return @($os, $arch)
}

function Download($url, $dest) {
  Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

try {
  $pair = Get-OSArch
  $os = $pair[0]
  $arch = $pair[1]

  if ([string]::IsNullOrEmpty($Version)) {
    $latest = Invoke-RestMethod -Method GET -Uri "https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest"
    if ($null -eq $latest.tag_name) { throw "Cannot determine latest release tag" }
    $Version = $latest.tag_name
  }

  $asset = "${bin}_${os}_${arch}.zip"
  $base = "https://github.com/$githubOwner/$githubRepo/releases/download/$Version"
  $urlAsset = "$base/$asset"
  $urlSums = "$base/sha256sums.txt"

  $tmp = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath()) -Name ("${bin}_" + [System.Guid]::NewGuid().ToString())
  $zipPath = Join-Path $tmp.FullName "pkg.zip"
  Write-Host "Downloading $urlAsset"
  Download $urlAsset $zipPath

  if ($Verify.IsPresent) {
    $sumPath = Join-Path $tmp.FullName "sha256sums.txt"
    try { Download $urlSums $sumPath } catch {}
    if (Test-Path $sumPath) {
      $hash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLower()
      $name = $asset
      $match = Select-String -Path $sumPath -Pattern $name
      if ($match) {
        $expected = ($match.Line -split ' ')[0].ToLower()
        if ($expected -ne $hash) { throw "Checksum mismatch for $asset" }
      }
    }
  }

  $extract = Join-Path $tmp.FullName "x"
  Expand-Archive -Path $zipPath -DestinationPath $extract -Force
  # The archive contains a binary named like "localmaurice_windows_amd64.exe"
  $assetName = "${bin}_${os}_${arch}.exe"
  $srcExe = Join-Path $extract $assetName

  # Verify binary was extracted
  if (!(Test-Path $srcExe)) {
    throw "Binary '$assetName' not found in archive"
  }

  if ([string]::IsNullOrEmpty($BinDir)) {
    $homeBin = Join-Path $env:USERPROFILE ".local\bin"
    $BinDir = $homeBin
  }
  if (!(Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir | Out-Null }

  Copy-Item $srcExe (Join-Path $BinDir "$bin.exe") -Force
  Write-Host "Installed to $BinDir\$bin.exe"
  Write-Host "Ensure $BinDir is in your PATH."
}
catch {
  Write-Error $_
  exit 1
}
