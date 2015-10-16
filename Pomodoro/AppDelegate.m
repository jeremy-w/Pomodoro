//
//  AppDelegate.m
//  Pomodoro
//
//  Created by Jeremy on 2014-09-08.
//  Copyright (c) 2014 Jeremy W. Sherman. All rights reserved.
//

#import "AppDelegate.h"

@protocol Config
@property(readonly) NSTimeInterval workMinutes;
@property(readonly) NSTimeInterval restMinutes;
@end


@interface PreferencesConfig : NSObject <Config>
@end

@implementation PreferencesConfig
@dynamic restMinutes;
@dynamic workMinutes;

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:
        @{
          @"WorkMinutes": @50,
          @"RestMinutes": @10,
          }];
}


- (NSTimeInterval)workMinutes
{
    return [[NSUserDefaults standardUserDefaults] doubleForKey:@"WorkMinutes"];
}


- (NSTimeInterval)restMinutes
{
    return [[NSUserDefaults standardUserDefaults] doubleForKey:@"RestMinutes"];
}
@end


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
@property id<Config> config;

@end

@implementation AppDelegate {
    PMDTimer *_timer;
}
            
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.config = [PlistConfig new];
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

    if (seconds <= 0) {
        [self notifyUser];
    }
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
