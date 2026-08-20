#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 读取插件设置（iOS 设置 App → 越狱插件键盘）
/// 数据存在 NSUserDefaults suite: com.yueyu.qqkeyboard
@interface YueyuSettings : NSObject

+ (BOOL)translateEnabled;          // YYTranslateEnabled  默认 YES
+ (NSString *)baiduAppID;          // YYBaiduAppID        默认 @""
+ (NSString *)baiduSecretKey;      // YYBaiduSecretKey    默认 @""
+ (NSString *)defaultTargetLang;   // YYDefaultTargetLang 默认 @""(自动)；zh/en/ja/ko/fr/de/ru
+ (BOOL)sendBoth;                  // YYSendBoth          默认 NO（原文+译文一起发）
+ (BOOL)showToast;                 // YYShowToast         默认 YES（翻译中提示）

@end

NS_ASSUME_NONNULL_END