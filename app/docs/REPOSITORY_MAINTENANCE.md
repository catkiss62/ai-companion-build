# 仓库维护合同

本文只描述如何安全维护仓库，不定义 App 运行行为。`app/` 仍是唯一源码真源。

## 日常接班

1. 读取根目录 `AI_Companion_当前总账.md` 的接班协议、永久边界、当前基线、当前任务和后续导航。
2. 读取 `DOCUMENTATION_MAP.md`，再按本次模块打开专项文档、源码、测试和 validator。
3. 已完成版本的过程记录不默认全文读取。需要追溯时，先按版本、类名、设置键或故障词定点搜索冻结归档和 Git 历史。
4. 诊断与备份只在临时工作区取证，禁止提交到公开仓库。

这样可避免每轮同时加载当前总账、冻结总账和所有专项文档。旧证据仍可恢复，但不占用普通维护上下文。

## 分支与 `main`

- 功能开发和仓库维护使用独立分支；仓库维护从最近已构建且源码权威的开发分支切出。
- `main` 当前是旧稳定线，不自动合并，也不把它当作 v0.41.x 的开发起点。
- 等一个完整开发里程碑完成 CI 与真机验收后，再由用户明确决定是否把 `main` 快进到该检查点。
- 不为“整洁”批量删除旧分支、改写 Git 历史或迁移大型资源。它们不会显著减少日常模型读取量，却会扩大恢复风险。

## Source/regression validator

工作流只调用：

```bash
cd app
python3 tools/run_validation_suite.py
```

有序清单位于 `tools/validation_suite.txt`。统一入口在执行前会拒绝重复项、缺失文件、目录穿越和非 `validate_*.py` 项，然后按清单顺序逐项运行；任一 validator 失败即保持原有的 fail-fast 行为。

少数旧 validator 会扫描工作流并查找自己的文件名，因此工作流保留一段不执行的兼容标记；它不是第二份执行清单。新增 validator 不再建立这种反向依赖。

新增版本时只需：

1. 新建专项 validator；
2. 把相对路径追加到清单末尾；
3. 运行 `python3 tools/run_validation_suite.py --check-only`；
4. 再运行专项门和完整清单。

不得用自动 glob 替代清单。仓库含历史或仅用于特定环境的 validator，全部盲跑会重新引入已退役合同。

## 总账索引与归档

- 根目录当前总账是唯一日常入口。顶部至 `END QUICK HANDOFF INDEX` 是快速接班索引，包含永久边界、当前基线、当前任务、真机待验证和正文/归档导航；新窗口默认先读这一段。
- 标记后的正式记录不设字节上限，按版本持续追加。不得为了满足文件总大小而删除仍有交接价值的正式内容。
- 只有自然阶段边界、文件操作确实变慢或需要不可变证据快照时才新建带截止版本的只读归档，并记录 byte count 与 SHA-256；归档不是固定容量触发的强制动作。
- 建立归档后同步 `validate_current_ledger_handoff.py` 与 `DOCUMENTATION_MAP.md`。validator 只约束快速索引的边界/必要事实和既有归档完整性，不限制正式正文总容量。

## CI、资源与旧 Actions

- 文档限定变更继续走轻量 scope；源码、资产、配置、工作流、混合或无法判断的变更继续跑完整 APK 链。手动 dispatch 始终完整构建。
- 私有 TTS、桌宠、LingChat 与塔罗恢复/校验保持原样；本轮不迁移资源包、不修改恢复顺序。
- Artifact 由工作流按 14 天保留。旧 Actions run 数量本身不增加源码维护上下文，也不需要为仓库优化手动删除；Draft/Release 与 run 的清理属于独立、显式授权的破坏性维护。
- 当前工作流仍包含资源恢复、签名、APK 校验、Draft 上传和历史兼容标记。只有出现确定的维护故障，才分模块提取；不为了缩短 YAML 一次性重写发布链。

## 提交前最小检查

```bash
git diff --check
python3 app/tools/run_validation_suite.py --check-only
python3 -m py_compile app/tools/run_validation_suite.py
```

涉及工作流时另做 YAML 解析；涉及 App 运行行为时按总账要求运行专项测试、完整 validator、Flutter/Kotlin 测试和 APK 构建。文档或维护工具通过不等于真机功能已经通过。
