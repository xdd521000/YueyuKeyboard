#import "YueyuTranslator.h"
#import "YueyuSettings.h"
#import <CommonCrypto/CommonCrypto.h>

static NSString *const kYYGoogleEndpoint = @"https://translate.googleapis.com/translate_a/single";
static NSString *const kYYBaiduEndpoint = @"https://fanyi-api.baidu.com/api/trans/vip/translate";

@implementation YueyuTranslator

+ (instancetype)sharedInstance {
    static YueyuTranslator *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YueyuTranslator alloc] init];
    });
    return instance;
}

#pragma mark - 对外接口

- (void)translateText:(NSString *)text completion:(YueyuTranslateCompletion)completion {
    NSString *target = [YueyuSettings defaultTargetLang]; // "" = 自动
    [self translateText:text toLanguage:target completion:completion];
}

- (void)translateText:(NSString *)text toLanguage:(NSString *)targetLanguage completion:(YueyuTranslateCompletion)completion {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        [self finishWithResult:nil error:[self errorWithCode:1 message:@"没有可翻译的内容"] completion:completion];
        return;
    }

    NSString *canonical = [self canonicalLanguage:targetLanguage]; // "" = 自动

    // 百度优先：设置里已填 App ID + 密钥 且 翻译功能开启
    BOOL useBaidu = [YueyuSettings translateEnabled]
        && [YueyuSettings baiduAppID].length
        && [YueyuSettings baiduSecretKey].length;
    if (useBaidu) {
        [self translateWithBaidu:trimmed target:canonical completion:^(NSString *result, NSError *error) {
            if (result) {
                [self finishWithResult:result error:nil completion:completion];
            } else {
                // 百度失败 → 自动切 Google
                [self translateWithGoogle:trimmed target:canonical completion:completion];
            }
        }];
        return;
    }
    [self translateWithGoogle:trimmed target:canonical completion:completion];
}

#pragma mark - 目标语言解析

- (NSString *)canonicalLanguage:(NSString *)lang {
    if (!lang.length || [lang isEqualToString:@"auto"]) return @"";
    // 兼容历史值
    if ([lang isEqualToString:@"zh-CN"]) return @"zh";
    return lang;
}

- (NSString *)resolveTarget:(NSString *)canonical source:(NSString *)source {
    if (canonical.length) return canonical;
    return [YueyuTranslator isChineseText:source] ? @"en" : @"zh";
}

#pragma mark - 百度翻译

- (void)translateWithBaidu:(NSString *)text target:(NSString *)canonical completion:(YueyuTranslateCompletion)completion {
    NSString *to = [self baiduLangCode:[self resolveTarget:canonical source:text]];
    NSString *appid = [YueyuSettings baiduAppID];
    NSString *secret = [YueyuSettings baiduSecretKey];
    NSString *salt = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
    NSString *signSource = [NSString stringWithFormat:@"%@%@%@%@", appid, text, salt, secret];
    NSString *sign = [YueyuTranslator md5:signSource];

    NSURLComponents *components = [NSURLComponents componentsWithString:kYYBaiduEndpoint];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"q" value:text],
        [NSURLQueryItem queryItemWithName:@"from" value:@"auto"],
        [NSURLQueryItem queryItemWithName:@"to" value:to],
        [NSURLQueryItem queryItemWithName:@"appid" value:appid],
        [NSURLQueryItem queryItemWithName:@"salt" value:salt],
        [NSURLQueryItem queryItemWithName:@"sign" value:sign],
    ];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.timeoutInterval = 10.0;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [self finishWithResult:nil error:error completion:completion];
                return;
            }
            NSError *parseError = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if (parseError || ![json isKindOfClass:[NSDictionary class]]) {
                [self finishWithResult:nil error:[self errorWithCode:3 message:@"百度返回解析失败"] completion:completion];
                return;
            }
            NSDictionary *dict = json;
            NSString *errorCode = dict[@"error_code"];
            if (errorCode.length) {
                NSString *msg = [NSString stringWithFormat:@"百度错误 %@: %@", errorCode, dict[@"error_msg"] ?: @""];
                [self finishWithResult:nil error:[self errorWithCode:errorCode.intValue message:msg] completion:completion];
                return;
            }
            NSMutableString *translated = [NSMutableString string];
            for (id item in dict[@"trans_result"]) {
                if ([item isKindOfClass:[NSDictionary class]] && [item[@"dst"] isKindOfClass:[NSString class]]) {
                    if (translated.length) [translated appendString:@"\n"];
                    [translated appendString:item[@"dst"]];
                }
            }
            if (translated.length) {
                [self finishWithResult:translated error:nil completion:completion];
            } else {
                [self finishWithResult:nil error:[self errorWithCode:4 message:@"百度返回空结果"] completion:completion];
            }
        }] resume];
}

- (NSString *)baiduLangCode:(NSString *)canonical {
    static NSDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{ @"zh": @"zh", @"en": @"en", @"ja": @"jp", @"ko": @"kor",
                 @"fr": @"fra", @"de": @"de", @"ru": @"ru" };
    });
    return map[canonical] ?: @"en";
}

#pragma mark - Google 翻译（备用 / 默认）

- (void)translateWithGoogle:(NSString *)text target:(NSString *)canonical completion:(YueyuTranslateCompletion)completion {
    NSString *to = [self googleLangCode:[self resolveTarget:canonical source:text]];
    NSURLComponents *components = [NSURLComponents componentsWithString:kYYGoogleEndpoint];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"client" value:@"gtx"],
        [NSURLQueryItem queryItemWithName:@"sl" value:@"auto"],
        [NSURLQueryItem queryItemWithName:@"tl" value:to],
        [NSURLQueryItem queryItemWithName:@"dt" value:@"t"],
        [NSURLQueryItem queryItemWithName:@"q" value:text],
    ];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.timeoutInterval = 15.0;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [self finishWithResult:nil error:error completion:completion];
                return;
            }
            NSString *translated = [self parseGoogleTranslation:data];
            if (translated.length) {
                [self finishWithResult:translated error:nil completion:completion];
            } else {
                [self finishWithResult:nil error:[self errorWithCode:2 message:@"翻译结果解析失败"] completion:completion];
            }
        }] resume];
}

- (NSString *)googleLangCode:(NSString *)canonical {
    static NSDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{ @"zh": @"zh-CN", @"en": @"en", @"ja": @"ja", @"ko": @"ko",
                 @"fr": @"fr", @"de": @"de", @"ru": @"ru" };
    });
    return map[canonical] ?: @"en";
}

// gtx 返回：[[["译文","原文",...],...], "auto", "en", ...]
- (NSString *)parseGoogleTranslation:(NSData *)data {
    if (data.length == 0) return nil;
    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![json isKindOfClass:[NSArray class]]) return nil;
    NSArray *root = json;
    if (root.count == 0 || ![root[0] isKindOfClass:[NSArray class]]) return nil;
    NSMutableString *result = [NSMutableString string];
    for (id segment in root[0]) {
        if (![segment isKindOfClass:[NSArray class]]) continue;
        NSArray *pair = segment;
        if (pair.count > 0 && [pair[0] isKindOfClass:[NSString class]]) {
            [result appendString:pair[0]];
        }
    }
    return result.length > 0 ? result : nil;
}

#pragma mark - 工具

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+ (NSString *)md5:(NSString *)string {
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}
#pragma clang diagnostic pop

- (void)finishWithResult:(NSString *)result error:(NSError *)error completion:(YueyuTranslateCompletion)completion {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(result, error);
    });
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:@"YueyuTranslator" code:code
        userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
}

+ (BOOL)isChineseText:(NSString *)text {
    if (text.length == 0) return NO;
    NSInteger chineseCount = 0;
    NSInteger meaningfulCount = 0;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        BOOL isChinese = (c >= 0x4E00 && c <= 0x9FFF);
        BOOL isMeaningful = (c > 0x20 && c < 0x7F) || isChinese;
        if (isChinese) chineseCount++;
        if (isMeaningful) meaningfulCount++;
    }
    if (meaningfulCount == 0) return NO;
    return (double)chineseCount / meaningfulCount >= 0.3;
}

@end