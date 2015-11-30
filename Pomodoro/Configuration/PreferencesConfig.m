#import "PreferencesConfig.h"

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
