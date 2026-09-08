# v0.41.52 · 日记真实整理与主动新话题平衡

## 真机根因

v0.41.51 存档里共有 12 篇日记，12 篇都带同一个收尾，10 篇还带同一个“没有完全放下”段落。原因不是模型偏好，而是旧实现直接用固定模板拼接 DailyContinuity，并且只取第一个 shared moment，把 cares 和 awareness 压成布尔占位，也完全没有使用 carried threads。

主动联系的选择标签虽已有 curiosity、share thought 和 public web，但“新话题”只清空了最近聊天，PromptBuilder 随后仍注入 Memory、关系、近日连续性、参考资料和既有公开知识。于是上游选中了新题，下游正文仍很容易被旧事填满。网页 Provider 本身正常；83 个活动候选中只有 1 个进入分享候选，额外的 social readiness 条件也是可见分享稀少的瓶颈。

## 日记边界

- 日记只读取已 finalized 的前一日 DailyContinuity：最多 3 个 shared moments、2 个 cares、2 个 carried threads、2 个 awareness summary，以及数量字段。
- DeepSeek Flash 只负责把这些已整理材料写成第一人称日记；不能补造聊天、现实经历、网页事实或关系进展。
- 最近 7 篇正文用于避开中心和句式。60～800 字以外、命中旧固定话术或 bigram Jaccard 相似度达到 0.72 的模型稿会被拒绝。
- API 缺失、超时、格式错误或质量门失败时，使用只拼真实材料的 factual fallback。日记继续是 derived projection，不反写 Memory、AI Self、人格学习、兴趣证据或 Desire，也不重写既有日记。

## 主动新题边界

- curiosity、share thought、social share 的新题回合不再注入旧 Memory、关系事件、近日连续性、参考资料或既有公开知识正文。
- 仍保留本轮选中 Thought/网页候选、当前 Desire、Emotion、Somatic、Awareness 和表达层；没有具体新内容可以 WAIT。
- 选择器只统计最近 24 小时真正完成并对用户可见的 proactive message / public web share。最近最多 8 次若新鲜来源不足一半，会给新鲜候选有界加分、给 Memory/user history 有界摩擦；达到一半后不再强推较弱的新题。
- 这是一半一半的滚动倾向，不是逐条硬配额；疲劳、频率、忙碌、事实、权限、Grounding、模型自主 WAIT 和最终 Gate 都保持有效。
- 网页候选原 social-ready 路线保留；当 share score ≥ 0.74 且主观价值 ≥ 0.58 时，也可独立进入 share candidate，仍须经过后续选择与投递门。

## 可审计性与 UI 收尾

诊断设置会记录最近可见总数、新鲜来源数、短缺数、本次新鲜加权和旧上下文摩擦；策略事件只记录固定枚举，不保存 Thought、聊天或网页正文。

v0.41.51 真机证明“其他相册应用”仍不能让该 ROM 暴露小米相册，故 v0.41.52 删除该入口及整原生桥，保留原系统图片选择器/文件夹路径。表情长按仍显示完整 caption，但不再显示“完整语义：”标签。

## 真机观察

自动化只能证明边界和回归。安装后至少观察：下一篇新日记没有旧固定尾句且事实可追溯；自然主动联系中出现自身新观察或真实网页分享，同时旧事 follow-up 仍偶尔可见。达到模式变化需要自然积累数次可见主动消息，不要求等待固定时长。
