// 越狱插件键盘 - 翻译功能（v0.2）
// 依赖：YueyuTranslator.h / YueyuTranslator.m（同目录）
//
// 两种使用方式：
//   A. 命令式：输入翻译指令后发送（稳定入口）
//       翻译:你好    #fy 你好    #fyzh hello    #fyen 你好
//   B. 按钮式：QQ 输入附件栏最右侧新增「翻译」按钮，点一下把输入框内容原地翻译

#import <UIKit/UIKit.h>
#import "YueyuTranslator.h"

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

// 优先取 QQInputTextView；找不到就找当前正在输入的第一响应者 UITextView
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

// 解析翻译指令；命中返回 YES 并输出原文/目标语言（target 为 nil 表示自动判断）
static BOOL YYParseTranslateCommand(NSString *text, NSString **outSource, NSString **outTarget) {
    if (text.length == 0) return NO;
    NSString *source = nil;
    NSString *target = nil;

    if ([text hasPrefix:@"#fyzh"]) {
        source = [text substringFromIndex:5]; target = @"zh-CN";
    } else if ([text hasPrefix:@"#fyen"]) {
        source = [text substringFromIndex:5]; target = @"en";
    } else if ([text hasPrefix:@"#fy"]) {
        source = [text substringFromIndex:3];
    } else if ([text hasPrefix:@"翻译"]) {
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
    UITextView *textView = YYCurrentInputTextView(nil);
    if (!textView || textView.text.length == 0) {
        YYShowAlert(@"提示", @"输入框为空，没有可翻译的内容");
        return;
    }
    NSString *original = textView.text;
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

    UITextView *textView = YYCurrentInputTextView(self);
    if (!textView) { %orig; return; }

    NSString *source = nil;
    NSString *target = nil;
    if (!YYParseTranslateCommand(textView.text, &source, &target)) { %orig; return; }

    yyTranslating = YES;
    // 先把命令文本替换成原文，翻译失败时也不至于把 "#fy..." 发出去
    textView.text = source;

    void (^handler)(NSString *, NSError *) = ^(NSString *result, NSError *error) {
        if (result.length) {
            textView.text = result;
        } else {
            YYShowAlert(@"翻译失败", error ? error.localizedDescription : @"未知错误");
            textView.text = source; // 失败时发送原文
        }
        %orig; // 触发 QQ 发送当前文本（译文或原文）
        yyTranslating = NO;
    };

    if (target) {
        [[YueyuTranslator sharedInstance] translateText:source toLanguage:target completion:handler];
    } else {
        [[YueyuTranslator sharedInstance] translateText:source completion:handler];
    }
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
    NSLog(@"[YueyuKeyboard] 已加载 (翻译功能 v0.2，命令式 + 按钮式)");
}