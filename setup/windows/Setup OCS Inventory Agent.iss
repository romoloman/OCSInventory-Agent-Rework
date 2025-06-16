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
Source: "{#AppPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#AppPath}\setup\windows\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"

[Code]
var
  CONFIG_PATH: String;
  ConnectionInputPage, ConfigInputPage: TInputQueryWizardPage;
  CheckPage: TWizardPage;
  URL, USERNAME, PASSWORD, CERTIFICATE: String;
  INVENTORY_MODE, LOG_LEVEL: Integer;
  InstallAsAServiceCheckBox, RunNowCheckBox: TNewCheckBox;
  ResultCode: Integer;

procedure InitializeWizard;
begin
  CONFIG_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent\config.json');
  ConnectionInputPage := CreateInputQueryPage(wpLicense, 'Agent configuration', 'Please specify your own agent settings.', '* Required fields are marked with an asterisk.');
  
  ConnectionInputPage.Add('* URL:', False);
  ConnectionInputPage.Add('* Username:', False);
  ConnectionInputPage.Add('* Password:', False);
  ConnectionInputPage.Add('Certificate:', False);

  ConfigInputPage := CreateInputQueryPage(ConnectionInputPage.ID, 'Agent configuration', 'Please specify your own agent settings.', '* Required fields are marked with an asterisk.');

  ConfigInputPage.Add('Agent mode:', False);
  ConfigInputPage.Add('Log level:', False);

  CheckPage := CreateCustomPage(ConfigInputPage.ID, 'Agent configuration', 'Please specify your own agent settings.');
  
  RunNowCheckBox := TNewCheckBox.Create(CheckPage);
  RunNowCheckBox.Parent := CheckPage.Surface;
  RunNowCheckBox.Top := 0;
  RunNowCheckBox.Left := 0;
  RunNowCheckBox.Width := CheckPage.SurfaceWidth;
  RunNowCheckBox.Caption := 'Run the agent now';
  RunNowCheckBox.Checked := True;

  InstallAsAServiceCheckBox := TNewCheckBox.Create(CheckPage);
  InstallAsAServiceCheckBox.Parent := CheckPage.Surface;
  InstallAsAServiceCheckBox.Top := RunNowCheckBox.Top + 50;
  InstallAsAServiceCheckBox.Left := 0;
  InstallAsAServiceCheckBox.Width := CheckPage.SurfaceWidth;
  InstallAsAServiceCheckBox.Caption := 'Install agent as a service';
  InstallAsAServiceCheckBox.Checked := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  if CurPageID = ConnectionInputPage.ID then
  begin    
    if ConnectionInputPage.Values[0] = '' then
    begin
      MsgBox('Error: URL is a mandatory field!', mbError, MB_OK);
      Result := False;
    end
    else if ConnectionInputPage.Values[1] = '' then
    begin
      MsgBox('Error: Username is a mandatory field!', mbError, MB_OK);
      Result := False;
    end
    else if ConnectionInputPage.Values[2] = '' then
    begin
      MsgBox('Error: Password is a mandatory field!', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    URL := ConnectionInputPage.Values[0];
    USERNAME := ConnectionInputPage.Values[1];
    PASSWORD := ConnectionInputPage.Values[2];
    CERTIFICATE := ConnectionInputPage.Values[4];

    if ConfigInputPage.Values[0] <> '' then
    begin
      INVENTORY_MODE := StrToInt64Def(ConfigInputPage.Values[0], 1);
    end
    else
    begin
      INVENTORY_MODE := 2;
    end;

    if ConfigInputPage.Values[1] <> '' then
    begin
      LOG_LEVEL := StrToInt64Def(ConfigInputPage.Values[1], 1);
    end
    else
    begin
      LOG_LEVEL := 2;
    end;

    SaveStringToFile(CONFIG_PATH, Format('{"url": %s, "username": %s, "password": %s, "certificate": %s, "bypass_certificate": false, "log_file": true, "log_level": %d, "mode": %d, "data_directory": ExpandConstant('{commonappdata}\OCSInventory-Agent\data'), "log_file_path": ExpandConstant('{commonappdata}\OCSInventory-Agent\data')}', [URL, USERNAME, PASSWORD, CERTIFICATE, LOG_LEVEL, INVENTORY_MODE]));

    if InstallAsAServiceCheckBox.Checked then
    begin
      Exec('echo', 'Hello World', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;

    if RunNowCheckBox.Checked then
    begin
      Exec('echo', 'Hello World', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;