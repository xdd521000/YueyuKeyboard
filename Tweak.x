// 越狱插件键盘 - 入口（骨架版本 0.0.1）
// 逆向参考类名见 References/QQ9.3.35-键盘相关类.md

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// TODO(需求确认后)：把下面的示例替换为真实要 hook 的 QQ 类
// 候选：QQInputTextView / QQInputAccessoryView / QQInputbarButton / QQInputIconButton
//       / EmojiBoardContainer.NTFaceRichBoardContainerBaseViewController 等

// 示例（确认类名后取消注释并改写）：
// %hook QQInputTextView
// - (void)setText:(id)text {
//     %orig; // 保留原逻辑
//     // 在这里注入你的逻辑
// }
// %end

%ctor {
    NSLog(@"[YueyuKeyboard] 已加载 (骨架版本 0.0.1)");
}