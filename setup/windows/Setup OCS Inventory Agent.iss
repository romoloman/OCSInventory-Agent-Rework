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
  CheckPage: TWizardPage;
  URL, USERNAME, PASSWORD, CERTIFICATE: String;
  LOG_LEVEL: Integer;
  InstallAsAServiceCheckBox, RunNowCheckBox: TNewCheckBox;
  ResultCode: Integer;

procedure InitializeWizard;
begin
  CONFIG_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent\config.json');
  InputPage := CreateInputQueryPage(wpLicense, 'Agent configuration', 'Please specify your own agent settings.', '* Required fields are marked with an asterisk.');
  
  InputPage.Add('* URL:', False);
  InputPage.Add('* Username:', False);
  InputPage.Add('* Password:', False);
  InputPage.Add('Log level:', False);
  InputPage.Add('Certificate:', False);
  
  InputPage.Values[0] := 'https://ocsinventory.example.com/';
  InputPage.Values[1] := 'admin';
  InputPage.Values[2] := 'admin';

  CheckPage := CreateCustomPage(InputPage.ID, 'Agent configuration', 'Please specify your own agent settings.');
  
  RunNowCheckBox := TNewCheckBox.Create(CheckPage);
  RunNowCheckBox.Parent := CheckPage.Surface;
  RunNowCheckBox.Top := 0;
  RunNowCheckBox.Left := 0;
  RunNowCheckBox.Width := CheckPage.SurfaceWidth;
  RunNowCheckBox.Caption := 'Run the agent now';
  RunNowCheckBox.Checked := True;

  InstallAsAServiceCheckBox := TNewCheckBox.Create(CheckPage);
  InstallAsAServiceCheckBox.Parent := CheckPage.Surface;
  InstallAsAServiceCheckBox.Top := 0;
  InstallAsAServiceCheckBox.Left := 0;
  InstallAsAServiceCheckBox.Width := CheckPage.SurfaceWidth;
  InstallAsAServiceCheckBox.Caption := 'Install agent as a service';
  InstallAsAServiceCheckBox.Checked := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  if CurPageID = InputPage.ID then
  begin    
    if InputPage.Values[0] = '' then
    begin
      MsgBox('Error: URL is a mandatory field!', mbError, MB_OK);
      Result := False;
    end
    else if InputPage.Values[1] = '' then
    begin
      MsgBox('Error: Username is a mandatory field!', mbError, MB_OK);
      Result := False;
    end
    else if InputPage.Values[2] = '' then
    begin
      MsgBox('Error: Password is a mandatory field!', mbError, MB_OK);
      Result := False;
    end;
    
    if InputPage.Values[3] <> '' then
    begin
      LOG_LEVEL := StrToInt64Def(InputPage.Values[0], 1);
    end;
  end;
end;