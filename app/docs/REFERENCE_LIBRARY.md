# Reference Library · v0.7

目的：保存用户实际导入的人设/设定参考资料，但不把 AI Companion 重新变成酒馆式角色扮演。

## 与 Memory Brain 的区别

Memory Brain：她真实和用户共同经历后形成的长期连续性。

Reference Library：用户主动导入的外部资料，例如旧角色的人设、背景、说话方式、偏好、扮演素材。

Reference 永远不能自动改写 AI Self。

## 检索优先级

1. 当前用户明确要求
2. 已确认边界 / 当前 Session
3. 现实关系历史 / Memory Brain / AI Self
4. Reference Library
5. 模型一般知识

## v0.7 导入

先提供 JSON/文本粘贴式导入层，用于验证数据结构。

解析器主动过滤聊天、history、reasoning、save、log、cache 等动态字段。等后续拿到实际 index 导出文件，再按真实结构增加精确“一键导入”，避免现在猜测字段导致误导入。
