// 越狱插件键盘 - 键盘工具栏 v0.4
// 功能：翻译 / 复制 / 左右移动光标
// 依赖：YueyuTranslator.h/.m、YueyuSettings.h/.m（同目录）
// 配置：iOS 设置 → 越狱插件键盘（百度翻译 Key、默认语言、开关）
//
// 用法：
//   翻译：输入 翻译:xx / #fy / #fyzh / #fyen / #fyja / #fyko / #fyfr / #fyde / #fyru 后发送，
//         或点附件栏「翻译」按钮原地翻译。
//   复制：点「复制」按钮，复制输入框内容（有选中文字则复制选中部分）到剪贴板。
//   移动：点「◀」「▶」按钮，光标左/右移动 1 个字符。

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
    NSString *target = @"";

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

#pragma mark - 键盘工具栏（翻译 / 复制 / 左右移动光标）

static NSInteger const kYYToolbarTag = 9527;

@interface YueyuToolbarHandler : NSObject
+ (instancetype)sharedHandler;
- (void)translateTapped:(id)sender;
- (void)copyTapped:(id)sender;
- (void)moveCaretLeft:(id)sender;
- (void)moveCaretRight:(id)sender;
@end

@implementation YueyuToolbarHandler

+ (instancetype)sharedHandler {
    static YueyuToolbarHandler *handler = nil;
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
            textView.text = result;
        } else {
            YYShowAlert(@"翻译失败", error ? error.localizedDescription : @"未知错误");
        }
    }];
}

- (void)copyTapped:(id)sender {
    UITextView *textView = YYCurrentInputTextView(nil);
    if (!textView || textView.text.length == 0) {
        YYShowAlert(@"提示", @"输入框为空，没有可复制的内容");
        return;
    }
    NSString *toCopy = textView.text;
    NSRange sel = textView.selectedRange;
    // 有选中文字 → 只复制选中的部分
    if (sel.length > 0 && sel.location + sel.length <= textView.text.length) {
        toCopy = [textView.text substringWithRange:sel];
    }
    [UIPasteboard generalPasteboard].string = toCopy;
    if ([YueyuSettings showToast]) YYShowToast(@"已复制");
}

- (void)moveCaretLeft:(id)sender {
    [self moveCaretBy:-1];
}

- (void)moveCaretRight:(id)sender {
    [self moveCaretBy:1];
}

- (void)moveCaretBy:(NSInteger)delta {
    UITextView *textView = YYCurrentInputTextView(nil);
    if (!textView) return;
    NSRange range = textView.selectedRange;
    NSInteger pos = (NSInteger)range.location;
    if (delta > 0) {
        pos = MIN(pos + delta, (NSInteger)textView.text.length);
    } else {
        pos = MAX(0, pos + delta);
    }
    textView.selectedRange = NSMakeRange((NSUInteger)pos, 0);
    if (!textView.isFirstResponder) {
        [textView becomeFirstResponder];
    }
}

@end

#pragma mark - Hook 1：发送拦截（翻译指令）

static BOOL yyTranslating = NO;

%hook NTAIOChat.NTAIOShortcutBarItemInputBarViewController

- (void)actionSend {
    if (yyTranslating) { %orig; return; }
    if (![YueyuSettings translateEnabled]) { %orig; return; }

    UITextView *textView = YYCurrentInputTextView(self);
    if (!textView) { %orig; return; }

    NSString *source = nil;
    NSString *target = nil;
    if (!YYParseTranslateCommand(textView.text, &source, &target)) { %orig; return; }

    yyTranslating = YES;
    textView.text = source;
    if ([YueyuSettings showToast]) YYShowToast(@"翻译中…");

    void (^handler)(NSString *, NSError *) = ^(NSString *result, NSError *error) {
        if (result.length) {
            if ([YueyuSettings sendBoth]) {
                textView.text = [NSString stringWithFormat:@"%@\n\n%@", source, result];
            } else {
                textView.text = result;
            }
        } else {
            YYShowAlert(@"翻译失败", error ? error.localizedDescription : @"未知错误");
            textView.text = source;
        }
        %orig;
        yyTranslating = NO;
    };

    [[YueyuTranslator sharedInstance] translateText:source toLanguage:target completion:handler];
}

%end

#pragma mark - Hook 2：输入附件栏加工具栏（◀ ▶ 复制 翻译）

%hook QQInputAccessoryView

- (void)layoutSubviews {
    %orig;
    UIView *existing = [self viewWithTag:kYYToolbarTag];
    if (!existing) {
        NSArray *defs = @[
            @{ @"title": @"◀", @"sel": @"moveCaretLeft:", @"w": @30 },
            @{ @"title": @"▶", @"sel": @"moveCaretRight:", @"w": @30 },
            @{ @"title": @"复制", @"sel": @"copyTapped:", @"w": @52 },
            @{ @"title": @"翻译", @"sel": @"translateTapped:", @"w": @52 }
        ];

        UIStackView *bar = [[UIStackView alloc] init];
        bar.tag = kYYToolbarTag;
        bar.axis = UILayoutConstraintAxisHorizontal;
        bar.spacing = 6;
        bar.translatesAutoresizingMaskIntoConstraints = NO;

        YueyuToolbarHandler *handler = [YueyuToolbarHandler sharedHandler];
        for (NSDictionary *d in defs) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            [btn setTitle:d[@"title"] forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor colorWithRed:0.04 green:0.37 blue:0.82 alpha:1] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            btn.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
            btn.layer.cornerRadius = 6;
            btn.translatesAutoresizingMaskIntoConstraints = NO;
            [btn.widthAnchor constraintEqualToConstant:[d[@"w"] doubleValue]].active = YES;
            [btn.heightAnchor constraintEqualToConstant:28].active = YES;
            [btn addTarget:handler action:NSSelectorFromString(d[@"sel"]) forControlEvents:UIControlEventTouchUpInside];
            [bar addArrangedSubview:btn];
        }

        [self addSubview:bar];
        [NSLayoutConstraint activateConstraints:@[
            [bar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [bar.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    [self bringSubviewToFront:existing];
}

%end

%ctor {
    NSLog(@"[YueyuKeyboard] 已加载 (键盘工具栏 v0.4：翻译/复制/左右移动)");
}