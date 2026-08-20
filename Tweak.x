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
#import <substrate.h>
#import "YueyuTranslator.h"
#import "YueyuSettings.h"

static void YYOpenMenu(void);

// QQInputAccessoryView 头文件声明（逆向头文件里是 UICollectionView 子类）
@interface QQInputAccessoryView : UICollectionView
@end


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

static UIWindow *YYKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    return windowScene.windows.firstObject;
                }
            }
        }
    }
    return nil;
}

static UITextView *YYCurrentInputTextView(UIViewController *vc) {
    if (vc.view) {
        UIView *v = YYFindSubview(vc.view, NSClassFromString(@"QQInputTextView"));
        if (v) return (UITextView *)v;
    }
    UIWindow *window = YYKeyWindow();
    if (window) return YYFirstResponderTextView(window);
    return nil;
}

static void YYShowAlert(NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *top = YYKeyWindow().rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (top) [top presentViewController:alert animated:YES completion:nil];
}

static void YYShowToast(NSString *message) {
    UIWindow *window = YYKeyWindow();
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

- (void)menuTapped:(id)sender {
    YYOpenMenu();
}

@end

#pragma mark - Hook 1：发送拦截（翻译指令）

static BOOL yyTranslating = NO;

// Swift 类不能直接 %hook（Logos 警告会变错误且不可靠），改用运行时方法替换
static void (*yyOrigActionSend)(id, SEL);

static void yyNewActionSend(id self, SEL _cmd) {
    if (yyTranslating) { yyOrigActionSend(self, _cmd); return; }
    if (![YueyuSettings translateEnabled]) { yyOrigActionSend(self, _cmd); return; }

    UITextView *textView = YYCurrentInputTextView(self);
    if (!textView) { yyOrigActionSend(self, _cmd); return; }

    NSString *source = nil;
    NSString *target = nil;
    if (!YYParseTranslateCommand(textView.text, &source, &target)) { yyOrigActionSend(self, _cmd); return; }

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
        yyOrigActionSend(self, _cmd);
        yyTranslating = NO;
    };

    [[YueyuTranslator sharedInstance] translateText:source toLanguage:target completion:handler];
}

#pragma mark - Hook 2：输入附件栏加工具栏（◀ ▶ 复制 翻译）

%hook QQInputAccessoryView

- (void)layoutSubviews {
    %orig;
    UIView *existing = [self viewWithTag:kYYToolbarTag];
    if (!existing) {
        NSArray *defs = @[
            @{ @"title": @"☰", @"sel": @"menuTapped:", @"w": @34 },
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
    // 拦截发送（Swift 类用运行时 hook）
    Class inputBarCls = NSClassFromString(@"NTAIOChat.NTAIOShortcutBarItemInputBarViewController");
    if (inputBarCls) {
        MSHookMessageEx(inputBarCls, @selector(actionSend), (IMP)yyNewActionSend, (IMP *)&yyOrigActionSend);
    } else {
        NSLog(@"[YueyuKeyboard] 未找到输入栏类，命令式翻译可能不生效");
    }
    NSLog(@"[YueyuKeyboard] 已加载 (键盘工具栏 v0.4：翻译/复制/左右移动)");
}

#pragma mark - QQ 内主菜单（键盘工具栏 ☰ 入口，无需系统设置）

@interface YueyuMenuController : UIViewController <UITextFieldDelegate>
@end

@implementation YueyuMenuController {
    UISwitch *_enableSwitch;
    UISwitch *_toastSwitch;
    UISwitch *_bothSwitch;
    UISegmentedControl *_langSeg;
    UITextField *_baiduIdField;
    UITextField *_baiduKeyField;
}

- (NSUserDefaults *)yyPrefs {
    return [[NSUserDefaults alloc] initWithSuiteName:@"com.yueyu.qqkeyboard"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"越狱插件键盘";
    self.view.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeTapped)];

    NSUserDefaults *prefs = [self yyPrefs];
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];

    CGFloat y = 16;

    y = [self yyGroup:@"翻译行为" y:y in:scroll];

    _enableSwitch = [[UISwitch alloc] init];
    BOOL en = [prefs objectForKey:@"YYTranslateEnabled"] ? [prefs boolForKey:@"YYTranslateEnabled"] : YES;
    [_enableSwitch setOn:en];
    [_enableSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    y = [self yyRow:@"启用翻译功能" control:_enableSwitch y:y in:scroll];

    _toastSwitch = [[UISwitch alloc] init];
    BOOL to = [prefs objectForKey:@"YYShowToast"] ? [prefs boolForKey:@"YYShowToast"] : YES;
    [_toastSwitch setOn:to];
    [_toastSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    y = [self yyRow:@"显示“翻译中…”提示" control:_toastSwitch y:y in:scroll];

    _bothSwitch = [[UISwitch alloc] init];
    BOOL bo = [prefs objectForKey:@"YYSendBoth"] ? [prefs boolForKey:@"YYSendBoth"] : NO;
    [_bothSwitch setOn:bo];
    [_bothSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    y = [self yyRow:@"原文 + 译文一起发送" control:_bothSwitch y:y in:scroll];

    NSArray *langTitles = @[@"自动", @"中文", @"英文", @"日文", @"韩文", @"法文", @"德文", @"俄文"];
    _langSeg = [[UISegmentedControl alloc] initWithItems:langTitles];
    _langSeg.frame = CGRectMake(0, 0, 210, 30);
    _langSeg.selectedSegmentIndex = 0;
    NSString *cur = [prefs stringForKey:@"YYDefaultTargetLang"];
    NSArray *codes = @[@"auto", @"zh", @"en", @"ja", @"ko", @"fr", @"de", @"ru"];
    for (NSUInteger i = 0; i < codes.count; i++) {
        if ([cur isEqualToString:codes[i]]) { _langSeg.selectedSegmentIndex = i; break; }
    }
    [_langSeg addTarget:self action:@selector(langChanged:) forControlEvents:UIControlEventValueChanged];
    y = [self yyRow:@"默认目标语言" control:_langSeg y:y in:scroll];

    y += 6;

    y = [self yyGroup:@"百度翻译（可选，不填自动用谷歌）" y:y in:scroll];

    _baiduIdField = [self yyField:@"fanyi-api.baidu.com 申请" secure:NO text:[prefs stringForKey:@"YYBaiduAppID"]];
    y = [self yyRow:@"百度 App ID" control:_baiduIdField y:y in:scroll];

    _baiduKeyField = [self yyField:@"申请后获取" secure:YES text:[prefs stringForKey:@"YYBaiduSecretKey"]];
    y = [self yyRow:@"百度密钥" control:_baiduKeyField y:y in:scroll];

    y += 6;

    y = [self yyGroup:@"用法" y:y in:scroll];

    UILabel *use = [[UILabel alloc] initWithFrame:CGRectMake(16, y, self.view.bounds.size.width - 32, 80)];
    use.numberOfLines = 0;
    use.font = [UIFont systemFontOfSize:13];
    use.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    use.text = @"命令：翻译:xx / #fy / #fyzh / #fyen / #fyja / #fyko / #fyfr / #fyde / #fyru\n工具栏：◀ ▶ 光标移动 ｜ 复制 ｜ 翻译 ｜ ☰ 菜单\n提示：填了百度 Key 用百度，没填自动用谷歌翻译。";
    [scroll addSubview:use];
    y += 96;

    scroll.contentSize = CGSizeMake(self.view.bounds.size.width, y + 20);
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)switchChanged:(UISwitch *)s {
    NSString *key = (s == _enableSwitch) ? @"YYTranslateEnabled" : (s == _toastSwitch) ? @"YYShowToast" : @"YYSendBoth";
    NSUserDefaults *p = [self yyPrefs];
    [p setBool:s.on forKey:key];
    [p synchronize];
}

- (void)langChanged:(UISegmentedControl *)seg {
    static NSArray *codes = nil;
    if (!codes) codes = @[@"auto", @"zh", @"en", @"ja", @"ko", @"fr", @"de", @"ru"];
    NSUserDefaults *p = [self yyPrefs];
    [p setObject:codes[seg.selectedSegmentIndex] forKey:@"YYDefaultTargetLang"];
    [p synchronize];
}

- (void)textFieldDidEndEditing:(UITextField *)f {
    NSUserDefaults *p = [self yyPrefs];
    [p setObject:(f.text ?: @"") forKey:(f == _baiduIdField ? @"YYBaiduAppID" : @"YYBaiduSecretKey")];
    [p synchronize];
}

- (UITextField *)yyField:(NSString *)ph secure:(BOOL)sec text:(NSString *)text {
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 170, 30)];
    f.borderStyle = UITextBorderStyleRoundedRect;
    f.placeholder = ph;
    f.secureTextEntry = sec;
    f.font = [UIFont systemFontOfSize:14];
    f.text = text ?: @"";
    f.delegate = self;
    return f;
}

- (CGFloat)yyGroup:(NSString *)title y:(CGFloat)y in:(UIScrollView *)scroll {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, y, 300, 20)];
    l.text = title;
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    l.textColor = [UIColor colorWithRed:0.42 green:0.46 blue:0.55 alpha:1.0];
    [scroll addSubview:l];
    return y + 26;
}

- (CGFloat)yyRow:(NSString *)label control:(UIView *)control y:(CGFloat)y in:(UIScrollView *)scroll {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, y, 160, 34)];
    l.text = label;
    l.font = [UIFont systemFontOfSize:15];
    l.textColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    [scroll addSubview:l];
    CGRect f = control.frame;
    f.origin = CGPointMake(self.view.bounds.size.width - f.size.width - 16, y + (34 - f.size.height) / 2);
    control.frame = f;
    [scroll addSubview:control];
    return y + 42;
}

@end

static void YYOpenMenu(void) {
    UIWindow *window = YYKeyWindow();
    if (!window) return;
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;
    YueyuMenuController *mc = [[YueyuMenuController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [top presentViewController:nav animated:YES completion:nil];
}
