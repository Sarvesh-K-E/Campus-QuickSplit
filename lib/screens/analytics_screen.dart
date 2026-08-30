import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/neo_button.dart';

enum TimeFilter { month, year, lifetime }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  TimeFilter _currentFilter = TimeFilter.month;

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Spend Analytics'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme(themeProvider.themeMode != ThemeMode.dark);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUnifiedAnalyticsCard(context, dataProvider),
            const SizedBox(height: 24),
            if (_currentFilter == TimeFilter.month)
              _buildMonthHeatmap(context, dataProvider).animate().fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
            const SizedBox(height: 24),
            _buildMonthlyTrendChart(context, dataProvider).animate().fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(DateTime date) {
    final nowIST = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final expDate = date.toUtc().add(const Duration(hours: 5, minutes: 30));

    switch (_currentFilter) {
      case TimeFilter.month:
        return expDate.year == nowIST.year && expDate.month == nowIST.month;
      case TimeFilter.year:
        return expDate.year == nowIST.year;
      case TimeFilter.lifetime:
        return true;
    }
  }

  String _getFilterTitle() {
    switch (_currentFilter) {
      case TimeFilter.month:
        return 'MY TOTAL SPENDING (THIS MONTH)';
      case TimeFilter.year:
        return 'MY TOTAL SPENDING (THIS YEAR)';
      case TimeFilter.lifetime:
        return 'MY TOTAL SPENDING (LIFETIME)';
    }
  }

  double _calculateMyTotalSpend(DataProvider dataProvider) {
    double myTotal = 0;
    final localUserId = dataProvider.localUser?.id;
    if (localUserId == null) return 0;

    for (var exp in dataProvider.allExpenses) {
      if (exp.category == 'Payment') continue;
      if (_matchesFilter(exp.date)) {
        for (var split in exp.splitters) {
          if (split.userId == localUserId) {
            myTotal += split.amount;
          }
        }
      }
    }
    return myTotal;
  }

  Widget _buildTimeFilterToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        border: Border.all(color: borderColor, width: 3),
      ),
      child: Row(
        children: [
          _buildFilterButton('Month', TimeFilter.month),
          Container(width: 3, color: borderColor, height: 40),
          _buildFilterButton('Year', TimeFilter.year),
          Container(width: 3, color: borderColor, height: 40),
          _buildFilterButton('Life', TimeFilter.lifetime),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, TimeFilter filter) {
    final isSelected = _currentFilter == filter;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentFilter = filter;
          });
        },
        child: Container(
          height: 40,
          color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isSelected 
                    ? (isDark ? Colors.black : Colors.white) 
                    : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedAnalyticsCard(BuildContext context, DataProvider dataProvider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neoBlue, // Use a vibrant blue for the unified card
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            offset: const Offset(4, 4),
            blurRadius: 0,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildTimeFilterToggle(),
            const SizedBox(height: 24),
            Text(_getFilterTitle(), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            Text(
              '₹ ${_calculateMyTotalSpend(dataProvider).toStringAsFixed(2)}', 
              style: const TextStyle(
                color: Colors.black, 
                fontSize: 40,
                fontWeight: FontWeight.w900,
              )
            ),
            const SizedBox(height: 32),
            const Divider(color: Colors.black, thickness: 3, height: 1),
            const SizedBox(height: 24),
            _buildCategoryPieChart(context, dataProvider),
          ],
        ),
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _buildCategoryPieChart(BuildContext context, DataProvider dataProvider) {
    final expenses = dataProvider.allExpenses;
    final localUserId = dataProvider.localUser?.id;

    if (expenses.isEmpty || localUserId == null) {
      return const Center(child: Text('No expenses recorded yet.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
    }

    final categoryTotals = <String, double>{
      'Food': 0, 'Transport': 0, 'Subs': 0, 'Supplies': 0, 'Other': 0
    };

    double totalAmount = 0;
    
    for (var exp in expenses) {
      if (exp.category == 'Payment') continue;
      if (_matchesFilter(exp.date)) {
        for (var split in exp.splitters) {
          if (split.userId == localUserId) {
            categoryTotals[exp.category] = (categoryTotals[exp.category] ?? 0) + split.amount;
            totalAmount += split.amount;
          }
        }
      }
    }

    if (totalAmount == 0) {
      return const Center(child: Text('No recorded splits for this period.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
    }

    final safeColors = [
      AppTheme.neoOrange,
      AppTheme.neoYellow,
      AppTheme.neoPink,
      AppTheme.neoGreen,
      Colors.white,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.tealAccent,
    ];

    final sortedCategories = categoryTotals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categoryColors = <String, Color>{};
    for (int i = 0; i < sortedCategories.length; i++) {
      categoryColors[sortedCategories[i].key] = safeColors[i % safeColors.length];
    }

    List<PieChartSectionData> sections = [];
    for (var i = 0; i < sortedCategories.length; i++) {
      final category = sortedCategories[i].key;
      final amount = sortedCategories[i].value;
      final percentage = (amount / totalAmount) * 100;
      
      sections.add(
        PieChartSectionData(
          color: categoryColors[category]!,
          value: percentage,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 40,
          borderSide: const BorderSide(color: Colors.black, width: 2),
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
          badgeWidget: null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CATEGORY BREAKDOWN', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 16)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 20,
                    sections: sections,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: sortedCategories.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 16, 
                          height: 16, 
                          decoration: BoxDecoration(
                            color: categoryColors[e.key]!,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${e.key}: ₹${e.value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 13))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlyTrendChart(BuildContext context, DataProvider dataProvider) {
    if (dataProvider.allExpenses.isEmpty) return const SizedBox.shrink();

    final localUserId = dataProvider.localUser?.id;
    if (localUserId == null) return const SizedBox.shrink();

    final nowIST = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final monthlyTotals = <int, double>{}; 
    
    for (int i = 5; i >= 0; i--) {
      final pastDate = DateTime(nowIST.year, nowIST.month - i, 1);
      monthlyTotals[pastDate.month] = 0.0;
    }

    for (var exp in dataProvider.allExpenses) {
      if (exp.category == 'Payment') continue;
      final expDate = exp.date.toUtc().add(const Duration(hours: 5, minutes: 30));
      if (monthlyTotals.containsKey(expDate.month)) {
        if (nowIST.difference(expDate).inDays < 200) {
          double mySplitAmount = 0;
          for (var split in exp.splitters) {
            if (split.userId == localUserId) {
              mySplitAmount += split.amount;
            }
          }
          monthlyTotals[expDate.month] = monthlyTotals[expDate.month]! + mySplitAmount;
        }
      }
    }

    final barGroups = <BarChartGroupData>[];
    int xIndex = 0;
    double maxY = 0;
    
    List<int> monthOrder = [];
    for (int i = 5; i >= 0; i--) {
      monthOrder.add(DateTime(nowIST.year, nowIST.month - i, 1).month);
    }

    for (var month in monthOrder) {
      final amount = monthlyTotals[month] ?? 0.0;
      if (amount > maxY) maxY = amount;
      
      barGroups.add(
        BarChartGroupData(
          x: xIndex,
          barRods: [
            BarChartRodData(
              toY: amount,
              color: AppTheme.neoGreen,
              width: 20,
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 3),
            ),
          ],
        )
      );
      xIndex++;
    }

    maxY = maxY == 0 ? 100 : maxY * 1.2;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            offset: const Offset(4, 4),
            blurRadius: 0,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MY 6-MONTH INSIGHTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 32),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '₹${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value.toInt() >= 0 && value.toInt() < monthOrder.length) {
                            final monthInt = monthOrder[value.toInt()];
                            final date = DateTime(nowIST.year, monthInt, 1);
                            final monthStr = DateFormat('MMM').format(date);
                            return SideTitleWidget(meta: meta, space: 16, child: Text(monthStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)));
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 38,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value == maxY) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              '₹${value.toInt()}',
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                          );
                        }
                      )
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 2, dashArray: [5, 5]),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 100.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut);
  }


  Widget _buildMonthHeatmap(BuildContext context, DataProvider dataProvider) {
    final localUserId = dataProvider.localUser?.id;
    if (localUserId == null) return const SizedBox.shrink();

    final nowIST = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final year = nowIST.year;
    final month = nowIST.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1 = Monday, 7 = Sunday

    // GitHub usually starts on Sunday. So Sunday = 0, Monday = 1 ... Saturday = 6.
    final startingOffset = firstDayWeekday == 7 ? 0 : firstDayWeekday; 

    // Aggregate daily expenses for the current month
    Map<int, double> dailyTotals = {};
    for (int i = 1; i <= daysInMonth; i++) {
      dailyTotals[i] = 0.0;
    }

    for (var exp in dataProvider.allExpenses) {
      if (exp.category == 'Payment') continue;
      final expDate = exp.date.toUtc().add(const Duration(hours: 5, minutes: 30));
      if (expDate.year == year && expDate.month == month) {
        for (var split in exp.splitters) {
          if (split.userId == localUserId) {
            dailyTotals[expDate.day] = dailyTotals[expDate.day]! + split.amount;
          }
        }
      }
    }

    double maxSpend = 0.0;
    for (var val in dailyTotals.values) {
      if (val > maxSpend) maxSpend = val;
    }

    // Build grid cells
    List<Widget> cells = [];
    
    // Add empty cells for offset
    for (int i = 0; i < startingOffset; i++) {
      cells.add(const SizedBox(width: 24, height: 24));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Add days
    for (int day = 1; day <= daysInMonth; day++) {
      final spend = dailyTotals[day]!;
      Color cellColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

      if (spend > 0) {
        final ratio = spend / maxSpend;
        if (ratio < 0.25) {
          cellColor = AppTheme.neoGreen.withOpacity(0.4);
        } else if (ratio < 0.5) {
          cellColor = AppTheme.neoGreen.withOpacity(0.6);
        } else if (ratio < 0.75) {
          cellColor = AppTheme.neoGreen.withOpacity(0.8);
        } else {
          cellColor = AppTheme.neoGreen;
        }
      }

      cells.add(
        Tooltip(
          message: 'Day $day: ₹${spend.toStringAsFixed(0)}',
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: cellColor,
              border: Border.all(color: isDark ? Colors.black : Colors.black87, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
    }

    // Pad end of last week
    final remainingCells = (7 - ((startingOffset + daysInMonth) % 7)) % 7;
    for (int i = 0; i < remainingCells; i++) {
      cells.add(const SizedBox(width: 24, height: 24));
    }

    // Split cells into rows (weeks)
    List<Widget> rows = [];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: cells.sublist(i, i + 7).map((c) => Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: c,
          )).toList(),
        )
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        border: Border.all(color: isDark ? Colors.white : Colors.black, width: 3),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.white : Colors.black,
            offset: const Offset(4, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAILY SPENDING HEATMAP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Text(DateFormat('MMMM yyyy').format(nowIST).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) => Padding(
                    padding: const EdgeInsets.only(right: 4.0, bottom: 8.0),
                    child: SizedBox(
                      width: 24,
                      child: Center(
                        child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      ),
                    ),
                  )).toList(),
                ),
                ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: row,
                )).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less ', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              _buildLegendCell(isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              _buildLegendCell(AppTheme.neoGreen.withOpacity(0.4)),
              _buildLegendCell(AppTheme.neoGreen.withOpacity(0.6)),
              _buildLegendCell(AppTheme.neoGreen.withOpacity(0.8)),
              _buildLegendCell(AppTheme.neoGreen),
              const Text(' More', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendCell(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
