import 'package:flutter/material.dart';

import '../../core/agent/agent_tool.dart';
import '../../core/agent/agent_tool_registry.dart';

/// User-facing capability guide. Executable Agent entries are read from the
/// same registry as the runtime so this page cannot silently advertise a tool
/// that is only present in a prompt or an old project note.
class CapabilityHelpPage extends StatelessWidget {
  const CapabilityHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chatTools = AgentToolRegistry.all
        .where((tool) => tool.executable && tool.userTurnAvailable)
        .toList(growable: false);
    final autonomousTools = AgentToolRegistry.all
        .where((tool) => tool.executable && tool.autonomousAvailable)
        .toList(growable: false);
    final unavailableTools = AgentToolRegistry.all
        .where((tool) => !tool.executable)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('帮助与真实能力')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '这里按当前程序实际能力整理，不把计划中的功能写成已经可用。'
                '工具仍会遵守权限、隐私、网络、额度和停止状态；失败时不会用对白冒充成功。',
              ),
            ),
          ),
          const _HelpSection(
            icon: Icons.manage_search_rounded,
            title: '让她检查自己的系统',
            initiallyExpanded: true,
            children: [
              _HelpParagraph(
                '在普通聊天中使用确定性前缀，例如：\n'
                '【检查系统】看看你有哪些真实功能\n'
                '【检查系统】最近调用结果\n'
                '【检查系统】成长与人格学习',
              ),
              _HelpParagraph(
                '自然语言也可以触发相关能力；前缀只用于明确自查范围，不是授权口令。'
                '沉浸房间是独立玩法，不执行这条系统检查命令。',
              ),
            ],
          ),
          _ToolSection(
            icon: Icons.chat_bubble_outline_rounded,
            title: '普通聊天可调用',
            subtitle: '只有当前真实可执行、且允许由用户对话触发的工具会出现在这里。',
            tools: chatTools,
          ),
          _ToolSection(
            icon: Icons.auto_awesome_motion_rounded,
            title: '她可自主使用',
            subtitle: '自主能力仍受 Desire、Thought、预算、隐私和结果核验约束，不代表每轮都会使用。',
            tools: autonomousTools,
          ),
          const _HelpSection(
            icon: Icons.stop_circle_outlined,
            title: '停止、刷新与卡住时怎么办',
            children: [
              _HelpParagraph(
                '生成或工具执行中可以点停止。被停止的未完成回复不会进入上下文和记忆；'
                '联网、读网页和图片任务也会接收同一停止信号。',
              ),
              _HelpParagraph(
                '刷新本条会重新生成当前回复，确认后才按正常消息写入。若停止后仍长期显示执行中，'
                '先保存同一时刻的脱敏诊断报告，再重新打开 App；不需要反复发送同一句指令。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.photo_library_outlined,
            title: '网页、图片与查手机',
            children: [
              _HelpParagraph(
                '明确要求搜索时，她可以搜索公开网页、读取网页正文并保留来源；普通“看看”不会自动当成联网授权。',
              ),
              _HelpParagraph(
                '她可以只读搜索自己的日记、随笔、心情、愿望、购物车、塔罗、浏览器和相册。'
                '按明确要求还可以发送本地表情包、已存相册图片或联网图片，并以真实附件结果为准。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.sports_esports_outlined,
            title: 'Cedar Toy 游戏厅',
            children: [
              _HelpParagraph(
                'Cedar 专用 MCP 已接通：她可以读取实时游戏列表和指南、执行合法动作、继续同一局，'
                '并在活动窗显示真实进展。网站的回合、防沉迷、房间和终局结果优先于本地猜测。',
              ),
              _HelpParagraph(
                '通用 MCP Registry 尚未开放。当前能玩 Cedar 不等于已经能连接任意 MCP 服务或工作区。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.graphic_eq_rounded,
            title: '本地语音与呈现',
            children: [
              _HelpParagraph(
                'Genie TTS 在本机生成语音，支持中/日/EN、四种音色、语速、音量、停止和缓存。'
                '首次加载或较长文本会更慢；情绪音效与 TTS 是两套独立播放链。',
              ),
              _HelpParagraph(
                '普通聊天、悬浮聊天和沉浸房间共享主要呈现设置；沉浸房间有独立场景和记忆边界。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.backup_outlined,
            title: '备份、恢复与设备接管',
            children: [
              _HelpParagraph(
                '完整备份用于迁移本地数据库、设置和受支持媒体。恢复前会预检；恢复、删除和设备接管属于高影响操作，'
                '应先保留可用备份，不要用聊天承诺代替真实恢复结果。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.privacy_tip_outlined,
            title: '权限与隐私边界',
            children: [
              _HelpParagraph(
                '读取手机状态只提供当前 App、屏幕/锁屏状态和粗粒度忙碌度。'
                '查看当前屏幕必须由你明确请求，并经过敏感页面拦截；临时截图不会保存到相册。',
              ),
              _HelpParagraph(
                'Token、绑定码、私密房间正文、用户图片、备份和诊断不会作为公开项目内容。'
                '系统权限被关闭、网络失败或模型额度不足时，对应能力会如实失败或延后。',
              ),
            ],
          ),
          _ToolSection(
            icon: Icons.hourglass_disabled_outlined,
            title: '尚未开放',
            subtitle: '这些条目只保留为未来能力定义，当前没有可执行入口。',
            tools: unavailableTools,
            showRisk: false,
          ),
          const _HelpSection(
            icon: Icons.troubleshoot_rounded,
            title: '排查问题时提供什么',
            children: [
              _HelpParagraph(
                '优先提供：问题发生的大致时间、当时看到的提示、同一时刻导出的脱敏诊断报告。'
                '涉及存档状态、记忆、游戏连续性或媒体引用时，再附同一时刻的完整备份。',
              ),
              _HelpParagraph(
                '诊断报告用于定位权限、工具阶段和失败分类；备份用于核对持久状态。'
                '两者不会自动证明没有记录到的屏幕现象，所以偶发 UI 问题最好同时附截图。',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolSection extends StatelessWidget {
  const _ToolSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tools,
    this.showRisk = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<AgentToolDefinition> tools;
  final bool showRisk;

  @override
  Widget build(BuildContext context) => _HelpSection(
        icon: icon,
        title: title,
        children: [
          _HelpParagraph(subtitle),
          for (final tool in tools)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                tool.risk == AgentToolRisk.readOnly
                    ? Icons.visibility_outlined
                    : Icons.play_circle_outline_rounded,
                size: 21,
              ),
              title: Text(tool.title),
              subtitle: Text(tool.description),
              trailing: showRisk
                  ? Text(
                      tool.risk == AgentToolRisk.readOnly ? '只读' : '会执行',
                      style: Theme.of(context).textTheme.labelSmall,
                    )
                  : null,
            ),
        ],
      );
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 12),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Icon(icon),
          title: Text(title),
          initiallyExpanded: initiallyExpanded,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: children,
        ),
      );
}

class _HelpParagraph extends StatelessWidget {
  const _HelpParagraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(text),
        ),
      );
}
