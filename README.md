# 越狱插件键盘（YueyuKeyboard）

> iOS 越狱插件（Theos / Logos tweak），面向 **QQ iOS 9.3.35** 的自定义键盘插件。
> 逆向参考：`D:\gpt.ggit\QQ9.3.35版本头文件-20260819-2154.zip`
> （STFX Header Dump v1.1 导出，共 130,865 个头文件，约 158.7 MB）

## 项目目标
给 QQ 聊天输入框注入自定义键盘 / 键盘扩展。
（翻译已实现 v0.2；候选：快捷短语 / 自定义表情 / 快捷指令 / 增强开关）

## 已实现功能

### 翻译（v0.2，命令式 + 按钮式）
- 方式 A（命令式）：输入指令后发送，插件自动翻译并发送译文。
  | 指令 | 效果 |
  |------|------|
  | `翻译:你好` / `#fy 你好` | 自动判断语言（中文→英文，英文→中文） |
  | `#fyzh hello` | 强制译为中文 |
  | `#fyen 你好` | 强制译为英文 |
- 方式 B（按钮式）：QQ 输入附件栏最右侧「翻译」按钮，点击把输入框内容原地翻译。
- 翻译失败：命令式发送原文、按钮式弹窗提示，不丢内容。
- 翻译引擎：`YueyuTranslator.h/.m`（无需 API Key 的公开端点，可替换为百度/DeepL）。
- Hook 点：`NTAIOShortcutBarItemInputBarViewController -actionSend` + `QQInputAccessoryView`（基于 9.3.35 头文件，真机验证时可能需微调）。

## 当前状态
- [x] 项目骨架搭建（Theos 结构 + 辅助脚本 + 逆向参考索引）
- [x] 翻译功能代码（命令式 + 按钮式，未真机编译验证）
- [ ] 编译出 deb 并真机测试（测试清单：`work/真机测试清单.md`）
- [ ] 其他功能：快捷短语 / 自定义表情 / 快捷指令 / 增强开关

## 目录结构
```
越狱插件键盘/
├── README.md                 # 本文件
├── control                   # 包元数据（deb）
├── Makefile                  # Theos 构建脚本
├── Tweak.x                   # Logos 钩子（翻译功能 v0.2）
├── YueyuTranslator.h/.m      # 翻译引擎
├── layout/                   # 打包后安装到设备的文件
│   └── Library/MobileSubstrate/DynamicLibraries/
│       └── YueyuKeyboard.plist   # 注入范围：仅 QQ(com.tencent.mqq)
├── Scripts/                  # 辅助脚本（Windows PowerShell）
│   ├── search_header.ps1     # 在压缩包里搜类名（不解压）
│   └── extract_headers.ps1   # 把匹配的头文件解压出来
├── References/               # 逆向参考
│   └── QQ9.3.35-键盘相关类.md
├── work/                     # 中间产物（草稿、笔记、日志、测试清单）
└── outputs/                  # 最终交付物（deb、截图等）
```

## 构建前置
- [Theos](https://theos.dev)（macOS 推荐；Windows 可用 WSL 交叉编译）
- 越狱设备（iOS 13+，arm64）用于安装测试

## 快速开始
1. 用 `Scripts\search_header.ps1 关键词` 在头文件包里找目标类
2. 用 `Scripts\extract_headers.ps1 关键词` 解压相关头文件到 `References\`
3. 在 `Tweak.x` 里写 `%hook`，`make package` 出 deb
4. 按 `work\真机测试清单.md` 真机测试，截图存 `outputs\`

## 约定
- 遵循 `D:\gpt.ggit` 记忆库规则：中间产物放 `work/`，交付物放 `outputs/`
- 每个阶段结束更新记忆库文档（主线 / 交接）