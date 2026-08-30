import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_card.dart';

class ImportGroupScreen extends StatefulWidget {
  final String jsonStr;

  const ImportGroupScreen({super.key, required this.jsonStr});

  @override
  State<ImportGroupScreen> createState() => _ImportGroupScreenState();
}

class _ImportGroupScreenState extends State<ImportGroupScreen> {
  List<dynamic> _members = [];
  String _groupName = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _parseJson();
  }

  void _parseJson() {
    try {
      final data = jsonDecode(widget.jsonStr);
      final group = data['group'] as Map<String, dynamic>;
      _groupName = group['name'] as String;
      _members = data['members'] as List<dynamic>;
    } catch (e) {
      // Invalid JSON
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid group file format')));
        context.pop();
      });
    }
  }

  Future<void> _importAsUser(String mappedUserId) async {
    setState(() => _isLoading = true);
    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      await dataProvider.importGroup(widget.jsonStr, mappedUserId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Group "$_groupName" imported successfully!')));
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_members.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Group', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.neoPink))
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeoCard(
                  color: AppTheme.neoBlue,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Who are you in:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(_groupName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.black)),
                        const SizedBox(height: 16),
                        const Text('Select your name from the list below to map your identity to this imported group.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index] as Map<String, dynamic>;
                      return NeoCard(
                        color: AppTheme.neoYellow,
                        onTap: () => _importAsUser(member['id']),
                        child: ListTile(
                          title: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                          trailing: const Icon(Icons.download, color: Colors.black),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
