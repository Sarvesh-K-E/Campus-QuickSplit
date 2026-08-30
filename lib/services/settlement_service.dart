import '../models/expense_group.dart';
import '../models/expense.dart';

class SettlementService {
  static Map<String, double> calculateBalances(ExpenseGroup group, List<Expense> expenses) {
    Map<String, double> balances = {};
    for (var member in group.members) {
      balances[member.id] = 0.0;
    }

    for (var expense in expenses) {
      for (var payer in expense.payers) {
        balances[payer.userId] = (balances[payer.userId] ?? 0.0) + payer.amount;
      }
      for (var split in expense.splitters) {
        balances[split.userId] = (balances[split.userId] ?? 0.0) - split.amount;
      }
    }
    return balances;
  }

  static List<Transaction> getUnoptimizedDebts(ExpenseGroup group, List<Expense> expenses) {
    Map<String, Map<String, double>> debts = {};

    for (var expense in expenses) {
      double totalPaid = expense.payers.fold(0.0, (sum, p) => sum + p.amount);
      if (totalPaid <= 0) continue;

      for (var splitter in expense.splitters) {
        if (splitter.amount <= 0) continue;
        
        for (var payer in expense.payers) {
          if (payer.amount <= 0) continue;
          
          // Splitter owes this payer proportionally based on payer's contribution to total
          double proportion = payer.amount / totalPaid;
          double owesToPayer = splitter.amount * proportion;
          
          if (owesToPayer > 0) {
            debts.putIfAbsent(splitter.userId, () => {});
            debts[splitter.userId]![payer.userId] = (debts[splitter.userId]![payer.userId] ?? 0.0) + owesToPayer;
          }
        }
      }
    }

    // Simplify direct mutual debts (A owes B 10, B owes A 6 -> A owes B 4)
    List<Transaction> unoptimized = [];
    Set<String> processedPairs = {};

    debts.forEach((fromUser, toMap) {
      toMap.forEach((toUser, amount) {
        if (fromUser == toUser) return; // ignore self debts
        
        String pairKey = fromUser.compareTo(toUser) < 0 ? '${fromUser}_$toUser' : '${toUser}_$fromUser';
            
        if (processedPairs.contains(pairKey)) return;
        processedPairs.add(pairKey);

        double fromToTo = amount;
        double toToFrom = debts[toUser]?[fromUser] ?? 0.0;

        if (fromToTo > toToFrom) {
          double net = fromToTo - toToFrom;
          if (net > 0.01) {
            unoptimized.add(Transaction(from: fromUser, to: toUser, amount: net));
          }
        } else if (toToFrom > fromToTo) {
          double net = toToFrom - fromToTo;
          if (net > 0.01) {
            unoptimized.add(Transaction(from: toUser, to: fromUser, amount: net));
          }
        }
      });
    });

    return unoptimized;
  }

  static List<Transaction> simplifyDebts(Map<String, double> balances) {
    List<Transaction> transactions = [];
    
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    balances.forEach((userId, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(userId, balance.abs()));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(userId, balance));
      }
    });

    // Phase 1: Exact Matches
    // Find perfect 1-to-1 matches to guarantee optimal pairing before splitting
    bool matchFound = true;
    while (matchFound) {
      matchFound = false;
      for (int i = 0; i < debtors.length; i++) {
        for (int j = 0; j < creditors.length; j++) {
          if ((debtors[i].value - creditors[j].value).abs() < 0.01) {
            transactions.add(Transaction(
              from: debtors[i].key,
              to: creditors[j].key,
              amount: debtors[i].value,
            ));
            debtors.removeAt(i);
            creditors.removeAt(j);
            matchFound = true;
            break;
          }
        }
        if (matchFound) break;
      }
    }

    // Phase 2: True Dynamic Greedy Matching
    // Matches the absolute largest debtor to the absolute largest creditor and re-sorts dynamically
    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      debtors.sort((a, b) => b.value.compareTo(a.value));
      creditors.sort((a, b) => b.value.compareTo(a.value));

      var debtor = debtors.first;
      var creditor = creditors.first;

      double minAmount = debtor.value < creditor.value ? debtor.value : creditor.value;

      transactions.add(Transaction(
        from: debtor.key,
        to: creditor.key,
        amount: minAmount,
      ));

      double remDebt = debtor.value - minAmount;
      double remCredit = creditor.value - minAmount;

      debtors.removeAt(0);
      creditors.removeAt(0);

      if (remDebt > 0.01) {
        debtors.add(MapEntry(debtor.key, remDebt));
      }
      if (remCredit > 0.01) {
        creditors.add(MapEntry(creditor.key, remCredit));
      }
    }

    return transactions;
  }
}

class Transaction {
  final String from;
  final String to;
  final double amount;

  Transaction({required this.from, required this.to, required this.amount});
}
