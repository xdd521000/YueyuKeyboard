// 越狱插件键盘 - 翻译功能（v0.3）
// 依赖：YueyuTranslator.h/.m、YueyuSettings.h/.m（同目录）
// 配置：iOS 设置 → 越狱插件键盘（百度 App ID/密钥、默认语言、开关）
//
// 用法（输入框输入后发送）：
//   翻译:你好            → 按设置默认语言翻译（默认自动）
//   #fy 你好             → 同上
//   #fyzh hello          → 译为中文
//   #fyen 你好           → 译为英文
//   #fyja / #fyko / #fyfr / #fyde / #fyru  → 日/韩/法/德/俄
// 或点输入附件栏「翻译」按钮，原地翻译输入框内容。

#import <UIKit/UIKit.h>
#import "YueyuTranslator.h"
#import "YueyuSettings.h"

#pragma mark - 工具函数

static UIView *YYFindSubview(UIView *view, Class cls) {
    if (!view) return nil;
    if ([view isKindOfClass:cls]) return view;
    for (UIView *sub in view.subviews) {
        UIView *found = YYFindSubview(sub, cls);
        if (found) return found;
    }
    return nil;
}

static UITextView *YYFirstResponderTextView(UIView *view) {
    if (!view) return nil;
    if ([view isKindOfClass:[UITextView class]] && view.isFirstResponder) return (UITextView *)view;
    for (UIView *sub in view.subviews) {
        UITextView *found = YYFirstResponderTextView(sub);
        if (found) return found;
    }
    return nil;
}

static UITextView *YYCurrentInputTextView(UIViewController *vc) {
    if (vc.view) {
        UIView *v = YYFindSubview(vc.view, NSClassFromString(@"QQInputTextView"));
        if (v) return (UITextView *)v;
    }
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (window) return YYFirstResponderTextView(window);
    return nil;
}

static void YYShowAlert(NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *top = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (top) [top presentViewController:alert animated:YES completion:nil];
}

static void YYShowToast(NSString *message) {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;
    UIView *toast = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 190, 42)];
    toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78];
    toast.layer.cornerRadius = 8;
    toast.alpha = 0;
    UILabel *label = [[UILabel alloc] initWithFrame:toast.bounds];
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:14];
    label.adjustsFontSizeToFitWidth = YES;
    [toast addSubview:label];
    toast.center = CGPointMake(window.bounds.size.width / 2, window.bounds.size.height * 0.4);
    [window addSubview:toast];
    [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 0; } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}

// 解析翻译指令；命中返回 YES 并输出原文/目标语言（target 为 @"" 表示按设置/自动）
static BOOL YYParseTranslateCommand(NSString *text, NSString **outSource, NSString **outTarget) {
    if (text.length == 0) return NO;
    static NSDictionary *langCommands = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        langCommands = @{
            @"#fyzh": @"zh", @"#fyen": @"en", @"#fyja": @"ja", @"#fyko": @"ko",
            @"#fyfr": @"fr", @"#fyde": @"de", @"#fyru": @"ru"
        };
    });

    NSString *source = nil;
    NSString *target = @""; // 空 = 用设置默认/自动

    for (NSString *prefix in langCommands) {
        if ([text hasPrefix:prefix]) {
            source = [text substringFromIndex:prefix.length];
            target = langCommands[prefix];
            break;
        }
    }
    if (!source && [text hasPrefix:@"#fy"]) {
        source = [text substringFromIndex:3];
    } else if (!source && [text hasPrefix:@"翻译"]) {
        source = [text substringFromIndex:2];
    }
    if (!source) return NO;

    source = [source stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([source hasPrefix:@":"] || [source hasPrefix:@"："]) {
        source = [source substringFromIndex:1];
    }
    source = [source stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (source.length == 0) return NO;

    if (outSource) *outSource = source;
    if (outTarget) *outTarget = target;
    return YES;
}

#pragma mark - 翻译按钮（方式 B：输入附件栏按钮）

static NSInteger const kYYTranslateButtonTag = 9527;

@interface YueyuTranslateButtonHandler : NSObject
+ (instancetype)sharedHandler;
- (void)translateTapped:(id)sender;
@end

@implementation YueyuTranslateButtonHandler

+ (instancetype)sharedHandler {
    static YueyuTranslateButtonHandler *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ handler = [[self alloc] init]; });
    return handler;
}

- (void)translateTapped:(id)sender {
    if (![YueyuSettings translateEnabled]) return;
    UITextView *textView = YYCurrentInputTextView(nil);
    if (!textView || textView.text.length == 0) {
        YYShowAlert(@"提示", @"输入框为空，没有可翻译的内容");
        return;
    }
    NSString *original = textView.text;
    if ([YueyuSettings showToast]) YYShowToast(@"翻译中…");
    [[YueyuTranslator sharedInstance] translateText:original completion:^(NSString *result, NSError *error) {
        if (result.length) {
            textView.text = result; // 原地替换为译文
        } else {
            YYShowAlert(@"翻译失败", error ? error.localizedDescription : @"未知错误");
        }
    }];
}

@end

#pragma mark - Hook 1：发送拦截（翻译指令，方式 A）

static BOOL yyTranslating = NO;

%hook NTAIOChat.NTAIOShortcutBarItemInputBarViewController

- (void)actionSend {
    // 翻译完成后的二次发送直接放行
    if (yyTranslating) { %orig; return; }
    // 设置里关闭了翻译功能 → 原样发送
    if (![YueyuSettings translateEnabled]) { %orig; return; }

    UITextView *textView = YYCurrentInputTextView(self);
    if (!textView) { %orig; return; }

    NSString *source = nil;
    NSString *target = nil;
    if (!YYParseTranslateCommand(textView.text, &source, &target)) { %orig; return; }

    yyTranslating = YES;
    // 先把命令文本替换成原文，翻译失败时也不至于把 "#fy..." 发出去
    textView.text = source;
    if ([YueyuSettings showToast]) YYShowToast(@"翻译中…");

    void (^handler)(NSString *, NSError *) = ^(NSString *result, NSError *error) {
        if (result.length) {
            if ([YueyuSettings sendBoth]) {
                // 原文 + 译文一起发（一条气泡，上下两段）
                textView.text = [NSString stringWithFormat:@"%@\n\n%@", source, result];
            } else {
                textView.text = result;
            }
        } else {
            YYShowAlert(@"翻译失败", error ? error.localizedDescription : @"未知错误");
            textView.text = source; // 失败时发送原文
        }
        %orig; // 触发 QQ 发送当前文本
        yyTranslating = NO;
    };

    [[YueyuTranslator sharedInstance] translateText:source toLanguage:target completion:handler];
}

%end

#pragma mark - Hook 2：输入附件栏加「翻译」按钮（方式 B）

%hook QQInputAccessoryView

- (void)layoutSubviews {
    %orig;
    UIButton *btn = (UIButton *)[self viewWithTag:kYYTranslateButtonTag];
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = kYYTranslateButtonTag;
        [btn setTitle:@"翻译" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor colorWithRed:0.04 green:0.37 blue:0.82 alpha:1] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        btn.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
        btn.layer.cornerRadius = 6;
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn addTarget:[YueyuTranslateButtonHandler sharedHandler]
                action:@selector(translateTapped:)
      forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        [NSLayoutConstraint activateConstraints:@[
            [btn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [btn.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [btn.widthAnchor constraintGreaterThanOrEqualToConstant:52],
            [btn.heightAnchor constraintEqualToConstant:28]
        ]];
    }
    [self bringSubviewToFront:btn];
}

%end

%ctor {
    NSLog(@"[YueyuKeyboard] 已加载 (翻译功能 v0.3，百度优先 + 设置页)");
}