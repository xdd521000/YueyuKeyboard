#import "YueyuSettings.h"

static NSString *const kYueyuPrefsSuite = @"com.yueyu.qqkeyboard";

@implementation YueyuSettings

+ (NSUserDefaults *)prefs {
    return [[NSUserDefaults alloc] initWithSuiteName:kYueyuPrefsSuite];
}

+ (BOOL)translateEnabled {
    NSNumber *v = [[self prefs] objectForKey:@"YYTranslateEnabled"];
    return v ? v.boolValue : YES;
}

+ (NSString *)baiduAppID {
    return [[[self prefs] stringForKey:@"YYBaiduAppID"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+ (NSString *)baiduSecretKey {
    return [[[self prefs] stringForKey:@"YYBaiduSecretKey"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+ (NSString *)defaultTargetLang {
    NSString *lang = [[self prefs] stringForKey:@"YYDefaultTargetLang"];
    if (!lang.length || [lang isEqualToString:@"auto"]) return @"";
    return lang;
}

+ (BOOL)sendBoth {
    return [[self prefs] boolForKey:@"YYSendBoth"];
}

+ (BOOL)showToast {
    NSNumber *v = [[self prefs] objectForKey:@"YYShowToast"];
    return v ? v.boolValue : YES;
}

@end