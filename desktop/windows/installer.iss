#ifndef AppVersion
  #define AppVersion "0.8.0"
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
