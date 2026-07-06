; Packages `flutter build windows --release` into a single installer,
; ClaudeUsageMonitorSetup.exe (see .github/workflows/release.yml, which
; passes /DMyAppVersion=<version> on the iscc command line).
;
; Compile locally with:
;   iscc /DMyAppVersion=1.1.0 packaging\windows\installer.iss

#define MyAppName "Claude Usage Monitor"
#define MyAppPublisher "Alann Estrada"
#define MyAppExeName "claude_usage_monitor.exe"
#define MyAppURL "https://github.com/alann-estrada-KSH/claude_usage_monitor"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{2F7B7C9E-6B7B-4B7A-9C7E-6C1A4C1D9C7B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\ClaudeUsageMonitor
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\
OutputBaseFilename=ClaudeUsageMonitorSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
; Lets the installer close/relaunch a running instance instead of failing
; with a file-in-use error -- needed for the in-app updater (see
; lib/core/update/update_checker.dart) to run this silently over a live app.
CloseApplications=yes
RestartApplications=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
