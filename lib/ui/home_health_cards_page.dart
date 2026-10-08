import 'package:flutter/material.dart';

import '../domain/home_health_cards.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import 'app_theme.dart';

class HomeHealthCardsPage extends StatefulWidget {
  const HomeHealthCardsPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<HomeHealthCardsPage> createState() => _HomeHealthCardsPageState();
}

class _HomeHealthCardsPageState extends State<HomeHealthCardsPage> {
  late HomeHealthCardLayout _draft;
  late String _owner;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.homeHealthCardLayout;
    _owner = widget.controller.homeHealthCardOwner;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.controller.saveHomeHealthCards(
      _draft,
      expectedOwner: _owner,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = '设置未保存，请返回后重试';
      });
    }
  }

  Widget _tile(
    HealthMetric metric, {
    required bool shown,
    int? index,
  }) => Container(
    key: ValueKey('edit-home-card-${metric.wireName}'),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SaydianColors.line),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: IconButton(
        key: ValueKey(
          '${shown ? 'hide' : 'show'}-home-card-${metric.wireName}',
        ),
        tooltip: '${shown ? '隐藏' : '显示'}${metric.label}',
        onPressed: _saving || _owner != widget.controller.homeHealthCardOwner
            ? null
            : () => setState(() {
                _draft = _draft.setVisible(metric, !shown);
              }),
        icon: Icon(shown ? Icons.remove_circle : Icons.add_circle),
        color: shown ? SaydianColors.muted : SaydianColors.blue,
      ),
      title: Text(
        metric.label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: shown && index != null
          ? ReorderableDelayedDragStartListener(
              index: index,
              enabled:
                  !_saving && _owner == widget.controller.homeHealthCardOwner,
              child: Semantics(
                label: '长按拖动${metric.label}调整顺序',
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: SaydianColors.muted,
                  ),
                ),
              ),
            )
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final eligible = _draft.order
          .where(widget.controller.shouldShowHealthMetric)
          .toList();
      final shown = eligible
          .where((metric) => !_draft.hidden.contains(metric))
          .toList();
      final hidden = eligible.where(_draft.hidden.contains).toList();
      final accountChanged = _owner != widget.controller.homeHealthCardOwner;
      return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('编辑卡片'),
            actions: [
              IconButton(
                key: const Key('save-home-health-cards'),
                tooltip: '保存',
                onPressed: _saving || accountChanged ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            children: [
              if (_error != null || accountChanged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(accountChanged ? '账号已切换，请返回后重新编辑' : _error!),
                ),
              const Text(
                '已显示',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Text('暂无首页卡片，可从下方添加'),
                ),
              ReorderableListView.builder(
                key: const Key('home-health-cards-reorder'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: shown.length,
                itemBuilder: (_, index) =>
                    _tile(shown[index], shown: true, index: index),
                onReorderItem: (oldIndex, newIndex) {
                  if (_saving || accountChanged) return;
                  final reordered = shown.toList();
                  reordered.insert(newIndex, reordered.removeAt(oldIndex));
                  setState(() => _draft = _draft.reorderVisible(reordered));
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '未显示',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              for (final metric in hidden) _tile(metric, shown: false),
              if (eligible.isEmpty) const Text('连接戒指并完成能力读取后，可编辑支持的健康卡片'),
              if (eligible.isNotEmpty && hidden.isEmpty)
                const Text('所有可用卡片均已显示'),
              const SizedBox(height: 36),
              const Text(
                '长按并拖拽右侧手柄调整顺序\n只影响首页展示，不会删除健康数据',
                textAlign: TextAlign.center,
                style: TextStyle(color: SaydianColors.muted, height: 1.7),
              ),
            ],
          ),
        ),
      );
    },
  );
}
