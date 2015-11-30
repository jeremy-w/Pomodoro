@import Foundation;

@interface PMDTimer : NSObject
- (instancetype)initWithSeconds:(NSTimeInterval)seconds;

@property(nonatomic) NSTimeInterval seconds;

- (void)pause;
- (void)resume;
- (void)abort;
@end
