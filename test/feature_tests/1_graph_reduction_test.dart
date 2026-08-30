import 'package:flutter_test/flutter_test.dart';
import 'package:campus_quicksplit/services/settlement_service.dart';

void main() {
  group('Advanced Graph Reduction (simplifyDebts)', () {
    test('Breaks a 5-way cyclic debt chain into optimal transactions', () {
      // Scenario:
      // A owes B 100
      // B owes C 150
      // C owes D 200
      // D owes E 250
      // E owes A 300
      
      // Net balances:
      // A: -100 (owes B) + 300 (E owes A) = +200
      // B: +100 (A owes B) - 150 (owes C) = -50
      // C: +150 (B owes C) - 200 (owes D) = -50
      // D: +200 (C owes D) - 250 (owes E) = -50
      // E: +250 (D owes E) - 300 (owes A) = -50
      
      final balances = {
        'A': 200.0,
        'B': -50.0,
        'C': -50.0,
        'D': -50.0,
        'E': -50.0,
      };

      // Since B, C, D, E all owe exactly 50, and A is owed exactly 200, 
      // the optimal settlement graph is exactly 4 transactions:
      // B->A (50), C->A (50), D->A (50), E->A (50)
      
      final transactions = SettlementService.simplifyDebts(balances);

      expect(transactions.length, 4, reason: 'Should take exactly 4 transactions to settle 4 debtors and 1 creditor');
      
      double totalSettled = 0.0;
      for (var tx in transactions) {
        expect(tx.to, 'A', reason: 'Every transaction should go to the sole creditor A');
        expect(tx.amount, 50.0, reason: 'Each debtor owes exactly 50');
        totalSettled += tx.amount;
      }
      
      expect(totalSettled, 200.0, reason: 'Total settled amount must equal total debt');
    });
  });
}
