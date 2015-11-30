#import "Config.h"

@interface PlistConfig : NSObject <Config>
- (instancetype)initWithURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;
@end
