import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../services/settlement_service.dart';
import '../services/auth_service.dart';
import '../models/settlement_report_model.dart';
import 'payment_screen.dart';

class SettlementDetailScreen extends StatefulWidget {
  final SettlementReportModel report;

  const SettlementDetailScreen({super.key, required this.report});

  @override
  State<SettlementDetailScreen> createState() => _SettlementDetailScreenState();
}

class _SettlementDetailScreenState extends State<SettlementDetailScreen> {
  late SettlementReportModel _report;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  Future<void> _finalizeReport() async {
    final shouldFinalize = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize Report'),
        content: const Text(
          'Once finalized, the report cannot be edited. Members will be notified of their dues. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );

    if (shouldFinalize != true) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final settlementService = Provider.of<SettlementService>(context, listen: false);

    final success = await settlementService.finalizeReport(
      authService.userModel!.currentMealSystemId!,
      _report.reportId,
    );

    if (mounted) {
      if (success) {
        // Reload the updated report
        await settlementService.loadSettlementReports(
          authService.userModel!.currentMealSystemId!,
        );
        
        final updatedReport = settlementService.reports.firstWhere(
          (r) => r.reportId == _report.reportId,
          orElse: () => _report,
        );
        
        setState(() {
          _report = updatedReport;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report finalized successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _viewSettlementTransactions() {
    final settlementService = Provider.of<SettlementService>(context, listen: false);
    final transactions = settlementService.calculateSettlementTransactions(_report);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SettlementTransactionsSheet(
        transactions: transactions,
      ),
    );
  }

  void _makePayment(MemberSettlement settlement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          report: _report,
          settlement: settlement,
        ),
      ),
    ).then((_) {
      // Reload report after payment
      final authService = Provider.of<AuthService>(context, listen: false);
      final settlementService = Provider.of<SettlementService>(context, listen: false);
      settlementService.loadSettlementReports(
        authService.userModel!.currentMealSystemId!,
      ).then((_) {
        final updatedReport = settlementService.reports.firstWhere(
          (r) => r.reportId == _report.reportId,
          orElse: () => _report,
        );
        setState(() {
          _report = updatedReport;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final settlementService = Provider.of<SettlementService>(context);
    final monthName = DateFormat('MMMM yyyy').format(_report.month);
    final myUserId = authService.userModel?.userId;
    final mySettlement = myUserId != null ? _report.memberSettlements[myUserId] : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Settlement - $monthName'),
        actions: [
          if (!_report.isFinalized && !_report.isFullyPaid)
            IconButton(
              icon: const Icon(Icons.check_circle),
              tooltip: 'Finalize Report',
              onPressed: _finalizeReport,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '${_report.totalExpenses.toStringAsFixed(2)} BDT',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Total Expenses',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryItem(
                            icon: Icons.restaurant,
                            value: '${_report.totalMeals}',
                            label: 'Total Meals',
                            color: Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _SummaryItem(
                            icon: Icons.attach_money,
                            value: '${_report.costPerMeal.toStringAsFixed(1)}',
                            label: 'Per Meal',
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // My Settlement (if applicable)
            if (mySettlement != null) ...[
              Card(
                elevation: 3,
                color: mySettlement.owes ? Colors.red[50] : Colors.green[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            mySettlement.owes ? Icons.payment : Icons.account_balance_wallet,
                            color: mySettlement.owes ? Colors.red : Colors.green,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              mySettlement.owes ? 'You Owe' : mySettlement.shouldReceive ? 'You Receive' : 'Balanced',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: mySettlement.owes ? Colors.red[900] : Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${mySettlement.absoluteBalance.toStringAsFixed(2)} BDT',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: mySettlement.owes ? Colors.red[800] : Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Meals eaten: ${mySettlement.mealsEaten} | Paid: ${mySettlement.totalPaid.toStringAsFixed(0)} BDT',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (mySettlement.owes && _report.isFinalized) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _makePayment(mySettlement),
                          icon: const Icon(Icons.payment),
                          label: const Text('Make Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Settlement Transactions Button
            if (_report.isFinalized) ...[
              OutlinedButton.icon(
                onPressed: _viewSettlementTransactions,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('View Settlement Transactions'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Category Breakdown
            if (_report.categoryBreakdown.isNotEmpty) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expense Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._report.categoryBreakdown.entries.map((entry) {
                        final percentage = (_report.totalExpenses > 0
                            ? (entry.value / _report.totalExpenses) * 100
                            : 0).toStringAsFixed(1);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CategoryBar(
                            category: entry.key,
                            amount: entry.value,
                            percentage: double.parse(percentage),
                            total: _report.totalExpenses,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Members Who Owe
            if (_report.membersWhoOwe.isNotEmpty) ...[
              const Text(
                'Members Who Owe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._report.membersWhoOwe.map((settlement) {
                return _MemberSettlementCard(
                  settlement: settlement,
                  status: 'owes',
                  onPayment: _report.isFinalized ? () => _makePayment(settlement) : null,
                  isMe: settlement.userId == myUserId,
                );
              }),
              const SizedBox(height: 16),
            ],

            // Members To Receive
            if (_report.membersToReceive.isNotEmpty) ...[
              const Text(
                'Members To Receive',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._report.membersToReceive.map((settlement) {
                return _MemberSettlementCard(
                  settlement: settlement,
                  status: 'receive',
                  isMe: settlement.userId == myUserId,
                );
              }),
              const SizedBox(height: 16),
            ],

            // Balanced Members
            if (_report.balancedMembers.isNotEmpty) ...[
              const Text(
                'Balanced Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._report.balancedMembers.map((settlement) {
                return _MemberSettlementCard(
                  settlement: settlement,
                  status: 'balanced',
                  isMe: settlement.userId == myUserId,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String category;
  final double amount;
  final double percentage;
  final double total;

  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.total,
  });

  Color _getCategoryColor() {
    final random = math.Random(category.hashCode);
    return Color.fromRGBO(
      random.nextInt(200) + 55,
      random.nextInt(200) + 55,
      random.nextInt(200) + 55,
      1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${amount.toStringAsFixed(0)} BDT ($percentage%)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? amount / total : 0,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _MemberSettlementCard extends StatelessWidget {
  final MemberSettlement settlement;
  final String status; // 'owes', 'receive', 'balanced'
  final VoidCallback? onPayment;
  final bool isMe;

  const _MemberSettlementCard({
    required this.settlement,
    required this.status,
    this.onPayment,
    this.isMe = false,
  });

  Color _getStatusColor() {
    switch (status) {
      case 'owes':
        return Colors.red;
      case 'receive':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isMe ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMe ? BorderSide(color: _getStatusColor(), width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor().withOpacity(0.2),
                  child: Text(
                    settlement.userName[0].toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            settlement.userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${settlement.mealsEaten} meals eaten',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${settlement.absoluteBalance.toStringAsFixed(2)} BDT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Owed: ${settlement.totalOwed.toStringAsFixed(0)} BDT',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                Text(
                  'Paid: ${settlement.totalPaid.toStringAsFixed(0)} BDT',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (onPayment != null && status == 'owes') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onPayment,
                icon: const Icon(Icons.payment, size: 16),
                label: const Text('Pay Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettlementTransactionsSheet extends StatelessWidget {
  final List<SettlementTransaction> transactions;

  const _SettlementTransactionsSheet({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Settlement Transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Optimized payment plan to settle all balances:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ...transactions.map((txn) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.fromUserName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'pays ${txn.amount.toStringAsFixed(2)} BDT',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        txn.toUserName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}