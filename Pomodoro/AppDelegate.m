//
//  AppDelegate.m
//  Pomodoro
//
//  Created by Jeremy on 2014-09-08.
//  Copyright (c) 2014 Jeremy W. Sherman. All rights reserved.
//

#import "AppDelegate.h"
#import "PreferencesConfig.h"
#import "PMDTimer.h"

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@property NSWindowController *preferencesController;
@property id<Config> config;
@end

@implementation AppDelegate {
    PMDTimer *_timer;
}
            
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.config = [PreferencesConfig new];
    [self workAction:nil];
    [self pauseAction:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (IBAction)showPreferences:(id)sender
{
    if (!self.preferencesController) {
        NSWindowController *preferencesController = [[NSWindowController alloc]
                                                     initWithWindowNibName:@"Preferences"];
        NSAssert(preferencesController != nil, @"failed to create window controller");
        self.preferencesController = preferencesController;
    }
    [self.window beginSheet:self.preferencesController.window completionHandler:NULL];
}

- (IBAction)dismissPreferences:(id)sender
{
    [self.window endSheet:self.window.attachedSheet];
}

- (IBAction)workAction:(NSButton *)sender
{
    [self clockInMinutes:self.config.workMinutes];
    [self resumeAction:nil];
}
- (IBAction)restAction:(NSButton *)sender
{
    [self clockInMinutes:self.config.restMinutes];
    [self resumeAction:nil];
}

- (void)clockInMinutes:(NSUInteger)minutes
{
    [_timer removeObserver:self forKeyPath:@"seconds"];
    [_timer abort];
    _timer = [self newTimerWithMinutes:minutes];
    [_timer addObserver:self forKeyPath:@"seconds" options:0 context:nil];
    [self timerDidChange];
}
- (PMDTimer *)newTimerWithMinutes:(NSUInteger)minutes
{
    PMDTimer *timer = [[PMDTimer alloc] initWithSeconds:minutes * 60.0];
    return timer;
}

- (IBAction)pauseAction:(NSButton *)sender
{
    [_timer pause];
}
- (IBAction)resumeAction:(NSButton *)sender
{
    [_timer resume];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _timer && [keyPath isEqualToString:@"seconds"]) {
        [self timerDidChange];
    }
}

- (void)timerDidChange
{
    NSTimeInterval seconds = _timer ? _timer.seconds : 0;
    self.clockText = [self formatSeconds:seconds];

    BOOL didTimerExpire = (seconds <= 0);
    if (didTimerExpire) {
        [self notifyUser];
    }

    NSDockTile *tile = [NSApplication sharedApplication].dockTile;
    NSString *minutesLeft = [self.clockText componentsSeparatedByString:@":"][0];
    tile.badgeLabel = (didTimerExpire ? nil : minutesLeft);
}

- (void)notifyUser
{
    NSBeep();

    NSUserNotification *note = [NSUserNotification new];
    note.title = @"Time's up!";
    [[NSUserNotificationCenter defaultUserNotificationCenter]
     deliverNotification:note];
}

- (NSString *)formatSeconds:(NSTimeInterval)seconds
{
    NSTimeInterval clockMinutes = trunc(seconds / 60.0);
    NSTimeInterval clockSeconds = seconds - clockMinutes * 60;
    NSString *clockText = [NSString stringWithFormat:@"%1.0f:%02.0f", clockMinutes, clockSeconds];
    return clockText;
}
@end
