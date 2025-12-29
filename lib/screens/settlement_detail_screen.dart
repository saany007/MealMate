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
    final monthName = DateFormat('MMMM yyyy').format(_report.month);
    final myUserId = authService.userModel?.userId;
    final mySettlement = myUserId != null ? _report.memberSettlements[myUserId] : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Settlement - $monthName'),
        actions: [
          if (_report.status == 'draft')
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

            // My Settlement (Top Priority Card)
            if (mySettlement != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: mySettlement.netBalance > 0 ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: mySettlement.netBalance > 0 ? Colors.red.shade200 : Colors.green.shade200,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            mySettlement.netBalance > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: mySettlement.netBalance > 0 ? Colors.red : Colors.green,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              mySettlement.netBalance > 0 ? 'YOU NEED TO PAY' : 'YOU WILL RECEIVE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: mySettlement.netBalance > 0 ? Colors.red[900] : Colors.green[900],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${mySettlement.netBalance.abs().toStringAsFixed(2)} BDT',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: mySettlement.netBalance > 0 ? Colors.red[800] : Colors.green[800],
                            ),
                          ),
                          // PAY BUTTON (Visible if you owe > 0)
                          if (mySettlement.netBalance > 0)
                            ElevatedButton.icon(
                              onPressed: () => _makePayment(mySettlement),
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('PAY NOW'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Meals eaten: ${mySettlement.mealsEaten} | Paid: ${mySettlement.totalPaid.toStringAsFixed(0)} BDT',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Settlement Transactions Button
            OutlinedButton.icon(
              onPressed: _viewSettlementTransactions,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('View Who Pays Whom'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 24),

            // Category Breakdown
            if (_report.categoryBreakdown.isNotEmpty) ...[
              const Text(
                'Expense Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _report.categoryBreakdown.entries.map((entry) {
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
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Full Member List
            _buildMembersList(myUserId),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList(String? myUserId) {
    // Sort members: Debtors first (Red), then Creditors (Green)
    List<MemberSettlement> members = _report.memberSettlements.values.toList();
    members.sort((a, b) => b.netBalance.compareTo(a.netBalance));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Member Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...members.map((settlement) {
          String status = 'balanced';
          if (settlement.netBalance > 0) status = 'owes';
          if (settlement.netBalance < 0) status = 'receive';

          return _MemberSettlementCard(
            settlement: settlement,
            status: status,
            // Allow payment if it's ME and I OWE
            onPayment: (settlement.userId == myUserId && status == 'owes') 
                ? () => _makePayment(settlement) 
                : null,
            isMe: settlement.userId == myUserId,
          );
        }),
        const SizedBox(height: 30), // Bottom padding
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// HELPER WIDGETS
// ---------------------------------------------------------------------------

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
    final statusColor = _getStatusColor();
    final statusText = status == 'owes' ? 'NEEDS TO PAY' : (status == 'receive' ? 'GETS BACK' : 'SETTLED');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Text(
                    settlement.userName.isNotEmpty ? settlement.userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: statusColor,
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
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'YOU',
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
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${settlement.netBalance.abs().toStringAsFixed(0)} BDT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            
            // Payment Button inside the list item (if it's me and I owe)
            if (onPayment != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onPayment,
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('PAY NOW'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
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
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Who Pays Whom?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Follow this plan to settle all balances:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text("Everything is settled!"))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final txn = transactions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Payer
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      txn.fromUserName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                    const Text("PAYS", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              // Amount & Arrow
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    const Icon(Icons.arrow_forward, color: Colors.grey),
                                    Text(
                                      "${txn.amount.toStringAsFixed(0)} BDT",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              // Receiver
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      txn.toUserName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    const Text("RECEIVES", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
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