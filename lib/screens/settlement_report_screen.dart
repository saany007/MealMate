import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/settlement_service.dart';
import '../services/auth_service.dart';
import '../services/meal_system_service.dart';
import '../models/settlement_report_model.dart';
import 'settlement_detail_screen.dart';

class SettlementReportScreen extends StatefulWidget {
  const SettlementReportScreen({super.key});

  @override
  State<SettlementReportScreen> createState() => _SettlementReportScreenState();
}

class _SettlementReportScreenState extends State<SettlementReportScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final settlementService = Provider.of<SettlementService>(context, listen: false);
    
    if (authService.userModel?.currentMealSystemId != null) {
      await settlementService.loadSettlementReports(
        authService.userModel!.currentMealSystemId!,
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _generateReport() async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);

    // Show month picker
    final selectedMonth = await showDatePicker(
      context: context,
      initialDate: lastMonth,
      firstDate: DateTime(2020, 1),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Month',
    );

    if (selectedMonth == null) return;

    setState(() {
      _isGenerating = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final settlementService = Provider.of<SettlementService>(context, listen: false);
    final systemService = Provider.of<MealSystemService>(context, listen: false);

    if (systemService.currentMealSystem == null) return;

    final report = await settlementService.generateMonthlyReport(
      systemId: authService.userModel!.currentMealSystemId!,
      month: selectedMonth,
      mealSystem: systemService.currentMealSystem!,
    );

    setState(() {
      _isGenerating = false;
    });

    if (mounted) {
      if (report != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report generated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to report detail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettlementDetailScreen(report: report),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlementService = Provider.of<SettlementService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settlement Reports'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settlement Reports'),
      ),
      body: settlementService.reports.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Reports Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate your first monthly settlement report',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateReport,
                    icon: const Icon(Icons.add),
                    label: const Text('Generate Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: settlementService.reports.length,
                itemBuilder: (context, index) {
                  final report = settlementService.reports[index];
                  return _ReportCard(report: report);
                },
              ),
            ),
      floatingActionButton: settlementService.reports.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isGenerating ? null : _generateReport,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add),
              label: const Text('New Report'),
            )
          : null,
    );
  }
}

class _ReportCard extends StatelessWidget {
  final SettlementReportModel report;

  const _ReportCard({required this.report});

  Color _getStatusColor() {
    switch (report.status) {
      case SettlementStatus.draft:
        return Colors.orange;
      case SettlementStatus.finalized:
        return Colors.blue;
      case SettlementStatus.paid:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(report.month);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettlementDetailScreen(report: report),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: _getStatusColor(),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monthName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              SettlementStatus.getEmoji(report.status),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              SettlementStatus.getDisplayName(report.status),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${report.totalExpenses.toStringAsFixed(0)} BDT',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.restaurant,
                      label: '${report.totalMeals} Meals',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.attach_money,
                      label: '${report.costPerMeal.toStringAsFixed(1)} BDT/meal',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.people,
                      label: '${report.memberSettlements.length} Members',
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.payment,
                      label: '${report.membersWhoOwe.length} Pending',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}