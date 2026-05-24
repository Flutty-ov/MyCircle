import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'log_service.dart';

class AppLogsPage extends StatefulWidget {
  const AppLogsPage({super.key});

  @override
  State<AppLogsPage> createState() => _AppLogsPageState();
}

class _AppLogsPageState extends State<AppLogsPage> {
  bool _copied = false;
  String _filter = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    LogService.instance.logStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copyLogs() async {
    final logs = LogService.instance.logs;
    final filtered = _filter.isEmpty
        ? logs
        : logs
            .where((e) =>
                e.toString().toLowerCase().contains(_filter.toLowerCase()))
            .toList();
    final text = filtered.isEmpty
        ? 'Нет логов'
        : filtered.map((e) => e.toString()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = LogService.instance.logs;
    final filtered = _filter.isEmpty
        ? logs
        : logs
            .where((e) =>
                e.toString().toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Логи приложения'),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                LogService.instance.clear();
                setState(() {});
              },
              tooltip: 'Очистить',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Фильтр логов...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _filter = value;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} записей',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _scrollToBottom,
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  label: const Text('Вниз'),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _filter.isEmpty
                          ? 'Логи пока пусты'
                          : 'Ничего не найдено',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final isLast = index == filtered.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: isLast ? 0 : 4,
                        ),
                        child: SelectableText(
                          entry.toString(),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _copyLogs,
                icon: Icon(_copied ? Icons.check : Icons.copy),
                label: Text(_copied ? 'Скопировано!' : 'Скопировать'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
