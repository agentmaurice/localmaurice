Param(
  [string]$Version = "",
  [string]$BinDir = ""
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

  $sumPath = Join-Path $tmp.FullName "sha256sums.txt"
  Download $urlSums $sumPath
  $hash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLower()
  $match = Select-String -Path $sumPath -Pattern [regex]::Escape($asset) | Select-Object -First 1
  if (-not $match) { throw "Checksum not found for $asset" }
  $expected = ($match.Line -split '\s+')[0].ToLower()
  if ($expected -ne $hash) { throw "Checksum mismatch for $asset" }

  $extract = Join-Path $tmp.FullName "x"
  Expand-Archive -Path $zipPath -DestinationPath $extract -Force
  $candidates = @(
    (Join-Path $extract "$bin.exe"),
    (Join-Path $extract "${bin}_${os}_${arch}.exe")
  )
  $srcExe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $srcExe) {
    $srcExe = Get-ChildItem -Path $extract -Recurse -File -Filter "*.exe" |
      Where-Object { $_.Name -eq "$bin.exe" -or $_.Name -eq "${bin}_${os}_${arch}.exe" } |
      Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not $srcExe) { throw "Binary '$bin.exe' not found in archive" }

  if ([string]::IsNullOrEmpty($BinDir)) {
    $BinDir = Join-Path $env:USERPROFILE ".local\bin"
  }
  if (!(Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir | Out-Null }

  Copy-Item $srcExe (Join-Path $BinDir "$bin.exe") -Force
  Write-Host "Installed $bin $Version to $BinDir\$bin.exe"
  Write-Host "Ensure $BinDir is in your PATH."
}
catch {
  Write-Error $_
  exit 1
}
