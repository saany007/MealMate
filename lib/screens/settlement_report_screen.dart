import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Added for feedback

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
    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final settlementService = Provider.of<SettlementService>(context, listen: false);
    
    if (authService.userModel?.currentMealSystemId != null) {
      await settlementService.loadSettlementReports(
        authService.userModel!.currentMealSystemId!,
      );
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateReport() async {
    final now = DateTime.now();
    // Default to generating for current month
    // You could add a month picker here if needed
    
    setState(() => _isGenerating = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final settlementService = Provider.of<SettlementService>(context, listen: false);
      final mealSystemService = Provider.of<MealSystemService>(context, listen: false); // Get MealSystem

      final systemId = authService.userModel?.currentMealSystemId;
      if (systemId == null) return;

      // Pass the current meal system to ensure we get correct Member Names
      final report = await settlementService.generateMonthlyReport(
        systemId: systemId,
        month: now,
        mealSystem: mealSystemService.currentMealSystem, // OPTIMIZATION: Pass loaded system
      );

      if (mounted) {
        if (report != null) {
          Fluttertoast.showToast(msg: "Report generated successfully");
          // Refresh dashboard data too if needed
          await mealSystemService.refreshSystemStats(systemId);
        } else {
          Fluttertoast.showToast(msg: "Failed to generate report");
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlementService = Provider.of<SettlementService>(context);
    final reports = settlementService.reports;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settlement Reports'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : reports.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _ReportCard(report: reports[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _generateReport,
        label: Text(_isGenerating ? 'Generating...' : 'Generate Current Month'),
        icon: _isGenerating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add_chart),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No settlement reports yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a report to settle monthly expenses',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final SettlementReportModel report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM yyyy').format(report.month);
    final isFinalized = report.status == 'finalized';

    return Card(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFinalized ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      report.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isFinalized ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.attach_money,
                      label: '${report.totalExpenses.toStringAsFixed(0)} BDT',
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.restaurant,
                      label: '${report.costPerMeal.toStringAsFixed(1)} / meal',
                      color: Colors.blue,
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