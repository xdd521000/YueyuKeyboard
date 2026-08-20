#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^YueyuTranslateCompletion)(NSString * _Nullable result, NSError * _Nullable error);

/// 翻译引擎 v0.3
/// 策略：设置里填了百度 App ID/密钥 → 百度优先，失败自动切 Google；
///       没填 → 直接用 Google（无需 Key）。
/// 语言代码（canonical）：@""/auto 自动、zh、en、ja、ko、fr、de、ru
@interface YueyuTranslator : NSObject

+ (instancetype)sharedInstance;

/// 自动翻译：目标语言取设置默认值；未设置时自动判断（中文→英文，其他→中文）。
- (void)translateText:(NSString *)text completion:(YueyuTranslateCompletion)completion;

/// 指定目标语言（canonical 代码，@""=自动）。
- (void)translateText:(NSString *)text toLanguage:(NSString *)targetLanguage completion:(YueyuTranslateCompletion)completion;

/// 粗略判断文本是否以中文为主（用于自动选择目标语言）。
+ (BOOL)isChineseText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END