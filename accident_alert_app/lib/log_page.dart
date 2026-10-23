import 'package:flutter/material.dart';
import 'log_store.dart';

class LogPage extends StatefulWidget {
  final bool isDarkMode;

  const LogPage({super.key, required this.isDarkMode});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final allLogs = AccidentLogStore.logs.reversed.toList();
    final reversed = _filter == 'All' ? allLogs : allLogs.where((e) => e.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Accident Logs'),
        actions: reversed.isEmpty
            ? null
            : [
                IconButton(
                  tooltip: 'Clear all',
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await AccidentLogStore.clear();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🗑  All logs cleared')),
                    );
                  },
                ),
              ],
      ),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Row(children: ['All', 'Accident', 'Near Miss', 'Normal'].map((f) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)))).toList())),
        Expanded(child: reversed.isEmpty
          ? Center(child: Text(allLogs.isEmpty ? 'No accident logs recorded yet.' : 'No matching logs.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              itemCount: reversed.length,
              itemBuilder: (context, index) => Card(
                color: Theme.of(context).cardColor,
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    reversed[index],
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            )),
      ]),
    );
  }
}
