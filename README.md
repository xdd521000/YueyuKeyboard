# 越狱插件键盘（YueyuKeyboard）

> iOS 越狱插件（Theos / Logos tweak），面向 **QQ iOS 9.3.35** 的自定义键盘插件。
> 逆向参考：`D:\gpt.ggit\QQ9.3.35版本头文件-20260819-2154.zip`（130,865 个头文件）。

## 已实现功能

### 翻译（v0.3，百度优先 + 设置页）
- **配置入口**：iOS 设置 → 越狱插件键盘
  - 百度翻译 App ID / 密钥（fanyi-api.baidu.com 免费申请）
  - 默认目标语言（自动/中/英/日/韩/法/德/俄）
  - 开关：启用翻译、原文+译文一起发、翻译中提示
- **翻译引擎**：设置里填了百度 Key → 百度优先，失败自动切 Google；没填 → 直接用 Google。
- **命令式**（输入后发送）：
  | 输入 | 效果 |
  |------|------|
  | `翻译:你好` / `#fy 你好` | 按设置默认语言翻译 |
  | `#fyzh hello` | 译为中文 |
  | `#fyen 你好` | 译为英文 |
  | `#fyja` / `#fyko` / `#fyfr` / `#fyde` / `#fyru` | 日 / 韩 / 法 / 德 / 俄 |
- **按钮式**：QQ 输入附件栏右侧「翻译」按钮，点击原地翻译输入框内容。
- 失败处理：命令式发送原文、按钮式弹窗，不丢内容。

## 当前状态
- [x] 项目骨架 + 逆向参考索引
- [x] 翻译 v0.1 命令式 → v0.2 按钮式 → v0.3 百度引擎 + 设置页
- [ ] 编译出 deb 并真机测试（测试清单：`work/真机测试清单.md`）

## 目录结构
```
越狱插件键盘/
├── README.md
├── control                       # 包元数据
├── Makefile                      # Theos 构建（tweak + 设置 bundle）
├── Tweak.x                       # Logos 钩子（翻译 v0.3）
├── YueyuTranslator.h/.m          # 翻译引擎（百度 + 谷歌备用）
├── YueyuSettings.h/.m            # 读取设置（NSUserDefaults）
├── YueyuKeyboardSettings.m       # 设置页控制器
├── .github/workflows/build-deb.yml  # GitHub Actions 云端打包
├── layout/                       # 打包后安装到设备的文件
│   ├── Library/MobileSubstrate/DynamicLibraries/YueyuKeyboard.plist  # 注入范围：QQ
│   └── Library/PreferenceBundles/YueyuKeyboardSettings.bundle/       # 设置页
│       └── Library/PreferenceLoader/Preferences/YueyuKeyboard.plist  # 设置入口
├── Scripts/                      # 头文件检索/解压脚本
├── References/                   # 逆向参考索引
├── work/                         # 中间产物（测试清单等）
└── outputs/                      # 最终交付物
```

## 构建与测试
- 打包：`make package`（或 GitHub Actions 工作流 `build-deb`）
- 安装：Filza 直接装 deb 或 `dpkg -i`，装完重启 QQ
- 测试：按 `work/真机测试清单.md`

## 约定
- 遵循 `D:\gpt.ggit` 记忆库规则：中间产物放 `work/`，交付物放 `outputs/`；对话结束更新交接文档。