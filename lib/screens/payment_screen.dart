import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settlement_service.dart';
import '../services/auth_service.dart';
import '../models/settlement_report_model.dart';

class PaymentScreen extends StatefulWidget {
  final SettlementReportModel report;
  final MemberSettlement settlement;

  const PaymentScreen({
    super.key,
    required this.report,
    required this.settlement,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();
  String _selectedMethod = PaymentMethod.bkash;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with owed amount
    _amountController.text = widget.settlement.absoluteBalance.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount > widget.settlement.absoluteBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount cannot exceed owed balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${amount.toStringAsFixed(2)} BDT'),
            const SizedBox(height: 8),
            Text('Method: ${PaymentMethod.getDisplayName(_selectedMethod)}'),
            if (_transactionIdController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Transaction ID: ${_transactionIdController.text.trim()}'),
            ],
            const SizedBox(height: 16),
            const Text(
              'This payment will be recorded in the settlement report.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    setState(() {
      _isProcessing = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final settlementService = Provider.of<SettlementService>(context, listen: false);

    final success = await settlementService.addPaymentRecord(
      systemId: authService.userModel!.currentMealSystemId!,
      reportId: widget.report.reportId,
      userId: widget.settlement.userId,
      amount: amount,
      method: _selectedMethod,
      transactionId: _transactionIdController.text.trim().isEmpty
          ? null
          : _transactionIdController.text.trim(),
    );

    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Make Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payment Summary Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total Owed:',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        Text(
                          '${widget.settlement.totalOwed.toStringAsFixed(2)} BDT',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Already Paid:',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        Text(
                          '${widget.settlement.totalPaid.toStringAsFixed(2)} BDT',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Remaining Balance:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${widget.settlement.absoluteBalance.toStringAsFixed(2)} BDT',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount Input
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount *',
                        hintText: 'Enter amount in BDT',
                        prefixIcon: Icon(Icons.attach_money),
                        suffixText: 'BDT',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 20),

                    // Payment Method Selection
                    const Text(
                      'Payment Method *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...PaymentMethod.all.map((method) {
                      return RadioListTile<String>(
                        value: method,
                        groupValue: _selectedMethod,
                        onChanged: (value) {
                          setState(() {
                            _selectedMethod = value!;
                          });
                        },
                        title: Row(
                          children: [
                            Text(PaymentMethod.getEmoji(method)),
                            const SizedBox(width: 8),
                            Text(PaymentMethod.getDisplayName(method)),
                          ],
                        ),
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                    const SizedBox(height: 20),

                    // Transaction ID (Optional)
                    TextField(
                      controller: _transactionIdController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID (optional)',
                        hintText: 'Enter transaction/reference ID',
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Instructions Card
            Card(
              elevation: 1,
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Instructions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InstructionItem(
                      text: 'This payment will be recorded but NOT processed through the app.',
                    ),
                    const SizedBox(height: 6),
                    _InstructionItem(
                      text: 'Make the payment directly to the person/owner through your chosen method.',
                    ),
                    const SizedBox(height: 6),
                    _InstructionItem(
                      text: 'Enter the transaction ID if available for record keeping.',
                    ),
                    const SizedBox(height: 6),
                    _InstructionItem(
                      text: 'You can make partial payments - remaining balance will be updated.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Process Payment Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Record Payment',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),

            // Previous Payments
            if (widget.settlement.payments.isNotEmpty) ...[
              const Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.settlement.payments.map((payment) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      child: Text(
                        PaymentMethod.getEmoji(payment.method),
                      ),
                    ),
                    title: Text(
                      '${payment.amount.toStringAsFixed(2)} BDT',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${PaymentMethod.getDisplayName(payment.method)} • ${_formatDate(payment.date)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: payment.transactionId != null
                        ? Text(
                            payment.transactionId!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InstructionItem extends StatelessWidget {
  final String text;

  const _InstructionItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[800],
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[800],
            ),
          ),
        ),
      ],
    );
  }
}