$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $project
if (-not $env:JAVA_HOME) { throw 'JAVA_HOME deve apontar para um JDK 21 Windows.' }
$support=Join-Path $project 'windows/support'
New-Item -ItemType Directory -Force -Path $support | Out-Null
& (Join-Path $project 'desktop/extractor/gradlew.bat') -p (Join-Path $project 'desktop/extractor') bundle --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar a busca.' }
Copy-Item -LiteralPath 'desktop/extractor/build/libs/musicon-extractor.jar' -Destination $support
$licenses=Join-Path $support 'licenses'
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -Path 'desktop/extractor/build/licenses/*' -Destination $licenses -Recurse -Force
$runtime=Join-Path $support 'runtime'
if (-not (Test-Path -LiteralPath $runtime)) {
  & (Join-Path $env:JAVA_HOME 'bin/jlink.exe') --add-modules java.base,java.compiler,java.net.http,java.logging,java.xml,java.desktop,java.scripting,java.sql,jdk.dynalink,jdk.crypto.ec,jdk.unsupported --output $runtime --strip-debug --no-header-files --no-man-pages --compress=2
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar o runtime.' }
}
Copy-Item -LiteralPath LICENSE -Destination (Join-Path $support 'MusicON-LICENSE')
Copy-Item -LiteralPath third_party/NewPipeExtractor-LICENSE -Destination (Join-Path $support 'NewPipeExtractor-LICENSE')
Copy-Item -LiteralPath desktop/windows/THIRD-PARTY.txt -Destination $support
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Falha nas dependências.' }
flutter build windows --release -t lib/main_windows.dart
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o MusicON Windows.' }
$release=Join-Path $project 'build/windows/x64/runner/Release'
$vswhere='C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe'
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$crt=Get-ChildItem -Path (Join-Path $vs 'VC/Redist/MSVC') -Directory -Recurse -Filter '*.CRT' |
  Where-Object { $_.Parent.Name -eq 'x64' -and (Test-Path (Join-Path $_.FullName 'vcruntime140.dll')) } |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Runtime C++ x64 nao encontrado no Visual Studio.' }
Get-ChildItem -LiteralPath $crt.FullName -Filter *.dll | Copy-Item -Destination $release
New-Item -ItemType Directory -Force -Path dist | Out-Null
Compress-Archive -Path (Join-Path $release '*') -DestinationPath dist/MusicON-Windows-x64.zip -Force
$iscc='C:/Program Files (x86)/Inno Setup 6/ISCC.exe'
if (-not (Test-Path -LiteralPath $iscc)) { throw 'Instale Inno Setup 6 para gerar o instalador.' }
& $iscc desktop/windows/installer.iss
if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar o instalador.' }
Get-FileHash -LiteralPath dist/MusicON-Setup.exe,dist/MusicON-Windows-x64.zip -Algorithm SHA256 | ForEach-Object { "$($_.Hash.ToLower())  $(Split-Path $_.Path -Leaf)" } | Set-Content -Encoding UTF8 dist/SHA256SUMS-Windows.txt
