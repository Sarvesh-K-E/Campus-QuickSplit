import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../providers/data_provider.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_button.dart';
import '../services/database_service.dart';

class EditGroupScreen extends StatefulWidget {
  final String groupId;

  const EditGroupScreen({super.key, required this.groupId});

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final _nameController = TextEditingController();
  final _memberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final group = Provider.of<DataProvider>(context, listen: false).groups.firstWhere((g) => g.id == widget.groupId);
    _nameController.text = group.name;
  }

  void _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name cannot be empty')));
      return;
    }
    await Provider.of<DataProvider>(context, listen: false).updateGroupName(widget.groupId, newName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name updated')));
    }
  }

  void _addMember() async {
    final name = _memberController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member name cannot be empty')));
      return;
    }
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final id = const Uuid().v4();
    await dataProvider.createUser(name, id);
    
    final newUser = dataProvider.allUsers.firstWhere((u) => u.id == id);
    await dataProvider.addMemberToGroup(widget.groupId, newUser);
    
    _memberController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added')));
    }
  }

  void _removeMember(String userId) async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    
    // VALIDATION: Check if user is involved in any active expenses in this group
    final expenses = await DatabaseService.instance.getExpensesByGroup(widget.groupId);
    bool isInvolved = false;
    for (var exp in expenses) {
      bool isPayer = exp.payers.any((p) => p.userId == userId);
      bool isSplitter = exp.splitters.any((s) => s.userId == userId);
      if (isPayer || isSplitter) {
        isInvolved = true;
        break;
      }
    }

    if (isInvolved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove member. They are involved in an active expense. Delete the expense first.'),
          backgroundColor: Colors.redAccent,
        )
      );
      return;
    }

    await dataProvider.removeMemberFromGroup(widget.groupId, userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed')));
    }
  }


  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final group = dataProvider.groups.firstWhere((g) => g.id == widget.groupId);
    final localUser = dataProvider.localUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Group')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                NeoButton(
                  onPressed: _updateName,
                  color: AppTheme.neoGreen,
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    decoration: const InputDecoration(
                      labelText: 'Add New Member',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                NeoButton(
                  onPressed: _addMember,
                  color: AppTheme.neoBlue,
                  child: const Icon(Icons.person_add),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: group.members.length,
                  itemBuilder: (context, index) {
                    final member = group.members[index];
                    final isLocalUser = member.id == localUser?.id;
                    
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isLocalUser ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                        ),
                        child: Center(child: isLocalUser ? const Icon(Icons.person) : Text(member.name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                      ),
                      title: Text(member.name, style: TextStyle(fontWeight: isLocalUser ? FontWeight.bold : FontWeight.normal)),
                      trailing: isLocalUser ? null : IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () => _removeMember(member.id),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
