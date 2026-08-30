import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_action.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  DateTimeRange? _dateRange;
  String _selectedType = 'All';

  final Map<String, String> _typeFilters = {
    'All': 'All Activities',
    'expense_added': 'Expense Added',
    'expense_edited': 'Expense Edited',
    'expense_deleted': 'Expense Deleted',
    'expense_restored': 'Expense Restored',
    'payment_recorded': 'Payment Recorded',
    'payment_edited': 'Payment Edited',
    'payment_deleted': 'Payment Deleted',
    'group_created': 'Group Created',
    'group_edited': 'Group Edited',
    'group_deleted': 'Group Deleted',
    'group_restored': 'Group Restored',
  };

  Future<void> _exportCsv(List<AppAction> actions) async {
    try {
      String csv = "Date,Time,Action Type,Title,Description\n";
      for (var action in actions) {
        final istDate = action.timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
        final dateStr = DateFormat('dd MMM yyyy').format(istDate);
        final timeStr = DateFormat('hh:mm a').format(istDate);
        
        // Escape quotes to prevent CSV breakage and replace ₹ with Rs. for CSV compatibility
        final title = action.title.replaceAll('"', '""').replaceAll('₹', 'Rs. ');
        final subtitle = action.subtitle.replaceAll('"', '""').replaceAll('₹', 'Rs. ');
        
        csv += '"$dateStr","$timeStr","${_typeFilters[action.actionType] ?? action.actionType}","$title","$subtitle"\n';
      }

      final dir = await getTemporaryDirectory();
      final nowIST = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final filename = 'ActivityLog_${DateFormat('yyyyMMdd_HHmmss').format(nowIST)}_IST.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)], 
          text: 'Campus QuickSplit Activity Log',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Filter logic
    List<AppAction> filteredActions = dataProvider.activityLogs.where((action) {
      bool matchesType = _selectedType == 'All' || action.actionType == _selectedType;
      
      bool matchesDate = true;
      if (_dateRange != null) {
        final istDate = action.timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
        // Reset times for accurate day comparison
        final actionDay = DateTime(istDate.year, istDate.month, istDate.day);
        final startDay = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final endDay = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        
        matchesDate = actionDay.isAtSameMomentAs(startDay) || 
                      actionDay.isAtSameMomentAs(endDay) || 
                      (actionDay.isAfter(startDay) && actionDay.isBefore(endDay));
      }
      
      return matchesType && matchesDate;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export as CSV',
            onPressed: () => _exportCsv(filteredActions),
          ),
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme(themeProvider.themeMode != ThemeMode.dark);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: _dateRange,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme.copyWith(
                                primary: Theme.of(context).primaryColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (range != null) {
                        setState(() => _dateRange = range);
                      }
                    },
                    borderRadius: BorderRadius.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.date_range, size: 16, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _dateRange == null 
                                  ? 'Any Date' 
                                  : '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_dateRange != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _dateRange = null),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.grey),
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        width: 2,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        items: _typeFilters.entries.map((e) {
                          return DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: filteredActions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No activity matches your filters.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100, top: 8),
                    itemCount: filteredActions.length,
                    itemBuilder: (context, index) {
                      final action = filteredActions[index];
                      final istDate = action.timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
                      
                      IconData getIconForAction(String type) {
                        switch (type) {
                          case 'group_created': return Icons.group_add;
                          case 'group_edited': return Icons.edit;
                          case 'group_deleted': return Icons.group_remove;
                          case 'group_restored': return Icons.group;
                          case 'expense_added': return Icons.add_circle;
                          case 'expense_edited': return Icons.edit_document;
                          case 'expense_deleted': return Icons.delete;
                          case 'expense_restored': return Icons.restore;
                          case 'payment_recorded': return Icons.payment;
                          case 'payment_edited': return Icons.edit_note;
                          case 'payment_deleted': return Icons.money_off;
                          default: return Icons.local_activity;
                        }
                      }
                      
                      Color getColorForAction(String type) {
                        switch (type) {
                          case 'expense_deleted': return AppTheme.neoRed;
                          case 'group_deleted': return AppTheme.neoRed;
                          case 'payment_deleted': return AppTheme.neoRed;
                          case 'expense_added': return AppTheme.neoGreen;
                          case 'payment_recorded': return AppTheme.neoGreen;
                          case 'expense_edited': return AppTheme.neoYellow;
                          case 'payment_edited': return AppTheme.neoYellow;
                          case 'group_edited': return AppTheme.neoYellow;
                          case 'expense_restored': return AppTheme.neoBlue;
                          case 'group_restored': return AppTheme.neoBlue;
                          case 'group_created': return AppTheme.neoPink;
                          default: return AppTheme.neoOrange;
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: getColorForAction(action.actionType),
                              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                            ),
                            child: Center(child: Icon(getIconForAction(action.actionType), color: Colors.black)),
                          ),
                          title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(action.subtitle, style: TextStyle(color: getColorForAction(action.actionType), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(DateFormat('dd MMM yyyy, hh:mm a').format(istDate), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                        ),
                      ).animate(delay: (index * 50).ms).fade(duration: 400.ms).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOut);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
