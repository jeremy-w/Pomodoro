#import "PMDTimer.h"

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
