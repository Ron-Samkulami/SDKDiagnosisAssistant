

#import <UIKit/UIKit.h>

@interface RVDebugFloatWindow : UIView

@property (nonatomic,copy) void(^clickBolcks)(NSInteger i);


///  warning: frame的长宽必须相等
- (instancetype)initWithFrame:(CGRect)frame 
                  mainBtnName:(NSString*)mainBtnName
                       titles:(NSArray *)titles
                      bgcolor:(UIColor *)bgcolor;
/// 显示（默认）
- (void)showWindow;

/// 隐藏
- (void)dissmissWindow;

@end
