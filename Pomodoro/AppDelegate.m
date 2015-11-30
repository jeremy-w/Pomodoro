//
//  AppDelegate.m
//  Pomodoro
//
//  Created by Jeremy on 2014-09-08.
//  Copyright (c) 2014 Jeremy W. Sherman. All rights reserved.
//

#import "AppDelegate.h"
#import "PreferencesConfig.h"


@interface PlistConfig : NSObject <Config>
- (instancetype)initWithURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;
@end

@implementation PlistConfig
@synthesize workMinutes = _workMinutes;
@synthesize restMinutes = _restMinutes;

- (instancetype)initWithURL:(NSURL *)fileURL
{
    self = [super init];
    if (!self) return nil;

    NSDictionary *config = [NSDictionary dictionaryWithContentsOfURL:fileURL];
    NSAssert(config, @"failed to load config dictionary: %@", fileURL);
    _workMinutes = [self.class intervalFromObject:config[@"WorkMinutes"]];
    _restMinutes = [self.class intervalFromObject:config[@"RestMinutes"]];
    return self;
}


+ (NSTimeInterval)intervalFromObject:(id)object
{
    NSAssert([object respondsToSelector:@selector(doubleValue)],
             @"%s: %@ does not respond to doubleValue", __func__, object);
    return [object doubleValue];
}


- (instancetype)init
{
    self = [self initWithURL:self.configURL];
    return self;
}


- (NSURL *)configURL
{
    return [[NSBundle bundleForClass:self.class] URLForResource:@"config" withExtension:@"plist"];
}
@end


@interface PMDTimer : NSObject
- (instancetype)initWithSeconds:(NSTimeInterval)seconds;

@property(nonatomic) NSTimeInterval seconds;

- (void)pause;
- (void)resume;
- (void)abort;
@end

@implementation PMDTimer {
    NSTimer *_timer;
    NSTimeInterval _targetSeconds;
    NSMutableArray *_startTimes;
    NSMutableArray *_stopTimes;
}

- (void)dealloc
{
    [_timer invalidate];
}

- (void)abort
{
    [_timer invalidate];
    _timer = nil;
    self.seconds = 0;
}

- (instancetype)initWithSeconds:(NSTimeInterval)seconds
{
    self = [super init];
    if (!self) return nil;

    _targetSeconds = seconds;
    self.seconds = seconds;
    _startTimes = [NSMutableArray new];
    _stopTimes = [NSMutableArray new];
    return self;
}

- (void)resume
{
    if (!!_timer) return;

    [_startTimes addObject:[NSDate date]];
    /* Yup, this is a refcycle. Don't care just now, and gets broken during pause or when out of time. */
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(decrementSeconds) userInfo:nil repeats:YES];
}

- (void)decrementSeconds
{
    self.seconds = _targetSeconds - [self secondsElapsedBeforeDate:[NSDate date]];
    if (self.seconds <= 0) {
        [self pause];
        self.seconds = 0;
    }
}

- (NSTimeInterval)secondsElapsedBeforeDate:(NSDate *)date
{
    NSUInteger i = 0;
    NSArray *starts = [_startTimes copy];
    NSArray *stops = [_stopTimes copy];
    if (stops.count < starts.count) {
        stops = [stops arrayByAddingObject:date];
    }
    NSAssert(starts.count == stops.count, @"%s: expected same count: starts %@ vs. stops %@", __func__, starts, stops);

    NSTimeInterval elapsed = 0;
    for (NSDate *start in starts) {
        NSDate *stop = stops[i];
        i += 1;

        NSTimeInterval delta = [stop timeIntervalSinceDate:start];
        elapsed += delta;
    }
    return elapsed;
}

- (void)pause
{
    BOOL alreadyPaused = !_timer;
    if (alreadyPaused) return;

    [_stopTimes addObject:[NSDate date]];

    [_timer invalidate];
    _timer = nil;
}
@end

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
