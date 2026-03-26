#define AppId "{{C3B7680A-31A8-4E0E-A8A9-7F16300E2B29}"
#define AppName "Gift Ledger"
#define AppPublisher "final00000000"
#define AppExeName "Gift_Ledger.exe"

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef AppBuild
  #define AppBuild "0"
#endif

#ifndef AppChannel
  #define AppChannel "stable"
#endif

#ifndef SourceDir
  #define SourceDir "..\\..\\build\\windows\\x64\\runner\\Release"
#endif

#ifndef OutputDir
  #define OutputDir "..\\..\\build\\windows\\installer"
#endif

#ifndef OutputBaseName
  #define OutputBaseName "gift_ledger-" + AppChannel + "-windows-v" + AppVersion + "-build" + AppBuild + "-setup"
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/final00000000/Gift_Ledger
AppSupportURL=https://github.com/final00000000/Gift_Ledger/issues
DefaultDirName={autopf}\Gift Ledger
DefaultGroupName=Gift Ledger
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseName}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "chinesesimplified"; MessagesFile: "Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Gift Ledger"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\Gift Ledger"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动 Gift Ledger"; Flags: nowait postinstall skipifsilent
