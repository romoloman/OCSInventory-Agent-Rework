#define AppName "OCSInventory Agent"
#define AppVersion "3.0.0"
#define AppPublisher "OCSInventory"
#define AppURL "https://www.ocsinventory.com/"
#define AppExeName "agent-windows.exe"
#define AppPath "Path_of_your_agent\OCSInventory-Agent"

[Setup]
AppId={{652EB54C-0A14-46AF-9F06-3BA7C294AFC9}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
LicenseFile={#AppPath}\setup\windows\media\license.txt
OutputDir=OCSInventory-Agent-Setup
OutputBaseFilename=OCSInventory-Agent-Setup-{#AppVersion}
SetupIconFile={#AppPath}\setup\windows\media\icone_ocs.ico
SolidCompression=yes
UninstallDisplayIcon={#AppPath}\setup\windows\media\icone_ocs.ico
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
Source: "JSONConfig.dll"; Flags: dontcopy
Source: "{#AppPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#AppPath}\setup\windows\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"

[Code]
var
  CONFIG_PATH: String;
  InputPage: TInputQueryWizardPage;
  URL, USERNAME, PASSWORD, LOG_LEVEL, CERTIFICATE: String;
  ResultCode: Integer;

procedure InitializeWizard;
begin
  CONFIG_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent\config.json');
  InputPage := CreateInputQueryPage(wpInstalling, 'Agent configuration', 'Please specify your own agent settings.', '* Required fields are marked with an asterisk.');
  
  InputPage.Add('* URL:', False);
  InputPage.Add('* Username:', False);
  InputPage.Add('* Password:', False);
  InputPage.Add('LogLevel:', False);
  InputPage.Add('Certificate:', False);
  
  InputPage.Values[0] := 'https://ocsinventory.example.com/ocsinventory';
  InputPage.Values[1] := 'ocsuser';
  InputPage.Values[2] := 'ocspassword';
  InputPage.Values[3] := '2';
  InputPage.Values[4] := '';
end;