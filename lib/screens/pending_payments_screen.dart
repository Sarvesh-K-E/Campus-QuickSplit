import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/neo_card.dart';
import '../theme/app_theme.dart';

class PendingPaymentsScreen extends StatelessWidget {
  const PendingPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final pendingOut = dataProvider.getPendingOutgoingSettlements();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Payments', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: NeoCard(
              color: dataProvider.notificationsEnabled ? AppTheme.neoBlue : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
              margin: EdgeInsets.zero,
              child: CheckboxListTile(
                activeColor: AppTheme.neoPink,
                checkColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  'Daily Reminders', 
                  style: TextStyle(fontWeight: FontWeight.w900, color: dataProvider.notificationsEnabled ? Colors.black : null)
                ),
                subtitle: Text(
                  'Get notified daily if you have pending payments to settle.', 
                  style: TextStyle(fontWeight: FontWeight.w700, color: dataProvider.notificationsEnabled ? Colors.black87 : null)
                ),
                value: dataProvider.notificationsEnabled,
                side: BorderSide(
                  color: dataProvider.notificationsEnabled ? Colors.black : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black), 
                  width: 2
                ),
                onChanged: (value) {
                  dataProvider.toggleNotifications(value ?? false);
                },
              ),
            ),
          ),
          Expanded(
            child: pendingOut.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 80, color: AppTheme.neoGreen),
                        const SizedBox(height: 16),
                        const Text(
                          'You are all settled up! 🎉', 
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                        ),
                      ],
                    )
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: pendingOut.length,
                    itemBuilder: (context, index) {
                      final item = pendingOut[index];
                      final groupName = item['groupName'] as String;
                      final groupId = item['groupId'] as String;
                      final receiverName = item['receiverName'] as String;
                      final amount = item['amount'] as double;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: NeoCard(
                          color: AppTheme.neoPink,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            title: Text('You owe $receiverName', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                            subtitle: Text('In group: $groupName', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                                Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black)),
                              ],
                            ),
                            onTap: () {
                              context.push('/groups/$groupId');
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
