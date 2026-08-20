# 越狱插件键盘（YueyuKeyboard）

> iOS 越狱插件（Theos / Logos tweak），面向 **QQ iOS 9.3.35** 的自定义键盘插件。
> 逆向参考：`D:\gpt.ggit\QQ9.3.35版本头文件-20260819-2154.zip`
> （STFX Header Dump v1.1 导出，共 130,865 个头文件，约 158.7 MB）

## 项目目标
给 QQ 聊天输入框注入自定义键盘 / 键盘扩展。
（具体功能待确认：快捷短语 / 自定义表情 / 快捷指令 / 其他）

## 当前状态
- [x] 项目骨架搭建（Theos 结构 + 辅助脚本 + 逆向参考索引）
- [ ] 确定具体功能需求
- [ ] 定位 QQ 键盘相关类（初步候选见 `References/QQ9.3.35-键盘相关类.md`）
- [ ] 编写 Logos 钩子，编译出 deb
- [ ] 真机测试

## 目录结构
```
越狱插件键盘/
├── README.md                 # 本文件
├── control                   # 包元数据（deb）
├── Makefile                  # Theos 构建脚本
├── Tweak.x                   # Logos 钩子入口（骨架）
├── layout/                   # 打包后安装到设备的文件
│   └── Library/MobileSubstrate/DynamicLibraries/
│       └── YueyuKeyboard.plist   # 注入范围：仅 QQ(com.tencent.mqq)
├── Scripts/                  # 辅助脚本（Windows PowerShell）
│   ├── search_header.ps1     # 在压缩包里搜类名（不解压）
│   └── extract_headers.ps1   # 把匹配的头文件解压出来
├── References/               # 逆向参考
│   └── QQ9.3.35-键盘相关类.md
├── work/                     # 中间产物（草稿、笔记、日志）
└── outputs/                  # 最终交付物（deb、截图等）
```

## 构建前置
- [Theos](https://theos.dev)（macOS 推荐；Windows 可用 WSL 交叉编译）
- 越狱设备（iOS 13+，arm64）用于安装测试

## 快速开始
1. 确定功能需求，更新本 README 的目标章节
2. 用 `Scripts\search_header.ps1 关键词` 在头文件包里找目标类
3. 用 `Scripts\extract_headers.ps1 关键词` 解压相关头文件到 `References\`
4. 在 `Tweak.x` 里写 `%hook`，`make package` 出 deb
5. 安装到设备测试，截图存 `outputs\`

## 约定
- 遵循 `D:\gpt.ggit` 记忆库规则：中间产物放 `work/`，交付物放 `outputs/`
- 每个阶段结束更新记忆库文档（主线 / 交接）