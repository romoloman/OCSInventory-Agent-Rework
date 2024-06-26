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

- (void)didEnterPane:(InstallerSectionDirection)dir {
    // Optional: Pre-fill fields or perform setup logic when the pane is shown
    self->server.stringValue = @"http://example.com";
    self->username.stringValue = @"";
    self->password.stringValue = @"";
    self->serviceMode.state = NSControlStateValueOff;
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
        
        // Example: Save to a temporary file or perform further processing
        NSLog(@"Server: %@, Username: %@, Password: %@, Service Mode: %@", server, username, password, serviceModeEnabled ? @"Yes" : @"No");
        
        // Example: Save to a temporary file or perform further processing
        NSString *configContent = [NSString stringWithFormat:@"server=%@\nusername=%@\npassword=%@\nserviceMode=%@\n", server, username, password, serviceModeEnabled ? @"yes" : @"no"];
        NSString *tmpConfigFilePath = @"/tmp/installer_config.txt";
        [configContent writeToFile:tmpConfigFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            
    }
    
    return YES; // Allow advancing to the next pane or completing installation
}

@end
