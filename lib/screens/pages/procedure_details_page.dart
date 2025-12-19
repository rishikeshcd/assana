import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import 'medical_report_viewer_page.dart';

class ProcedureDetailsPage extends StatefulWidget {
  const ProcedureDetailsPage({super.key, required this.procedureId});

  final int procedureId;

  @override
  State<ProcedureDetailsPage> createState() => _ProcedureDetailsPageState();
}

class _ProcedureDetailsPageState extends State<ProcedureDetailsPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, dynamic>? _procedureData;
  List<Map<String, dynamic>> _siblingProcedures = [];
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
    _loadProcedureDetails(isInitialLoad: true);
    // Auto-refresh every 40 seconds (only when screen is active)
    _refreshTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted && _isRouteActive()) {
        print('⏰ ProcedureDetailsPage: Auto-refresh timer triggered');
        _loadProcedureDetails(isInitialLoad: false);
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
      print('🔄 ProcedureDetailsPage: App resumed, refreshing data');
      _loadProcedureDetails(isInitialLoad: false);
    }
  }

  // Check if this route is currently active/visible
  bool _isRouteActive() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  Future<void> _loadProcedureDetails({bool isInitialLoad = false}) async {
    // Prevent multiple simultaneous API calls
    if (_isRefreshing && !isInitialLoad) {
      print('⏸️ ProcedureDetailsPage: Refresh already in progress, skipping...');
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
      final response = await ApiMethods.getProcedureDetails(widget.procedureId);

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['status'] == true &&
          response.data['result'] != null) {
        final result = response.data['result'] as Map<String, dynamic>;
        setState(() {
          _procedureData = result['procedure'] as Map<String, dynamic>?;
          final siblings = result['sibiling_procedure'] as List<dynamic>? ?? [];
          _siblingProcedures = siblings
              .map((s) => s as Map<String, dynamic>)
              .toList();
          _appointmentData = result['appointment'] as Map<String, dynamic>?;
          _prescriptionData = result['prescription'] as Map<String, dynamic>?;
          _patientData = result['patient'] as Map<String, dynamic>?;
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load procedure details';
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      print('Error loading procedure details: $e');
      setState(() {
        _errorMessage = 'Error loading procedure details: ${e.toString()}';
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

  String _getProcedureName(int? procedureId) {
    // This would ideally come from the API, but for now return a placeholder
    return 'Procedure #${procedureId ?? 'N/A'}';
  }

  bool _canChangeStatus() {
    if (_procedureData == null) return false;

    final status = (_procedureData!['status'] as String? ?? '').toUpperCase();

    // Don't allow status change if already COMPLETED or CANCELLED
    if (status == 'COMPLETED' || status == 'CANCELLED') {
      return false;
    }

    // Don't allow status change for unassigned procedures (NOT_SCHEDULED, or no date)
    if (status == 'NOT_SCHEDULED' || status == 'NOT_SHEDULED') {
      return false;
    }

    // Check if procedure date is today or in the future
    final scheduledDateStr = _procedureData!['scheduled_date'] as String?;
    if (scheduledDateStr != null && scheduledDateStr.isNotEmpty) {
      try {
        final scheduledDate = DateTime.parse(scheduledDateStr);
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final scheduledDateStart = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
        );

        // Allow status change if procedure date is today or in the future
        return scheduledDateStart.isAfter(todayStart) ||
            scheduledDateStart.isAtSameMomentAs(todayStart);
      } catch (e) {
        print('Error parsing procedure date: $e');
        // If date parsing fails, don't allow status change (might be unassigned)
        return false;
      }
    }

    // If no date, don't allow status change (unassigned procedure)
    return false;
  }

  bool _canReschedule() {
    if (_procedureData == null) return false;

    final status = (_procedureData!['status'] as String? ?? '').toUpperCase();

    // Don't allow reschedule if status is ONGOING, COMPLETED, or CANCELLED
    if (status == 'ONGOING' || status == 'COMPLETED' || status == 'CANCELLED') {
      return false;
    }

    // Don't allow reschedule for unassigned procedures (NOT_SCHEDULED, or no date)
    if (status == 'NOT_SCHEDULED' || status == 'NOT_SHEDULED') {
      return false;
    }

    // Check if procedure date is today or in the future
    final scheduledDateStr = _procedureData!['scheduled_date'] as String?;
    if (scheduledDateStr != null && scheduledDateStr.isNotEmpty) {
      try {
        final scheduledDate = DateTime.parse(scheduledDateStr);
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final scheduledDateStart = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
        );

        // Allow reschedule if procedure date is today or in the future
        return scheduledDateStart.isAfter(todayStart) ||
            scheduledDateStart.isAtSameMomentAs(todayStart);
      } catch (e) {
        print('Error parsing procedure date: $e');
        // If date parsing fails, don't allow reschedule (might be unassigned)
        return false;
      }
    }

    // If no date, don't allow reschedule (unassigned procedure)
    return false;
  }

  void _showStatusDialog() {
    if (_procedureData == null) return;

    // Create a procedure map with patient name for the dialog
    final procedureForDialog = Map<String, dynamic>.from(_procedureData!);
    if (_appointmentData?['patient_name'] != null) {
      procedureForDialog['name'] = _appointmentData!['patient_name'];
    }

    showDialog(
      context: context,
      builder: (context) => _StatusDialog(
        procedure: procedureForDialog,
        currentStatus: _procedureData!['status'] as String?,
        onStatusChanged: () {
          _loadProcedureDetails(); // Reload details after status change
        },
      ),
    );
  }

  void _showRescheduleDialog() {
    if (_procedureData == null) return;

    // Create a procedure map with patient name for the dialog
    final procedureForDialog = Map<String, dynamic>.from(_procedureData!);
    if (_appointmentData?['patient_name'] != null) {
      procedureForDialog['name'] = _appointmentData!['patient_name'];
    }

    showDialog(
      context: context,
      builder: (context) => _RescheduleDialog(
        procedure: procedureForDialog,
        onRescheduled: () {
          _loadProcedureDetails(); // Reload details after rescheduling
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Procedure Details'),
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
                        onPressed: () => _loadProcedureDetails(isInitialLoad: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadProcedureDetails(isInitialLoad: false),
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

                        // Procedure Name (from procedure_id - would need API to provide name)
                        if (_procedureData?['procedure_id'] != null)
                          _DetailCard(
                            title: 'Procedure',
                            content: _getProcedureName(
                              _procedureData!['procedure_id'] as int?,
                            ),
                            icon: Icons.medical_services,
                          ),
                        const SizedBox(height: 16),

                        // Step Order
                        if (_procedureData?['step_order'] != null)
                          _DetailCard(
                            title: 'Step Order',
                            content: _procedureData!['step_order'].toString(),
                            icon: Icons.list,
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
                        if (_prescriptionData?['past_history'] != null &&
                            (_prescriptionData!['past_history'] as String)
                                .isNotEmpty)
                          _DetailCard(
                            title: 'Past History',
                            content: _prescriptionData!['past_history'] as String,
                            icon: Icons.history,
                          ),
                        if (_prescriptionData?['past_history'] != null &&
                            (_prescriptionData!['past_history'] as String)
                                .isNotEmpty)
                          const SizedBox(height: 16),

                        // Final Diagnose
                        if (_prescriptionData?['final_diagnose'] != null &&
                            (_prescriptionData!['final_diagnose'] as String)
                                .isNotEmpty)
                          _DetailCard(
                            title: 'Final Diagnose',
                            content: _prescriptionData!['final_diagnose'] as String,
                            icon: Icons.assignment,
                          ),
                        if (_prescriptionData?['final_diagnose'] != null &&
                            (_prescriptionData!['final_diagnose'] as String)
                                .isNotEmpty)
                          const SizedBox(height: 16),

                        // Scheduled Date
                        if (_procedureData?['scheduled_date'] != null)
                          _DetailCard(
                            title: 'Scheduled Date',
                            content: _formatDateTime(
                              _procedureData!['scheduled_date'] as String?,
                            ),
                            icon: Icons.calendar_today,
                          )
                        else
                          _DetailCard(
                            title: 'Scheduled Date',
                            content: 'Not scheduled',
                            icon: Icons.calendar_today,
                          ),
                        const SizedBox(height: 16),

                        // Status (clickable to change only for today's/upcoming procedures)
                        if (_procedureData?['status'] != null)
                          _canChangeStatus()
                              ? InkWell(
                                  onTap: () => _showStatusDialog(),
                                  child: _DetailCard(
                                    title: 'Status',
                                    content: _procedureData!['status'] as String,
                                    icon: Icons.flag,
                                    showArrow: true,
                                  ),
                                )
                              : _DetailCard(
                                  title: 'Status',
                                  content: _procedureData!['status'] as String,
                                  icon: Icons.flag,
                                  showArrow: false,
                                ),
                        const SizedBox(height: 16),

                        // Reschedule Button (only for scheduled procedures, not ONGOING)
                        if (_canReschedule() && _procedureData != null)
                          ElevatedButton.icon(
                            onPressed: () => _showRescheduleDialog(),
                            icon: const Icon(Icons.schedule),
                            label: const Text('Reschedule Procedure'),
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
                        if (_canReschedule() && _procedureData != null)
                          const SizedBox(height: 16),

                        // Sibling Procedures
                        if (_siblingProcedures.isNotEmpty) ...[
                          Text(
                            'Sibling Procedures',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._siblingProcedures.map((sibling) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.medical_services_outlined,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getProcedureName(
                                            sibling['procedure_id'] as int?,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (sibling['step_order'] != null)
                                    Text(
                                      'Step: ${sibling['step_order']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: ${sibling['status'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  if (sibling['scheduled_date'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${_formatDateTime(sibling['scheduled_date'] as String?)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

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
                        if (_appointmentData?['medical_report_link_unlocked'] !=
                            null)
                          const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
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

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({
    required this.procedure,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> procedure;
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
      final procedureId = widget.procedure['id'] as int;
      final statusToUpdate = _selectedStatus!.toUpperCase();
      print('🔄 Updating procedure $procedureId status from ${widget.currentStatus} to $statusToUpdate');
      
      final response = await ApiMethods.updateProcedureStatus(
        procedureId: procedureId,
        status: statusToUpdate,
      );

      print('✅ API Response Status: ${response.statusCode}');
      print('✅ API Response Data: ${response.data}');

      // Check HTTP status code and response body status field (if it exists)
      // If status field doesn't exist, treat HTTP 200 as success
      // If status field exists and is false, treat as error
      final hasStatusField = response.data != null &&
          response.data is Map &&
          response.data.containsKey('status');
      final isStatusFalse = hasStatusField && response.data['status'] == false;

      if (response.statusCode == 200 && !isStatusFalse && mounted) {
        Navigator.of(context).pop();
        widget.onStatusChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $_selectedStatus'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Extract error message from response body
        final errorMsg = response.data?['message'] ??
            'Failed to update status';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ Error updating procedure status: $e');
      if (e is DioException) {
        print('❌ DioException details: ${e.response?.data}');
        print('❌ DioException status: ${e.response?.statusCode}');
        print('❌ DioException message: ${e.message}');
      }
      if (mounted) {
        String errorMessage = 'Error updating status';
        if (e is DioException) {
          if (e.response?.data != null && e.response!.data is Map) {
            errorMessage = e.response!.data['message'] ?? 
                          e.response!.data['error'] ?? 
                          e.message ?? 
                          'Failed to update status';
          } else {
            errorMessage = e.message ?? 'Network error occurred';
          }
        } else {
          errorMessage = e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
      case 'COMPLETED':
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

    // If status is ONGOING, only allow COMPLETED or CANCELLED
    if (currentStatus == 'ONGOING') {
      return ['COMPLETED', 'CANCELLED'];
    }

    // For other statuses (COMPLETED, CANCELLED), no options available
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
          'Update Procedure Status',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This procedure is already ${widget.currentStatus}. Status cannot be changed.',
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
        'Update Procedure Status',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.procedure['name'] != null)
              Text(
                'Patient: ${widget.procedure['name']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            if (widget.currentStatus != null) ...[
              if (widget.procedure['name'] != null) const SizedBox(height: 8),
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
    required this.procedure,
    required this.onRescheduled,
  });

  final Map<String, dynamic> procedure;
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

      final procedureId = widget.procedure['id'] as int;
      print('🔄 Rescheduling procedure $procedureId to $isoDate');
      
      final response = await ApiMethods.rescheduleProcedure(
        procedureId: procedureId,
        newDate: isoDate,
        reason: _reasonController.text.trim(),
      );

      print('✅ Reschedule API Response Status: ${response.statusCode}');
      print('✅ Reschedule API Response Data: ${response.data}');

      // Check HTTP status code and response body status field (if it exists)
      // If status field doesn't exist, treat HTTP 200 as success
      // If status field exists and is false, treat as error
      final hasStatusField = response.data != null &&
          response.data is Map &&
          response.data.containsKey('status');
      final isStatusFalse = hasStatusField && response.data['status'] == false;

      if (response.statusCode == 200 && !isStatusFalse && mounted) {
        Navigator.of(context).pop();
        widget.onRescheduled();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Procedure rescheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Extract error message from response body
        final errorMsg = response.data?['message'] ??
            'Failed to reschedule procedure';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ Error rescheduling procedure: $e');
      if (e is DioException) {
        print('❌ DioException details: ${e.response?.data}');
        print('❌ DioException status: ${e.response?.statusCode}');
        print('❌ DioException message: ${e.message}');
      }
      if (mounted) {
        String errorMessage = 'Error rescheduling procedure';
        if (e is DioException) {
          if (e.response?.data != null && e.response!.data is Map) {
            errorMessage = e.response!.data['message'] ?? 
                          e.response!.data['error'] ?? 
                          e.message ?? 
                          'Failed to reschedule procedure';
          } else {
            errorMessage = e.message ?? 'Network error occurred';
          }
        } else {
          errorMessage = e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
        'Reschedule Procedure',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.procedure['name'] != null)
              Text(
                'Patient: ${widget.procedure['name']}',
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

