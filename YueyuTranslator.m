#import "YueyuTranslator.h"

static NSString *const kYYTranslateEndpoint = @"https://translate.googleapis.com/translate_a/single";

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
    NSString *target = [YueyuTranslator isChineseText:text] ? @"en" : @"zh-CN";
    [self translateText:text toLanguage:target completion:completion];
}

- (void)translateText:(NSString *)text toLanguage:(NSString *)targetLanguage completion:(YueyuTranslateCompletion)completion {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        [self finishWithResult:nil error:[self errorWithCode:1 message:@"没有可翻译的内容"] completion:completion];
        return;
    }
    if (targetLanguage.length == 0) {
        [self translateText:text completion:completion]; // 未指定目标语言时自动判断
        return;
    }

    NSURLComponents *components = [NSURLComponents componentsWithString:kYYTranslateEndpoint];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"client" value:@"gtx"],
        [NSURLQueryItem queryItemWithName:@"sl" value:@"auto"],
        [NSURLQueryItem queryItemWithName:@"tl" value:targetLanguage],
        [NSURLQueryItem queryItemWithName:@"dt" value:@"t"],
        [NSURLQueryItem queryItemWithName:@"q" value:trimmed],
    ];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.timeoutInterval = 15.0;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [self finishWithResult:nil error:error completion:completion];
                return;
            }
            NSString *translated = [self parseTranslation:data];
            if (translated.length == 0) {
                [self finishWithResult:nil error:[self errorWithCode:2 message:@"翻译结果解析失败"] completion:completion];
                return;
            }
            [self finishWithResult:translated error:nil completion:completion];
        }];
    [task resume];
}

#pragma mark - 内部

/// gtx 接口返回结构：[[["译文","原文",...], ...], "auto", "en", ...]
- (NSString *)parseTranslation:(NSData *)data {
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
        BOOL isLetterOrDigit = (c > 0x20 && c < 0x7F) || isChinese;
        if (isChinese) chineseCount++;
        if (isLetterOrDigit) meaningfulCount++;
    }
    if (meaningfulCount == 0) return NO;
    return (double)chineseCount / meaningfulCount >= 0.3;
}

@end