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
                '这里不是当前设备的可用性检测：还需开启对应功能、配置服务并授予必要权限；执行结果以实际回执为准。',
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
            subtitle: '这里列出自主工具；后台创作等能力另见下方说明。是否使用还取决于开关、当前状态、预算和真实结果，不代表每轮都会使用。',
            tools: autonomousTools,
          ),
          const _HelpSection(
            icon: Icons.hub_outlined,
            title: '模型通道与深度思考',
            children: [
              _HelpParagraph(
                '第一通道负责内部判断、整理和工具规划，也能生成回复；第二通道用于正文，开启并配置第三通道后会优先尝试第三通道。'
                '正文失败时按当前场景的重试与回退规则处理，留意失败提示；出现“使用 DS 回复”时可手动选择。模型对谈有独立规则。',
              ),
              _HelpParagraph(
                '深度思考允许更充分地查找、核对和处理任务，不保证每句话都调用工具，也不授予新的系统权限。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.palette_outlined,
            title: '小作品、委托与自主创作',
            children: [
              _HelpParagraph(
                '开启深度思考并明确委托后，可后台制作和预览本地 HTML 小作品。制作使用独立工作模型与思考设置；'
                '已有任务可继续或暂停，关闭深度思考不会自动停止已登记的工作。',
              ),
              _HelpParagraph(
                '自主创作有独立开关，允许她在符合空闲条件时从真实经历中构思和制作，不要求每天产出。'
                '制作完成与分享是不同阶段，私下完成不等于已经发给你；未授权的委托不会转成自主任务执行。',
              ),
              _HelpParagraph(
                '从聊天作品卡或作品集打开作品。作品内对话能结合该作品的细节和互动状态；普通聊天主要使用作品概况。'
                '作品源码、版本和受支持的进度随存档保存，这不代表她能修改 App 本身。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.forum_outlined,
            title: 'QQ 私聊与群聊',
            children: [
              _HelpParagraph(
                '先完成 QQ 连接与本人绑定，再按需要开启群聊、主动消息、语音或生图。群友昵称和群名不能代替本人绑定。'
                'QQ 各项开关与 App 内的开关需分别检查；发送成功以 QQ 实际回执为准。',
              ),
              _HelpParagraph(
                'QQ 历史只覆盖接入后实际收到并保存的内容，可按问题检索和分页回看，不会自动补齐从未接收的群历史。'
                '引用图片和动图可在可获取、可识别的范围内按问题读取；动图只选取预算允许的部分帧，不等于看完视频。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.history_rounded,
            title: '记忆、原文与房间',
            children: [
              _HelpParagraph(
                '记忆检索结合关键词、日期和本地语义匹配；索引准备中或语义检索不可用时，仍保留原有检索路径。'
                '没有召回不等于记录被删除。需要细节时可以按需追读保存的原文，摘要不能代表未读取的全部内容。',
              ),
              _HelpParagraph(
                '普通聊天、沉浸房间和模型对谈各有记录与归档范围。可以按需回看已结束的沉浸房间及模型对谈记录，'
                '剧情保持虚构边界，对谈观点保留发言者。模型对谈固定房间参与模型，失败重试不会换成另一模型代说。',
              ),
            ],
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
              _HelpParagraph(
                'App 每批图片可选择 DS 识图或千问识图，多张图片作为一条消息识别后一起回复。'
                '千问需配置视觉 API Key，识别失败时可回退 DS；发送前的选择只针对这一批图片。'
                '相册检索描述与实际看图是两件事，需要画面细节时应读取图片。',
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
                '开启游戏厅并配置有效凭据后，还可按自主游玩开关和当前状态选择游戏、继续已有活动；分享有独立开关。'
                '暂停或停止后以活动状态为准。通用 MCP Registry 尚未开放。当前能玩 Cedar 不等于已经能连接任意 MCP 服务或工作区。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.graphic_eq_rounded,
            title: '本地语音与呈现',
            children: [
              _HelpParagraph(
                'Genie TTS 在本机生成语音，支持中/日/EN、语速、音量、停止和缓存。日常、温柔、活泼、可爱四种语音风格可手动选择，也可自动判断；参考声音候选是另一项设置。'
                '预加载有助于后续播放，但切换语种或语音进程被系统回收后仍可能重新加载。情绪音效与 TTS 是两套独立播放链。',
              ),
              _HelpParagraph(
                '普通聊天、悬浮聊天和沉浸房间共享主要呈现设置；沉浸房间有独立场景和记忆边界。'
                '两套 Live2D 模型分别保存各自配置，动作、位置和缩放不能互相照搬；语音播放时嘴型与其他表情动作分工处理。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.backup_outlined,
            title: '备份、恢复与设备接管',
            children: [
              _HelpParagraph(
                '完整备份用于迁移本地数据库、设置和受支持媒体。恢复前会预检；恢复、删除和设备接管属于高影响操作，'
                '应先保留可用备份，不要用聊天承诺代替真实恢复结果。API Key 等凭据不随普通备份迁移，换设备后需检查服务配置、系统权限和主设备状态。',
              ),
            ],
          ),
          const _HelpSection(
            icon: Icons.privacy_tip_outlined,
            title: '权限与隐私边界',
            children: [
              _HelpParagraph(
                '读取手机状态只提供当前 App、屏幕/锁屏状态和粗粒度忙碌度。发送图片后可以在聊天里识图。',
              ),
              _HelpParagraph(
                '备份和诊断应作为私密资料提供，不要上传到公开仓库。'
                '系统权限被关闭、网络失败或模型额度不足时，对应能力会如实失败或延后。',
              ),
            ],
          ),
          _ToolSection(
            icon: Icons.hourglass_disabled_outlined,
            title: '尚未开放',
            subtitle: '这些条目只保留为未来能力定义，当前没有可执行入口。App 插件化、Agent 修改自身代码也尚未开放；QQ 动图选帧不代表通用视频理解。',
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
                '诊断报告用于定位权限、工具阶段和失败分类；备份用于核对持久状态。当前完整预检报告按既有授权包含 JEV 判断问题、输入上下文和判定记录，可能带有对话片段，不能把“脱敏”理解为绝无正文。'
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
