#import "PlistConfig.h"

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
