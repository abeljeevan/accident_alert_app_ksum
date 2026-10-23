import 'package:flutter/material.dart';
import 'contact_store.dart';

class ManageContactsPage extends StatefulWidget {
  final bool isDarkMode;

  const ManageContactsPage({super.key, required this.isDarkMode});

  @override
  State<ManageContactsPage> createState() => _ManageContactsPageState();
}

class _ManageContactsPageState extends State<ManageContactsPage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() { _controller.dispose(); _search.dispose(); super.dispose(); }

  void _addContact() async {
    final number = _controller.text.trim();
    if (number.isEmpty) return;

    await EmergencyContactsStore.add(number);
    _controller.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Contact $number added')),
    );
  }

  void _removeContact(String number) async {
    await EmergencyContactsStore.remove(number);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Contact $number removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = EmergencyContactsStore.contacts.where((n) => n.toLowerCase().contains(_search.text.trim().toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts'), actions: [IconButton(tooltip: 'Contact options', onPressed: () {}, icon: const Icon(Icons.person_outline_rounded)), IconButton(tooltip: 'Add contact', onPressed: _addContact, icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFFF3347)))]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addContact,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search contacts...')),
            const SizedBox(height: 12),
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts added yet.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final number = contacts[index];
                        return Card(
                          color: Theme.of(context).cardColor,
                          child: ListTile(
                            title: Text(
                              number,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text('Emergency contact'),
                            leading: CircleAvatar(backgroundColor: const Color(0xFFFF3347).withValues(alpha: .12), foregroundColor: const Color(0xFFFF3347), child: Text(number.isEmpty ? '?' : number.substring(0, 1))),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(tooltip: 'Call contact', icon: const Icon(Icons.call_rounded, color: Color(0xFFFF3347)), onPressed: () {}),
                              IconButton(
                              tooltip: 'Remove contact', icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3347)),
                              onPressed: () => _removeContact(number),
                            )]),
                          ),
                        );
                      },
                    ),
            ),
            if (contacts.isNotEmpty)
              ElevatedButton(
                onPressed: () async {
                  await EmergencyContactsStore.clear();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ All contacts cleared')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                ),
                child: const Text('Clear All Contacts'),
              ),
          ],
        ),
      ),
    );
  }
}
