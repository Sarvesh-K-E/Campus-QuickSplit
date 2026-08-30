import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/neo_card.dart';
import '../theme/app_theme.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Receive Group',
            onPressed: () {
              context.push('/p2p_receive');
            },
          ),
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme(themeProvider.themeMode != ThemeMode.dark);
            },
          ),
        ],
      ),
      body: dataProvider.groups.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 64.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No groups yet. Tap + to create one!', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: dataProvider.groups.length,
              itemBuilder: (context, index) {
                final group = dataProvider.groups[index];
                return Slidable(
                  key: ValueKey(group.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) async {
                          final groupToCache = group;
                          final expensesToCache = dataProvider.allExpenses.where((e) => e.groupId == group.id).toList();
                          
                          await dataProvider.deleteGroup(group.id, groupName: group.name);
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Group deleted'),
                              duration: const Duration(seconds: 5),
                              action: SnackBarAction(
                                label: 'UNDO',
                                onPressed: () {
                                  dataProvider.undoGroupDeletion(groupToCache, expensesToCache);
                                },
                              ),
                            ));
                          }
                        },
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Delete',
                      ),
                    ],
                  ),
                  child: NeoCard(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onTap: () {
                      context.push('/groups/${group.id}');
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.15),
                          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                        ),
                        child: Center(child: Text(group.name[0].toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 20))),
                      ),
                      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text('${group.members.length} members', style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                    ),
                  ),
                ).animate(delay: (index * 50).ms).fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/groups/create'),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('New Group', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
    );
  }
}
