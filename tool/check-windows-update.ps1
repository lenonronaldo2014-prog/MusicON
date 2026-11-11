$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Run this only on an isolated CI runner.' }
$expected = (Get-Item -LiteralPath build/windows/x64/runner/Release/MusicON.exe).VersionInfo.ProductVersion
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{68B4A41C-0DCA-4281-BE65-D3C4A4AE51D8}_is1'
if (Test-Path -LiteralPath $key) { throw 'A MusicON installation already exists.' }
$fixture = Join-Path $env:RUNNER_TEMP 'MusicON update fixture'
$downloads = Join-Path $env:RUNNER_TEMP 'musicon-update-fixtures'
gh release download v0.8.2 --repo lenonronaldo2014-prog/MusicON --pattern MusicON-Setup.exe --dir $downloads
if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the previous installer.' }
$previous = Join-Path $downloads 'MusicON-Setup.exe'
if ((Get-FileHash -LiteralPath $previous).Hash -ne '726d10bea4491d225be8bc176d7c68f34b89202bd6dd07b58386a67739a496c0') {
  throw 'Previous installer checksum mismatch.'
}
$directory = "/DIR=`"$fixture`""
$argsBase = @('/SP-', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/NOCLOSEAPPLICATIONS', $directory)
$setup = Start-Process -FilePath $previous -ArgumentList $argsBase -WindowStyle Hidden -PassThru
if (-not $setup.WaitForExit(120000) -or $setup.ExitCode -ne 0) { throw 'Fixture installation failed.' }
$exe = Join-Path $fixture 'MusicON.exe'
if ((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion -ne '0.8.2+14') {
  throw 'Unexpected fixture version.'
}

$holder = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-Command', '"Start-Sleep -Seconds 20"') -WindowStyle Hidden -PassThru
$log = Join-Path $env:RUNNER_TEMP 'musicon-update-install.log'
$setup = Start-Process -FilePath (Resolve-Path dist/MusicON-Setup.exe).Path -ArgumentList (
  $argsBase + @("/MUSICONUPDATE=$($holder.Id)", "/LOG=`"$log`"")
) -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 4
if ($setup.HasExited -or (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion -ne '0.8.2+14') {
  throw 'Setup did not wait for the previous process.'
}
if (-not $setup.WaitForExit(120000) -or $setup.ExitCode -ne 0) {
  if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Tail 35 }
  throw 'In-app update failed.'
}
if (-not (Select-String -LiteralPath $log -SimpleMatch 'Waiting for the current MusicON process to exit.' -Quiet)) {
  throw 'The installer did not exercise the process wait.'
}
$app = Get-Process MusicON -ErrorAction SilentlyContinue | Where-Object Path -eq $exe
if (-not $app) { throw 'MusicON did not reopen after the update.' }
try {
  if ((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion -ne $expected) {
    throw 'Wrong version after reopening.'
  }
  "Windows update verified: 0.8.2 -> $expected, wait and restart passed."
} finally {
  $app | Stop-Process
}
