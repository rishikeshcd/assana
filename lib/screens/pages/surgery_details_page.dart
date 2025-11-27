import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import 'medical_report_viewer_page.dart';

class SurgeryDetailsPage extends StatefulWidget {
  const SurgeryDetailsPage({super.key, required this.surgeryId});

  final int surgeryId;

  @override
  State<SurgeryDetailsPage> createState() => _SurgeryDetailsPageState();
}

class _SurgeryDetailsPageState extends State<SurgeryDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _surgeryData;
  Map<String, dynamic>? _appointmentData;
  Map<String, dynamic>? _prescriptionData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSurgeryDetails();
  }

  Future<void> _loadSurgeryDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiMethods.getSurgeryDetails(widget.surgeryId);

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['status'] == true &&
          response.data['result'] != null) {
        final result = response.data['result'] as Map<String, dynamic>;
        setState(() {
          _surgeryData = result['surgery'] as Map<String, dynamic>?;
          _appointmentData = result['appointment'] as Map<String, dynamic>?;
          _prescriptionData = result['prescription'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load surgery details';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading surgery details: $e');
      setState(() {
        _errorMessage = 'Error loading surgery details: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _openMedicalReport(String url) {
    // Open in-app using WebView
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MedicalReportViewerPage(reportUrl: url),
      ),
    );
  }

  bool _canChangeStatus() {
    if (_surgeryData == null) return false;

    final status = (_surgeryData!['status'] as String? ?? '').toUpperCase();

    // Don't allow status change if already FINISHED or CANCELLED
    if (status == 'FINISHED' || status == 'CANCELLED') {
      return false;
    }

    // Don't allow status change for unassigned surgeries (NOT_SHEDULED, NOT_SCHEDULED, or no date)
    if (status == 'NOT_SHEDULED' || status == 'NOT_SCHEDULED') {
      return false;
    }

    // Check if surgery date is today or in the future
    final surgeryDateStr = _surgeryData!['surgery_date'] as String?;
    if (surgeryDateStr != null && surgeryDateStr.isNotEmpty) {
      try {
        final surgeryDate = DateTime.parse(surgeryDateStr);
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final surgeryDateStart = DateTime(
          surgeryDate.year,
          surgeryDate.month,
          surgeryDate.day,
        );

        // Allow status change if surgery date is today or in the future
        return surgeryDateStart.isAfter(todayStart) ||
            surgeryDateStart.isAtSameMomentAs(todayStart);
      } catch (e) {
        print('Error parsing surgery date: $e');
        // If date parsing fails, don't allow status change (might be unassigned)
        return false;
      }
    }

    // If no date, don't allow status change (unassigned surgery)
    return false;
  }

  void _showStatusDialog() {
    if (_surgeryData == null) return;

    // Create a surgery map with patient name for the dialog
    final surgeryForDialog = Map<String, dynamic>.from(_surgeryData!);
    if (_appointmentData?['patient_name'] != null) {
      surgeryForDialog['name'] = _appointmentData!['patient_name'];
    }

    showDialog(
      context: context,
      builder: (context) => _StatusDialog(
        surgery: surgeryForDialog,
        currentStatus: _surgeryData!['status'] as String?,
        onStatusChanged: () {
          _loadSurgeryDetails(); // Reload details after status change
        },
      ),
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return 'Not scheduled';
    }
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final day = dateTime.day;
      final month = months[dateTime.month - 1];
      final year = dateTime.year;
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final displayMinute = minute.toString().padLeft(2, '0');

      return '$day $month $year, $displayHour:$displayMinute $period';
    } catch (e) {
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Surgery Details'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSurgeryDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSurgeryDetails,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Name
                    if (_appointmentData?['patient_name'] != null)
                      _DetailCard(
                        title: 'Patient Name',
                        content: _appointmentData!['patient_name'] as String,
                        icon: Icons.person,
                      ),
                    const SizedBox(height: 16),

                    // Surgery Name
                    if (_surgeryData?['surgery_name'] != null)
                      _DetailCard(
                        title: 'Surgery Name',
                        content: _surgeryData!['surgery_name'] as String,
                        icon: Icons.medical_services,
                      ),
                    const SizedBox(height: 16),

                    // Issue
                    if (_appointmentData?['issues'] != null)
                      _DetailCard(
                        title: 'Issue',
                        content: _appointmentData!['issues'] as String,
                        icon: Icons.info,
                      ),
                    const SizedBox(height: 16),

                    // Past History
                    if (_prescriptionData?['past_history'] != null)
                      _DetailCard(
                        title: 'Past History',
                        content: _prescriptionData!['past_history'] as String,
                        icon: Icons.history,
                      ),
                    const SizedBox(height: 16),

                    // Final Diagnose
                    if (_prescriptionData?['final_diagnose'] != null)
                      _DetailCard(
                        title: 'Final Diagnose',
                        content: _prescriptionData!['final_diagnose'] as String,
                        icon: Icons.assignment,
                      ),
                    const SizedBox(height: 16),

                    // Surgery Date
                    if (_surgeryData?['surgery_date'] != null)
                      _DetailCard(
                        title: 'Surgery Date',
                        content: _formatDateTime(
                          _surgeryData!['surgery_date'] as String?,
                        ),
                        icon: Icons.calendar_today,
                      ),
                    const SizedBox(height: 16),

                    // Status (clickable to change only for today's/upcoming surgeries)
                    if (_surgeryData?['status'] != null)
                      _canChangeStatus()
                          ? InkWell(
                              onTap: () => _showStatusDialog(),
                              child: _DetailCard(
                                title: 'Status',
                                content: _surgeryData!['status'] as String,
                                icon: Icons.flag,
                                showArrow: true,
                              ),
                            )
                          : _DetailCard(
                              title: 'Status',
                              content: _surgeryData!['status'] as String,
                              icon: Icons.flag,
                              showArrow: false,
                            ),
                    const SizedBox(height: 16),

                    // Medical Report Link
                    if (_appointmentData?['medical_report_link_unlocked'] !=
                        null)
                      InkWell(
                        onTap: () => _openMedicalReport(
                          _appointmentData!['medical_report_link_unlocked']
                              as String,
                        ),
                        child: _DetailCard(
                          title: 'Medical Report',
                          content: 'Tap to view medical report',
                          icon: Icons.description,
                          showArrow: true,
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({
    required this.surgery,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> surgery;
  final String? currentStatus;
  final VoidCallback onStatusChanged;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  String? _selectedStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == null || _selectedStatus == widget.currentStatus) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final surgeryId = widget.surgery['id'] as int;
      final response = await ApiMethods.updateSurgeryStatus(
        surgeryId: surgeryId,
        status: _selectedStatus!,
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.of(context).pop();
        widget.onStatusChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $_selectedStatus'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      print('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ONGOING':
        return Colors.orange;
      case 'FINISHED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  List<String> _getAvailableStatusOptions() {
    final currentStatus = widget.currentStatus?.toUpperCase() ?? '';

    // If status is SCHEDULED or SHEDULED, only allow ONGOING or CANCELLED
    if (currentStatus == 'SCHEDULED' || currentStatus == 'SHEDULED') {
      return ['ONGOING', 'CANCELLED'];
    }

    // If status is ONGOING, only allow FINISHED or CANCELLED
    if (currentStatus == 'ONGOING') {
      return ['FINISHED', 'CANCELLED'];
    }

    // For other statuses (FINISHED, CANCELLED), no options available
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final statusOptions = _getAvailableStatusOptions();

    // If no options available
    if (statusOptions.isEmpty) {
      return AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Update Surgery Status',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This surgery is already ${widget.currentStatus}. Status cannot be changed.',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        'Update Surgery Status',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.surgery['name'] != null)
              Text(
                'Patient: ${widget.surgery['name']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            if (widget.currentStatus != null) ...[
              if (widget.surgery['name'] != null) const SizedBox(height: 8),
              Text(
                'Current Status: ${widget.currentStatus}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ...statusOptions.map((status) {
              final isSelected = _selectedStatus?.toUpperCase() == status;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getStatusColor(status).withOpacity(0.1)
                          : AppColors.cardBackground,
                      border: Border.all(
                        color: isSelected
                            ? _getStatusColor(status)
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? _getStatusColor(status)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? _getStatusColor(status)
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? _getStatusColor(status)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.content,
    required this.icon,
    this.showArrow = false,
  });

  final String title;
  final String content;
  final IconData icon;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (showArrow)
            Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16),
        ],
      ),
    );
  }
}
