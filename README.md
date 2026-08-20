# 越狱插件键盘（YueyuKeyboard）

> iOS 越狱插件（Theos / Logos tweak），面向 **QQ iOS 9.3.35** 的自定义键盘插件。
> 逆向参考：`D:\gpt.ggit\QQ9.3.35版本头文件-20260819-2154.zip`（130,865 个头文件）。

## 已实现功能

### 键盘工具栏（v0.4：翻译 + 复制 + 左右移动光标）
- 输入附件栏最右侧一排按钮：◀ ▶ 复制 翻译
- **◀ ▶**：光标左/右移动 1 个字符（不收起键盘）
- **复制**：复制输入框内容；有选中文字则只复制选中部分
- **翻译**：原地翻译输入框内容（需设置里开启）

### 翻译（v0.3，百度优先 + 设置页）
- 配置：iOS 设置 → 越狱插件键盘（百度 App ID/密钥、默认语言、开关）
- 引擎：百度优先（填 Key 时），失败自动切 Google；没填 Key 直接用 Google
- 命令：翻译:xx / #fy / #fyzh / #fyen / #fyja / #fyko / #fyfr / #fyde / #fyru
- 开关：启用翻译、原文+译文一起发、翻译中提示
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