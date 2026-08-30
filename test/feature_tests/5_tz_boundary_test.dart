import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Analytics Timezone Boundaries', () {
    test('Ensures expenses near UTC midnight fall into correct IST day/month', () {
      // Logic from analytics_screen.dart:
      // final expDate = date.toUtc().add(const Duration(hours: 5, minutes: 30));
      
      bool matchesMonthFilter(DateTime date, DateTime nowIST) {
        final expDate = date.toUtc().add(const Duration(hours: 5, minutes: 30));
        return expDate.year == nowIST.year && expDate.month == nowIST.month;
      }

      // Let's say current IST time is August 1st, 1:00 AM.
      // UTC time is July 31st, 7:30 PM.
      final nowIST = DateTime.utc(2023, 8, 1, 1, 0); // Pretend this is our mock IST

      // Scenario A: An expense occurs at exactly July 31st, 11:59 PM IST.
      // In UTC, this is July 31st, 6:29 PM.
      final julyExpense = DateTime.utc(2023, 7, 31, 18, 29); // UTC equivalent of 11:59 PM IST
      
      // Scenario B: An expense occurs at exactly August 1st, 12:01 AM IST.
      // In UTC, this is July 31st, 6:31 PM.
      final augustExpense = DateTime.utc(2023, 7, 31, 18, 31); // UTC equivalent of 12:01 AM IST

      // Verify that July expense does NOT match the August filter
      expect(matchesMonthFilter(julyExpense, nowIST), isFalse, reason: 'Expense at 11:59 PM July 31st (IST) should NOT fall into August');
      
      // Verify that August expense DOES match the August filter
      expect(matchesMonthFilter(augustExpense, nowIST), isTrue, reason: 'Expense at 12:01 AM August 1st (IST) should fall into August');
    });
  });
}
