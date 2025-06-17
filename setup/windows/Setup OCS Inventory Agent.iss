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
  ConnectionInputPage, ConfigInputPage: TInputQueryWizardPage;
  CheckPage: TWizardPage;
  URL, USERNAME, PASSWORD, CERTIFICATE, STORE_DATA_PATH, CONFIG_PATH, LOG_PATH: String;
  INVENTORY_MODE, LOG_LEVEL: Integer;
  InstallAsAServiceCheckBox, RunNowCheckBox: TNewCheckBox;
  ResultCode: Integer;

procedure InitializeWizard;
begin
  ConnectionInputPage := CreateInputQueryPage(wpLicense, ExpandConstant('{cm:AgentConfigurationPageTitle}'), ExpandConstant('{cm:AgentConfigurationPageDescription}'), ExpandConstant('{cm:MandatoryFields}'));
  
  ConnectionInputPage.Add('* URL:', False);
  ConnectionInputPage.Add('* Username:', False);
  ConnectionInputPage.Add('* Password:', False);
  ConnectionInputPage.Add('Certificate:', False);

  ConfigInputPage := CreateInputQueryPage(ConnectionInputPage.ID, ExpandConstant('{cm:AgentConfigurationPageTitle}'), ExpandConstant('{cm:AgentConfigurationPageDescription}'), ExpandConstant('{cm:MandatoryFields}'));

  ConfigInputPage.Add('Agent mode:', False);
  ConfigInputPage.Add('Log level:', False);

  CheckPage := CreateCustomPage(ConfigInputPage.ID, ExpandConstant('{cm:AgentConfigurationPageTitle}'), ExpandConstant('{cm:AgentConfigurationPageDescription}'));
  
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
    CERTIFICATE := ConnectionInputPage.Values[3];

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

    STORE_DATA_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent');
    CONFIG_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent\config.json');
    LOG_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent\ocsinventory-agent.log');

    if not DirExists(STORE_DATA_PATH) then
    begin
      CreateDir(STORE_DATA_PATH);
    end;

    SaveStringToFile(CONFIG_PATH, Format('{"url": "%s", "username": "%s", "password": "%s", "certificate": "%s", "bypass_certificate": false, "log_file": true, "log_level": %d, "mode": %d, "data_directory": "%s", "log_file_path": "%s"}', [URL, USERNAME, PASSWORD, CERTIFICATE, LOG_LEVEL, INVENTORY_MODE, STORE_DATA_PATH, LOG_PATH]), false);

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

[CustomeMessages]
AgentConfigurationPageTitle=Agent configuration
AgentConfigurationPageDescription=Please specify your own agent settings.
MandatoryFields=* Required fields are marked with an asterisk.
french.AgentConfigurationPageTitle=Configuration de l'agent
french.AgentConfigurationPageDescription=Veuillez spécifier vos propres paramètres d'agent.
french.MandatoryFields=* Les champs obligatoires sont marqués d'un astérisque.