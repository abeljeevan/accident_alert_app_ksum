import 'package:flutter/material.dart';
import 'log_store.dart';

class LogPage extends StatefulWidget {
  final bool isDarkMode;

  const LogPage({super.key, required this.isDarkMode});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  @override
  Widget build(BuildContext context) {
    final reversed = AccidentLogStore.logs.reversed.toList();

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
      body: reversed.isEmpty
          ? Center(
              child: Text(
                'No accident logs recorded yet.',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.white,
                ),
              ),
            )
          : ListView.builder(
              itemCount: reversed.length,
              itemBuilder: (context, index) => Card(
                color: widget.isDarkMode
                    ? const Color(0xFF2C2C2C) // dark mode
                    : const Color(0xFF194276), // dark blue for light mode
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    reversed[index],
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
