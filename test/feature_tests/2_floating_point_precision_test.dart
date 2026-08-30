import 'package:flutter_test/flutter_test.dart';
import 'package:campus_quicksplit/services/settlement_service.dart';

void main() {
  group('Floating Point Precision Integrity', () {
    test('Correctly ignores negligible floating point drift during settlement', () {
      // Scenario: A group of 3 people split a ₹100 bill, resulting in infinite fractions.
      // After several complex transactions, their math drifts by a microscopic amount.
      
      final balances = {
        'A': -33.333333333333,
        'B': -33.333333333333,
        'C': 66.666666666666,
        'D': 0.0000000000001, // microscopic ghost debt
      };

      final transactions = SettlementService.simplifyDebts(balances);

      // The algorithm should realize D's debt is under the 0.01 threshold and ignore it entirely.
      // It should only settle A -> C and B -> C.
      expect(transactions.length, 2, reason: 'Should ignore micro-debts below 0.01');
      
      // Let's verify exactly how much is settled.
      final txA = transactions.firstWhere((t) => t.from == 'A');
      final txB = transactions.firstWhere((t) => t.from == 'B');
      
      expect(txA.to, 'C');
      expect(txB.to, 'C');
      
      // The amount should exactly match the min of the debtor/creditor at that phase.
      // Since C has 66.666..., A pays 33.333... and C is reduced.
      expect((txA.amount - 33.333333333333).abs() < 0.000001, isTrue);
    });
  });
}
