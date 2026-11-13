#ifndef AppVersion
  #define AppVersion "0.9.1"
#endif
[Setup]
AppId={{68B4A41C-0DCA-4281-BE65-D3C4A4AE51D8}
AppName=MusicON
AppVersion={#AppVersion}
AppPublisher=MusicON
AppPublisherURL=https://github.com/lenonronaldo2014-prog/MusicON
DefaultDirName={localappdata}\Programs\MusicON
DefaultGroupName=MusicON
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=MusicON-Setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\MusicON.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MusicON"; Filename: "{app}\MusicON.exe"
Name: "{autodesktop}\MusicON"; Filename: "{app}\MusicON.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\MusicON.exe"; Description: "Abrir MusicON"; Flags: nowait postinstall skipifsilent
Filename: "{app}\MusicON.exe"; Flags: nowait skipifnotsilent; Check: IsInAppUpdate

[Code]
const
  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{68B4A41C-0DCA-4281-BE65-D3C4A4AE51D8}_is1';

function OpenProcess(Access: Cardinal; InheritHandle: Integer; ProcessId: Cardinal): THandle;
  external 'OpenProcess@kernel32.dll stdcall';
function WaitForSingleObject(Handle: THandle; Milliseconds: Cardinal): Cardinal;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function CloseHandle(Handle: THandle): Integer;
  external 'CloseHandle@kernel32.dll stdcall';

function IsInAppUpdate: Boolean;
begin
  Result := ExpandConstant('{param:MUSICONUPDATE|}') <> '';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  InstalledDirectory: String;
  ProcessId: Integer;
  ProcessHandle: THandle;
  WaitResult: Cardinal;
begin
  Result := '';
  if not IsInAppUpdate then
    Exit;

  if not RegQueryStringValue(HKCU64, UninstallKey, 'InstallLocation', InstalledDirectory) or
     (CompareText(RemoveBackslashUnlessRoot(InstalledDirectory), ExpandConstant('{app}')) <> 0) or
     not FileExists(ExpandConstant('{app}\MusicON.exe')) then
  begin
    Result := 'Não foi possível localizar a instalação atual do MusicON.';
    Exit;
  end;

  ProcessId := StrToIntDef(ExpandConstant('{param:MUSICONUPDATE|0}'), 0);
  if ProcessId <= 0 then
  begin
    Result := 'Não foi possível identificar o MusicON em execução.';
    Exit;
  end;

  ProcessHandle := OpenProcess($00100000, 0, ProcessId);
  if ProcessHandle = 0 then
  begin
    { ERROR_INVALID_PARAMETER: the previous process has already exited. }
    if DLLGetLastError <> 87 then
      Result := 'Não foi possível verificar se o MusicON fechou.';
    Exit;
  end;

  Log('Waiting for the current MusicON process to exit.');
  WaitResult := WaitForSingleObject(ProcessHandle, 30000);
  CloseHandle(ProcessHandle);
  if WaitResult <> 0 then
    Result := 'O MusicON ainda está aberto. Feche o aplicativo e tente atualizar novamente.';
end;
