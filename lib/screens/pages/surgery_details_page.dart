import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import 'medical_report_viewer_page.dart';

class SurgeryDetailsPage extends StatefulWidget {
  const SurgeryDetailsPage({super.key, required this.surgeryId});

  final int surgeryId;

  @override
  State<SurgeryDetailsPage> createState() => _SurgeryDetailsPageState();
}

class _SurgeryDetailsPageState extends State<SurgeryDetailsPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, dynamic>? _surgeryData;
  Map<String, dynamic>? _appointmentData;
  Map<String, dynamic>? _prescriptionData;
  Map<String, dynamic>? _patientData;
  String? _errorMessage;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSurgeryDetails(isInitialLoad: true);
    // Auto-refresh every 40 seconds (only when screen is active)
    _refreshTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted && _isRouteActive()) {
        print('⏰ SurgeryDetailsPage: Auto-refresh timer triggered');
        _loadSurgeryDetails(isInitialLoad: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app comes to foreground and this route is active
    if (state == AppLifecycleState.resumed && mounted && _isRouteActive()) {
      print('🔄 SurgeryDetailsPage: App resumed, refreshing data');
      _loadSurgeryDetails(isInitialLoad: false);
    }
  }

  // Check if this route is currently active/visible
  bool _isRouteActive() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  Future<void> _loadSurgeryDetails({bool isInitialLoad = false}) async {
    // Prevent multiple simultaneous API calls
    if (_isRefreshing && !isInitialLoad) {
      print('⏸️ SurgeryDetailsPage: Refresh already in progress, skipping...');
      return;
    }

    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _isRefreshing = true;
    }

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
          _patientData = result['patient'] as Map<String, dynamic>?;
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load surgery details';
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      print('Error loading surgery details: $e');
      setState(() {
        _errorMessage = 'Error loading surgery details: ${e.toString()}';
        if (isInitialLoad) {
          _isLoading = false;
        }
      });
    } finally {
      _isRefreshing = false;
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

  bool _canReschedule() {
    if (_surgeryData == null) return false;

    final status = (_surgeryData!['status'] as String? ?? '').toUpperCase();

    // Don't allow reschedule if status is ONGOING, FINISHED, or CANCELLED
    if (status == 'ONGOING' || status == 'FINISHED' || status == 'CANCELLED') {
      return false;
    }

    // Don't allow reschedule for unassigned surgeries (NOT_SHEDULED, NOT_SCHEDULED, or no date)
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

        // Allow reschedule if surgery date is today or in the future
        return surgeryDateStart.isAfter(todayStart) ||
            surgeryDateStart.isAtSameMomentAs(todayStart);
      } catch (e) {
        print('Error parsing surgery date: $e');
        // If date parsing fails, don't allow reschedule (might be unassigned)
        return false;
      }
    }

    // If no date, don't allow reschedule (unassigned surgery)
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

  void _showRescheduleDialog() {
    if (_surgeryData == null) return;

    // Create a surgery map with patient name for the dialog
    final surgeryForDialog = Map<String, dynamic>.from(_surgeryData!);
    if (_appointmentData?['patient_name'] != null) {
      surgeryForDialog['name'] = _appointmentData!['patient_name'];
    }

    showDialog(
      context: context,
      builder: (context) => _RescheduleDialog(
        surgery: surgeryForDialog,
        onRescheduled: () {
          _loadSurgeryDetails(); // Reload details after rescheduling
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

  String _buildEmergencyContactContent() {
    final name = _patientData?['emergency_contact_name'] as String?;
    final phone = _patientData?['emergency_contact_phone'] as String?;
    
    final List<String> parts = [];
    if (name != null && name.isNotEmpty) {
      parts.add('Name: $name');
    }
    if (phone != null && phone.isNotEmpty) {
      parts.add('Phone: $phone');
    }
    
    return parts.isEmpty ? 'Not available' : parts.join('\n');
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

                    // Phone Number
                    if (_patientData?['phone_number'] != null)
                      _DetailCard(
                        title: 'Phone Number',
                        content: _patientData!['phone_number'] as String,
                        icon: Icons.phone,
                      ),
                    const SizedBox(height: 16),

                    // Emergency Contact
                    if ((_patientData?['emergency_contact_name'] != null &&
                            (_patientData!['emergency_contact_name'] as String)
                                .isNotEmpty) ||
                        (_patientData?['emergency_contact_phone'] != null &&
                            (_patientData!['emergency_contact_phone'] as String)
                                .isNotEmpty))
                      _DetailCard(
                        title: 'Emergency Contact',
                        content: _buildEmergencyContactContent(),
                        icon: Icons.emergency,
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

                    // Reschedule Button (only for today's/upcoming surgeries, not ONGOING)
                    if (_canReschedule() && _surgeryData != null)
                      ElevatedButton.icon(
                        onPressed: () => _showRescheduleDialog(),
                        icon: const Icon(Icons.schedule),
                        label: const Text('Reschedule Surgery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    if (_canReschedule() && _surgeryData != null)
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

    // If status is SCHEDULED, SHEDULED, or RESCHEDULED, only allow ONGOING or CANCELLED
    if (currentStatus == 'SCHEDULED' ||
        currentStatus == 'SHEDULED' ||
        currentStatus == 'RESCHEDULED') {
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

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({
    required this.surgery,
    required this.onRescheduled,
  });

  final Map<String, dynamic> surgery;
  final VoidCallback onRescheduled;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _reschedule() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both date and time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for rescheduling'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time into ISO 8601 format
      final dateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      final isoDate = dateTime.toIso8601String().split('.')[0]; // Remove milliseconds

      final surgeryId = widget.surgery['id'] as int;
      final response = await ApiMethods.rescheduleSurgery(
        surgeryId: surgeryId,
        newDate: isoDate,
        reason: _reasonController.text.trim(),
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.of(context).pop();
        widget.onRescheduled();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Surgery rescheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to reschedule surgery');
      }
    } catch (e) {
      print('Error rescheduling surgery: $e');
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        'Reschedule Surgery',
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
            const SizedBox(height: 24),
            // Date picker
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Select New Date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedDate == null
                            ? Colors.grey.shade600
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Time picker
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime == null
                          ? 'Select New Time'
                          : _selectedTime!.format(context),
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedTime == null
                            ? Colors.grey.shade600
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reason field
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for Rescheduling',
                hintText: 'Enter reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _reschedule,
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
              : const Text('Reschedule'),
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
