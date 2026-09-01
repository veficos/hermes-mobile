#ifndef AppVersion
  #error AppVersion must be supplied by build-installer.ps1
#endif
#ifndef BundleDir
  #error BundleDir must be supplied by build-installer.ps1
#endif
#ifndef InstallerOutputDir
  #error InstallerOutputDir must be supplied by build-installer.ps1
#endif

#define AppName "Hermes Mobile"
#define AppExeName "hermes_mobile.exe"

[Setup]
AppId={{74A2BA43-1DB1-48F9-9810-A80C0C28E89A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Hermes Mobile
DefaultDirName={localappdata}\Programs\Hermes Mobile
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#InstallerOutputDir}
OutputBaseFilename=HermesMobile-Setup-{#AppVersion}-x64
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
