//
//  MyInstallerPane.m
//  config-agent-ocs
//
//  Created by Factorfx Factorfx on 18/06/2024.
//

#import "MyInstallerPane.h"

@implementation MyInstallerPane

- (NSString *)title
{
    return [[NSBundle bundleForClass:[self class]] localizedStringForKey:@"PaneTitle" value:nil table:nil];
}

- (NSArray *) logLevels {
    return [NSArray arrayWithObjects:@"Error", @"Warning", @"Info", @"Verbose", nil];
}

- (void)didEnterPane:(InstallerSectionDirection)dir {
    NSAlert *cfgFileExistsWrn;
    filemgr = [ NSFileManager defaultManager];
    
    if ([filemgr fileExistsAtPath:@"/etc/ocsinventory-agent/inventory.json"]) {
        //We display a warning dialog
        cfgFileExistsWrn = [[NSAlert alloc] init];
        
        [cfgFileExistsWrn setMessageText:NSLocalizedStringFromTableInBundle(@"Already_conf_warn",nil,[NSBundle bundleForClass:[self class]], @"Warning about already existing cofiguration file")];
        [cfgFileExistsWrn setInformativeText:NSLocalizedStringFromTableInBundle(@"Already_conf_warn_comment",nil,[NSBundle bundleForClass:[self class]], @"Warning about already existing configuration file comment")];
        [cfgFileExistsWrn addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Yes",nil,[NSBundle bundleForClass:[self class]], @"Yes button")];
        [cfgFileExistsWrn addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"No",nil,[NSBundle bundleForClass:[self class]], @"No button")];
        [cfgFileExistsWrn setAlertStyle:NSAlertStyleInformational];
        
        
        if ([cfgFileExistsWrn runModal] != NSAlertFirstButtonReturn) {
            // No button was clicked, we don't display config pane
            [self gotoNextPane];
        }
    }
    
    // Optional: Pre-fill fields or perform setup logic when the pane is shown
    self->server.stringValue = @"http://example.com";
    self->username.stringValue = @"";
    self->password.stringValue = @"";
    self->serviceMode.state = NSControlStateValueOff;
    self->runNow.state = NSControlStateValueOff;
    
    //Defaults for loglevel droping list
    [logLevelList removeAllItems];
    [logLevelList addItemWithTitle: @"Error"];
    [logLevelList addItemWithTitle: @"Warning"];
    [logLevelList addItemWithTitle: @"Info"];
    [logLevelList addItemWithTitle: @"Verbose"];
    [logLevelList selectItemWithTitle: @"Info"];
}

- (IBAction) chooseLogLevel:(id)sender {
    NSString *logLevel = [logLevelList titleOfSelectedItem];
    
    //We show the selected log level
    [logLevelList setTitle:logLevel];
}

- (BOOL)shouldExitPane:(InstallerSectionDirection)direction {
    // Validate and process user input before exiting the pane
    if (direction == InstallerDirectionForward) {
        if (self->server.stringValue.length == 0 || self->username.stringValue.length == 0 || self->password.stringValue.length == 0) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Incomplete Information"];
            [alert setInformativeText:@"Please fill in all fields."];
            [alert addButtonWithTitle:@"OK"];
            [alert setAlertStyle:NSAlertStyleWarning];
            [alert runModal];
            return NO; // Prevent advancing if fields are incomplete
        }
        
        // Save configuration or perform actions with the entered data
        NSString *server = self->server.stringValue;
        NSString *username = self->username.stringValue;
        NSString *password = self->password.stringValue;
        BOOL serviceModeEnabled = (self->serviceMode.state == NSControlStateValueOn);
        BOOL runNowEnabled = (self->runNow.state == NSControlStateValueOn);
        NSString *logLevel = [logLevelList titleOfSelectedItem];
        
        // Example: Save to a temporary file or perform further processing
        NSLog(@"Server: %@, Username: %@, Password: %@, LogLevel: %@, Service Mode: %@, Run now: %@", server, username, password, logLevel, serviceModeEnabled ? @"Yes" : @"No", runNowEnabled ? @"Yes" : @"No");
        
        // Example: Save to a temporary file or perform further processing
        NSString *configContent = [NSString stringWithFormat:@"server=%@\nusername=%@\npassword=%@\nlogLevel=%@\nserviceMode=%@\nrunNow=%@\n", server, username, password, logLevel, serviceModeEnabled ? @"yes" : @"no", runNowEnabled ? @"yes" : @"no"];
        NSString *tmpConfigFilePath = @"/tmp/installer_config.txt";
        [configContent writeToFile:tmpConfigFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            
    }
    
    return YES; // Allow advancing to the next pane or completing installation
}

@end
