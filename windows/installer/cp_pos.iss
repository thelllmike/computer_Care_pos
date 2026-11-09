; Inno Setup script for CP POS (built by .github/workflows/windows-build.yml)
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{DC37E8D5-65BA-4BCB-8A70-4D5380D83C0F}
AppName=CP POS
AppVersion={#AppVersion}
AppPublisher=Clever Project
AppPublisherURL=https://cleverproject.lk
DefaultDirName={autopf}\CP POS
DefaultGroupName=CP POS
UninstallDisplayIcon={app}\cp_pos.exe
SetupIconFile=..\runner\resources\app_icon.ico
OutputDir=..\..\dist
OutputBaseFilename=CP_POS_Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\CP POS"; Filename: "{app}\cp_pos.exe"
Name: "{group}\Uninstall CP POS"; Filename: "{uninstallexe}"
Name: "{autodesktop}\CP POS"; Filename: "{app}\cp_pos.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\cp_pos.exe"; Description: "Launch CP POS"; Flags: nowait postinstall skipifsilent
