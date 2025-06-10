#define AppName "OCSInventory Agent"
#define AppVersion "3.0.0"
#define AppPublisher "OCSInventory"
#define AppURL "https://www.ocsinventory.com/"
#define AppExeName "agent-windows.exe"
#define AppPath "path_of_your_agent\OCSInventory-Agent"

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
LicenseFile={#AppPath}\setup\windows\media\licence.TXT
OutputDir=OCSInventory-Agent-Setup
OutputBaseFilename=OCSInventory-Agent-Setiup-{#AppVersion}
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

[UninstallRun]
Filename: "{app}\setup\windows\nssm.exe"; Parameters: "stop OCSInventory-Agent"; Flags: runhidden
Filename: "{app}\setup\windows\nssm.exe"; Parameters: "remove OCSInventory-Agent confirm"; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "C:\ProgramData\OCSInventory-Agent"

[Code]
var
  InputPage: TWizardPage;
  SILENT, SERVICE, NOW: Boolean;
  URL, USERNAME, PASSWORD, LOG_LEVEL, CERTIFICATE: String;
  URL_LABEL, USERNAME_LABEL, PASSWORD_LABEL, LOG_LEVEL_LABEL, CERTIFICATE_LABEL: TLabel;
  URL_INPUT, USERNAME_INPUT, PASSWORD_INPUT, CERTIFICATE_INPUT: TEdit;
  SERVICE_CHECKBOX, NOW_CHECKBOX: TNewCheckBox;
  LOG_LEVEL_COMBOBOX: TComboBox;
  CERTIFICATE_BUTTON: TButton;

procedure BrowseCertFile(Sender: TObject);
var
  FileName: String;
begin
  if GetOpenFileName('', FileName, '', 'Certificate Files|*.crt;*.pem|All Files|*.*', 'pem') then
  begin
    CERTIFICATE_INPUT.Text := FileName;
  end;
end;

procedure InitializeWizard;
begin
  SILENT := (Pos('/SILENT', GetCmdTail) > 0);
  
  // Initialize parameters from command-line if running silently
  if SILENT then
  begin
    URL := ExpandConstant('{param:URL}');
    USERNAME := ExpandConstant('{param:USERNAME}');
    PASSWORD := ExpandConstant('{param:PASSWORD}');
    SERVICE := (ExpandConstant('{param:SERVICE}') = 'True');
    NOW := (ExpandConstant('{param:NOW}') = 'True');
    LOG_LEVEL := ExpandConstant('{param:LOGLEVEL}');
    CERTIFICATE := ExpandConstant('{param:CERTIFICATE}');
  end
  else
  begin
    // If not silent, show configuration page
    InputPage := CreateCustomPage(wpLicense, 'Configuration', 'Please enter the configuration details:');
    
    URL_LABEL := TLabel.Create(InputPage);
    URL_LABEL.Parent := InputPage.Surface;
    URL_LABEL.Top := 30;
    URL_LABEL.Left := 10;
    URL_LABEL.Caption := 'Server URL:';
    URL_INPUT := TEdit.Create(InputPage);
    URL_INPUT.Parent := InputPage.Surface;
    URL_INPUT.Top := URL_LABEL.Top - 3;
    URL_INPUT.Left := URL_LABEL.Left + 100;
    URL_INPUT.Width := InputPage.SurfaceWidth - 110;
    URL_INPUT.Text := URL;

    USERNAME_LABEL := TLabel.Create(InputPage);
    USERNAME_LABEL.Parent := InputPage.Surface;
    USERNAME_LABEL.Top := URL_INPUT.Top + URL_INPUT.Height + 15;
    USERNAME_LABEL.Left := 10;
    USERNAME_LABEL.Caption := 'USERNAME:';
    USERNAME_INPUT := TEdit.Create(InputPage);
    USERNAME_INPUT.Parent := InputPage.Surface;
    USERNAME_INPUT.Top := USERNAME_LABEL.Top - 3;
    USERNAME_INPUT.Left := USERNAME_LABEL.Left + 100;
    USERNAME_INPUT.Width := InputPage.SurfaceWidth - 110;
    USERNAME_INPUT.Text := USERNAME;

    PASSWORD_LABEL := TLabel.Create(InputPage);
    PASSWORD_LABEL.Parent := InputPage.Surface;
    PASSWORD_LABEL.Top := USERNAME_INPUT.Top + USERNAME_INPUT.Height + 15;
    PASSWORD_LABEL.Left := 10;
    PASSWORD_LABEL.Caption := 'PASSWORD:';
    PASSWORD_INPUT := TEdit.Create(InputPage);
    PASSWORD_INPUT.Parent := InputPage.Surface;
    PASSWORD_INPUT.Top := PASSWORD_LABEL.Top - 3;
    PASSWORD_INPUT.Left := PASSWORD_LABEL.Left + 100;
    PASSWORD_INPUT.Width := InputPage.SurfaceWidth - 110;
    PASSWORD_INPUT.PASSWORDChar := '*';
    PASSWORD_INPUT.Text := PASSWORD;

    LOG_LEVEL_LABEL := TLabel.Create(InputPage);
    LOG_LEVEL_LABEL.Parent := InputPage.Surface;
    LOG_LEVEL_LABEL.Top := PASSWORD_INPUT.Top + PASSWORD_INPUT.Height + 15; // Position below PASSWORD_INPUT
    LOG_LEVEL_LABEL.Left := 10;
    LOG_LEVEL_LABEL.Caption := 'Log Level:';
    LOG_LEVEL_COMBOBOX := TComboBox.Create(InputPage);
    LOG_LEVEL_COMBOBOX.Parent := InputPage.Surface;
    LOG_LEVEL_COMBOBOX.Top := LOG_LEVEL_LABEL.Top - 3;
    LOG_LEVEL_COMBOBOX.Left := LOG_LEVEL_LABEL.Left + 100;
    LOG_LEVEL_COMBOBOX.Width := InputPage.SurfaceWidth - 110;
    LOG_LEVEL_COMBOBOX.Items.Add('Error');
    LOG_LEVEL_COMBOBOX.Items.Add('Warning');
    LOG_LEVEL_COMBOBOX.Items.Add('Info');
    LOG_LEVEL_COMBOBOX.Items.Add('Verbose');
    LOG_LEVEL_COMBOBOX.ItemIndex := 2; // Default to Info

    CERTIFICATE_LABEL := TLabel.Create(InputPage);
    CERTIFICATE_LABEL.Parent := InputPage.Surface;
    CERTIFICATE_LABEL.Top := LOG_LEVEL_COMBOBOX.Top + LOG_LEVEL_COMBOBOX.Height + 15;
    CERTIFICATE_LABEL.Left := 10;
    CERTIFICATE_LABEL.Caption := 'Certificate File:';
    
    CERTIFICATE_INPUT := TEdit.Create(InputPage);
    CERTIFICATE_INPUT.Parent := InputPage.Surface;
    CERTIFICATE_INPUT.Top := CERTIFICATE_LABEL.Top - 3;
    CERTIFICATE_INPUT.Left := CERTIFICATE_LABEL.Left + 100;
    CERTIFICATE_INPUT.Width := InputPage.SurfaceWidth - 200;
    
    CERTIFICATE_BUTTON := TButton.Create(InputPage);
    CERTIFICATE_BUTTON.Parent := InputPage.Surface;
    CERTIFICATE_BUTTON.Top := CERTIFICATE_INPUT.Top;
    CERTIFICATE_BUTTON.Left := CERTIFICATE_INPUT.Left + CERTIFICATE_INPUT.Width + 10;
    CERTIFICATE_BUTTON.Width := 75;
    CERTIFICATE_BUTTON.Caption := 'Browse...';
    CERTIFICATE_BUTTON.OnClick := @BrowseCertFile;
    
    SERVICE_CHECKBOX := TNewCheckBox.Create(InputPage);
    SERVICE_CHECKBOX.Parent := InputPage.Surface;
    SERVICE_CHECKBOX.Top := CERTIFICATE_INPUT.Top + CERTIFICATE_INPUT.Height + 10;
    SERVICE_CHECKBOX.Left := 10;
    SERVICE_CHECKBOX.Caption := 'Register service - agent must be launched automatically';
    SERVICE_CHECKBOX.Width := InputPage.SurfaceWidth - 110;
    SERVICE_CHECKBOX.Checked := SERVICE;

    NOW_CHECKBOX := TNewCheckBox.Create(InputPage);
    NOW_CHECKBOX.Parent := InputPage.Surface;
    NOW_CHECKBOX.Top := SERVICE_CHECKBOX.Top + SERVICE_CHECKBOX.Height + 10;
    NOW_CHECKBOX.Left := 10;
    NOW_CHECKBOX.Caption := 'Run agent now';
    NOW_CHECKBOX.Width := InputPage.SurfaceWidth - 110;
    NOW_CHECKBOX.Checked := NOW;
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  if SILENT then
    Exit;
  
  if CurPageID = InputPage.ID then
  begin
    if URL_INPUT.Text = '' then
    begin
      Log('Error: Please enter a valid URL.');
      Result := False;
    end
    else if USERNAME_INPUT.Text = '' then
    begin
      Log('Error: Please enter a valid USERNAME.');
      Result := False;
    end
    else if PASSWORD_INPUT.Text = '' then
    begin
      Log('Error: Please enter a valid PASSWORD.');
      Result := False;
    end
    else if CERTIFICATE_INPUT.Text = '' then
    begin
      Log('Error: Please select a certificate file.');
      Result := False;
    end;
  end;
end;

function GetURL: String;
begin
  if SILENT then
    Result := URL
  else
    Result := URL_INPUT.Text;
end;

function GetUSERNAME: String;
begin
  if SILENT then
    Result := USERNAME
  else
    Result := USERNAME_INPUT.Text;
end;

function GetPASSWORD: String;
begin
  if SILENT then
    Result := PASSWORD
  else
    Result := PASSWORD_INPUT.Text;
end;

function GetLOG_LEVEL: String;
begin
  if SILENT then
    Result := LOG_LEVEL
  else
  begin
    case LOG_LEVEL_COMBOBOX.Text of
      'Error': Result := '0';
      'Warning': Result := '1';
      'Info': Result := '2';
      'Verbose': Result := '3';
      else Result := '2'; // Default to Info if something goes wrong
    end;
  end;
end;

function GetCertificateFilePath: String;
begin
  if SILENT then
  begin
    Result := CERTIFICATE;
  end
  else
  begin
    Result := CERTIFICATE_INPUT.Text;
  end;
end;


function IsSERVICE: Boolean;
begin
  if SILENT then
    Result := SERVICE
  else
    Result := SERVICE_CHECKBOX.Checked;
end;

function IsNOW: Boolean;
begin
  if SILENT then
    Result := NOW
  else
    Result := NOW_CHECKBOX.Checked;
end;


function InstallServiceWithNSSM: Boolean;
var
  ResultCode: Integer;
  Command: String;
  NSSMPath: String;
begin
  Command := 'install OCSInventory-Agent "C:\Program Files\OCS Inventory Agent\setup\windows\daemon-windows.exe"';
  NSSMPath := 'C:\Program Files\OCS Inventory Agent\setup\windows\nssm.exe';
  Log('Installing service with NSSM: ' + NSSMPath + ' ' + Command);
  Result := Exec(NSSMPath, Command, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  if not Result then
    MsgBox('Failed to install service with NSSM. Error code: ' + IntToStr(ResultCode), mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  CommandAgentConfigure, CommandNOW: String;
begin

  try
    if CurStep = ssPostInstall then
    begin
      
      CommandAgentConfigure := '-f true -m 0 -p ' + GetPASSWORD() + ' -u ' + GetUSERNAME() + ' -s ' + GetURL() + ' -d "C:\ProgramData\OCSInventory-Agent"\inventory" -l "C:\ProgramData\OCSInventory-Agent"\agent.log"' + ' -v ' + GetLOG_LEVEL() + ' -c "' + GetCertificateFilePath()+'"';
      Log('Executing Command Agent Configuration: ' + ExpandConstant('{app}\{#AppExeName}') + ' ' + CommandAgentConfigure);
      Log('Cetificat path: ' + GetCertificateFilePath());
      if Exec(ExpandConstant('{app}\{#AppExeName}'), CommandAgentConfigure, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        Log('Successfully configured the agent: ' + ExpandConstant('{app}\{#AppExeName}'));
      end
      else
      begin
        Log('Failed to configure the agent ' + ExpandConstant('{app}\{#AppExeName}') + ' with code ' + IntToStr(ResultCode));
      end;

      if IsNOW then
      begin
        CommandNOW := '-f true -m 2 -p ' + GetPASSWORD() + ' -u ' + GetUSERNAME() + ' -s ' + GetURL() + ' -d "C:\ProgramData\OCSInventory-Agent"\inventory" -l "C:\ProgramData\OCSInventory-Agent"\agent.log"' + ' -v ' + GetLOG_LEVEL() + ' -c "' + GetCertificateFilePath()+'"';
        Log('Executing Command run agent: ' + ExpandConstant('{app}\{#AppExeName}') + ' ' + CommandNOW);
        
        if not Exec(ExpandConstant('{app}\{#AppExeName}'), CommandNOW, '', SW_HIDE, ewNoWait, ResultCode) then
        begin
          Log('Failed to run the agent ' + ExpandConstant('{app}\{#AppExeName}') + ' with code ' + IntToStr(ResultCode));
        end;
      end;

      if IsSERVICE then
      begin
        if not InstallServiceWithNSSM then
          Log('Failed to install service.');
      end;
    end;
  except
      Log('Exception in CurStepChanged: ');
  end;
end;
