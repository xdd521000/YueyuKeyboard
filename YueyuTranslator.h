#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^YueyuTranslateCompletion)(NSString * _Nullable result, NSError * _Nullable error);

/// 翻译引擎：把文本翻译成目标语言。
/// 默认走无需 API Key 的公开端点（translate.googleapis.com gtx），
/// 后续可替换为百度/有道/DeepL 等带 Key 的服务。
@interface YueyuTranslator : NSObject

+ (instancetype)sharedInstance;

/// 自动翻译：源文本主要是中文 → 英文，否则 → 中文。
- (void)translateText:(NSString *)text completion:(YueyuTranslateCompletion)completion;

/// 指定目标语言（如 zh-CN / en / ja）。
- (void)translateText:(NSString *)text toLanguage:(NSString *)targetLanguage completion:(YueyuTranslateCompletion)completion;

/// 粗略判断文本是否以中文为主（用于自动选择目标语言）。
+ (BOOL)isChineseText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END