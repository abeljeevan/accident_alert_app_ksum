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
    final contacts = EmergencyContactsStore.contacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter phone number',
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: widget.isDarkMode
                          ? const Color(0xFF2C2C2C) // dark mode
                          : const Color(0xFF194276), // dark blue light mode
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
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts added yet.',
                        style: TextStyle(
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final number = contacts[index];
                        return Card(
                          color: widget.isDarkMode
                              ? const Color(0xFF2C2C2C)
                              : const Color(0xFF194276),
                          child: ListTile(
                            title: Text(
                              number,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Color.fromARGB(255, 160, 15, 4)),
                              onPressed: () => _removeContact(number),
                            ),
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
