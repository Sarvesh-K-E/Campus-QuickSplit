import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/data_provider.dart';
import '../models/expense_group.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_button.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final List<String> _memberNames = [];
  final _memberController = TextEditingController();

  void _addMember() {
    if (_memberController.text.trim().isNotEmpty) {
      setState(() {
        _memberNames.add(_memberController.text.trim());
        _memberController.clear();
      });
    }
  }

  void _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name cannot be empty')));
      return;
    }
    
    if (_memberNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group must have at least one other member (minimum size of 2)')));
      return;
    }

    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final localUser = dataProvider.localUser;
    
    if (localUser == null) return;

    final groupId = const Uuid().v4();
    final group = ExpenseGroup(id: groupId, name: _nameController.text.trim());

    List<String> userIds = [localUser.id];
    for (var name in _memberNames) {
      final id = const Uuid().v4();
      await dataProvider.createUser(name, id);
      userIds.add(id);
    }
    
    await dataProvider.addGroup(group, userIds);
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localUser = Provider.of<DataProvider>(context).localUser;

    return Scaffold(
      appBar: AppBar(title: const Text('New Group')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    decoration: const InputDecoration(
                      labelText: 'Add Member by Name',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white), 
                    onPressed: _addMember
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: ListView(
                  children: [
                    if (localUser != null)
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                          ),
                          child: const Icon(Icons.person),
                        ),
                        title: Text(localUser.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ..._memberNames.asMap().entries.map((entry) {
                      int idx = entry.key;
                      String name = entry.value;
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                          ),
                          child: Center(child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                        ),
                        title: Text(name),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _memberNames.removeAt(idx);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: NeoButton(
                onPressed: _createGroup,
                color: AppTheme.neoGreen,
                child: const Center(child: Text('Create Group')),
              ),
            )
          ],
        ),
      ),
    );
  }
}
