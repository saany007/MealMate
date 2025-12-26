import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../models/expense_model.dart';
import '../models/meal_system_model.dart';
import '../services/meal_system_service.dart';

class ExpenseSummaryScreen extends StatefulWidget {
  const ExpenseSummaryScreen({super.key});

  @override
  State<ExpenseSummaryScreen> createState() => _ExpenseSummaryScreenState();
}

class _ExpenseSummaryScreenState extends State<ExpenseSummaryScreen> {
  ExpenseSummary? _summary;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSummary();
    });
  }

  Future<void> _loadSummary() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final month = args?['month'] ?? DateTime.now();

    final authService = Provider.of<AuthService>(context, listen: false);
    final expenseService = Provider.of<ExpenseService>(context, listen: false);
    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) return;

    setState(() => _isLoading = true);

    // Load meal system to get member names
    final mealSystem = await mealSystemService.loadMealSystem(systemId);
    if (mealSystem == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Create member names map
    final memberNames = <String, String>{};
    mealSystem.members.forEach((userId, memberInfo) {
      memberNames[userId] = memberInfo.name;
    });

    // Calculate summary
    final summary = await expenseService.calculateMonthlySummary(
      systemId: systemId,
      month: month,
      memberNames: memberNames,
    );

    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final month = args?['month'] ?? DateTime.now();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Summary - ${DateFormat('MMMM yyyy').format(month)}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? const Center(child: Text('Failed to load summary'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Total Summary Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Total Expenses',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_summary!.totalExpenses.toStringAsFixed(2)} BDT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _SummaryItem(
                                  label: 'Total Meals',
                                  value: '${_summary!.totalMeals}',
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.white30,
                                ),
                                _SummaryItem(
                                  label: 'Cost/Meal',
                                  value: '${_summary!.costPerMeal.toStringAsFixed(2)} BDT',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Member Balances
                      const Text(
                        'Member Balances',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._summary!.memberBalances.values.map((balance) {
                        return _MemberBalanceCard(balance: balance);
                      }),
                      const SizedBox(height: 24),

                      // Settlement Instructions
                      if (_summary!.membersWhoOwe.isNotEmpty) ...[
                        const Text(
                          'Settlement Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'How to settle',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._getSettlementTransactions()
                                  .map((transaction) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward,
                                          size: 14,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue[900],
                                            ),
                                            children: [
                                              TextSpan(
                                                text: transaction.fromName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const TextSpan(text: ' pays '),
                                              TextSpan(
                                                text: transaction.toName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const TextSpan(text: ' '),
                                              TextSpan(
                                                text: '${transaction.amount.toStringAsFixed(2)} BDT',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF22C55E),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  List<PaymentTransaction> _getSettlementTransactions() {
    if (_summary == null) return [];
    final expenseService = Provider.of<ExpenseService>(context, listen: false);
    return expenseService.calculateSettlementTransactions(_summary!);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MemberBalanceCard extends StatelessWidget {
  final MemberBalance balance;

  const _MemberBalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isOwed = balance.netBalance > 0;
    final owes = balance.netBalance < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwed
              ? Colors.green.withOpacity(0.3)
              : owes
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isOwed
                    ? Colors.green.withOpacity(0.1)
                    : owes
                        ? Colors.red.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                child: Text(
                  balance.userName[0].toUpperCase(),
                  style: TextStyle(
                    color: isOwed
                        ? Colors.green
                        : owes
                            ? Colors.red
                            : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  balance.userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isOwed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${balance.absoluteBalance.toStringAsFixed(2)} BDT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
              else if (owes)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '-${balance.absoluteBalance.toStringAsFixed(2)} BDT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Settled',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailItem(
                label: 'Meals Eaten',
                value: '${balance.mealsEaten}',
                icon: Icons.restaurant,
              ),
              _DetailItem(
                label: 'Total Paid',
                value: '${balance.totalPaid.toStringAsFixed(0)}',
                icon: Icons.payment,
              ),
              _DetailItem(
                label: 'Total Owed',
                value: '${balance.totalOwed.toStringAsFixed(0)}',
                icon: Icons.calculate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}