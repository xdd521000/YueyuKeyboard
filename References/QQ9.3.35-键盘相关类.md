# QQ 9.3.35 · 键盘/输入相关类（逆向参考索引）

> 来源：STFX Header Dump v1.1 导出头文件包（130,865 个）。
> 检索方式：`Scripts\search_header.ps1 关键词` 可随时重新检索。

## 聊天输入区（QQInput*）
| 类名 | 头文件 |
|------|--------|
| QQInputTextView | 123893_QQInputTextView.h |
| QQInputAccessoryView | 123729_QQInputAccessoryView.h |
| QQInputbarButton | 125404_QQInputbarButton.h |
| QQInputIconButton | 125406_QQInputIconButton.h |
| QQInputDefaultTextViewController | 129589_QQInputDefaultTextViewController.h |
| QQInputMaterialConfigManager | 018003_QQInputMaterialConfigManager.h |
| InputMaterialRecommendView | 123733_InputMaterialRecommendView.h |
| InputMaterialKeywordMatchManager | 080292_InputMaterialKeywordMatchManager.h |

## 表情面板（EmojiBoard / Emoji）
| 类名 | 头文件 |
|------|--------|
| EmojiBoardContainer.NTFaceRichBoardContainerBaseViewController | 126897_EmojiBoardContainer.NTFaceRichBoardContainerBaseViewController.h |
| EmojiBoardContainer.EmojiGroupModel | 002235_EmojiBoardContainer.EmojiGroupModel.h |
| EmojiBoardContainer.EmojiItemModel | 032752_EmojiBoardContainer.EmojiItemModel.h |
| EmojiBoardContainer.EmojiGroupHeaderViewModel | 032764_EmojiBoardContainer.EmojiGroupHeaderViewModel.h |
| EmojiCollectionView | 123688_EmojiCollectionView.h |
| EmojiContainerView | 117107_EmojiContainerView.h |
| QQEmojiSingleView | 113520_QQEmojiSingleView.h |
| QQEmojiPreView | 114176_QQEmojiPreView.h |
| QQEmojiInfo | 090025_QQEmojiInfo.h |

## 内联键盘 / 其他
| 类名 | 头文件 |
|------|--------|
| NTAIOChat.NTAIOInlineKeyboardDefine | 001045_NTAIOChat.NTAIOInlineKeyboardDefine.h |
| QQFTFAddFriendKeyboardView | 113510_QQFTFAddFriendKeyboardView.h |
| TenpayNumKeyboardView | 117744_TenpayNumKeyboardView.h |

## 说明
- `_Tt*` / `Swift.*` 为 Swift 混淆符号，一般不是 hook 目标，检索时已过滤。
- hook 前先用 `extract_headers.ps1` 解压目标头文件看方法签名。