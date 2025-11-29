import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import 'medical_report_viewer_page.dart';

class AppointmentDetailsPage extends StatefulWidget {
  const AppointmentDetailsPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<AppointmentDetailsPage> createState() => _AppointmentDetailsPageState();
}

class _AppointmentDetailsPageState extends State<AppointmentDetailsPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _patientData;
  List<dynamic>? _appointmentHistory;
  String? _errorMessage;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBookingDetails(isInitialLoad: true);
    // Auto-refresh every 40 seconds (only when screen is active)
    _refreshTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted && _isRouteActive()) {
        print('⏰ AppointmentDetailsPage: Auto-refresh timer triggered');
        _loadBookingDetails(isInitialLoad: false);
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
      print('🔄 AppointmentDetailsPage: App resumed, refreshing data');
      _loadBookingDetails(isInitialLoad: false);
    }
  }

  // Check if this route is currently active/visible
  bool _isRouteActive() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  Future<void> _loadBookingDetails({bool isInitialLoad = false}) async {
    // Prevent multiple simultaneous API calls
    if (_isRefreshing && !isInitialLoad) {
      print(
        '⏸️ AppointmentDetailsPage: Refresh already in progress, skipping...',
      );
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
      print('📋 Loading booking details for ID: ${widget.bookingId}');
      final response = await ApiMethods.getBookingDetails(widget.bookingId);
      print('📥 API Response Status: ${response.statusCode}');
      print('📥 API Response Data: ${response.data}');

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['status'] == true &&
          response.data['result'] != null) {
        final result = response.data['result'] as Map<String, dynamic>;
        print('✅ Booking data loaded successfully');
        setState(() {
          _bookingData = result['booking'] as Map<String, dynamic>?;
          _patientData = result['patient'] as Map<String, dynamic>?;
          _appointmentHistory = result['appointment_history'] as List<dynamic>?;
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      } else {
        print('❌ API returned error or invalid response');
        setState(() {
          _errorMessage = 'Failed to load appointment details';
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      print('❌ Error loading appointment details: $e');
      setState(() {
        _errorMessage = 'Error loading appointment details: ${e.toString()}';
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

  String? _getMedicalReportLink() {
    // First check booking object
    final bookingLink =
        _bookingData?['medical_report_link_unlocked'] as String?;
    if (bookingLink != null && bookingLink.isNotEmpty) {
      return bookingLink;
    }

    // If not found, check appointment_history (most recent appointment with report)
    if (_appointmentHistory != null && _appointmentHistory!.isNotEmpty) {
      for (var appointment in _appointmentHistory!) {
        final link = appointment['medical_report_link_unlocked'] as String?;
        if (link != null && link.isNotEmpty) {
          return link;
        }
      }
    }

    return null;
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
        title: const Text('Appointment Details'),
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
                    onPressed: _loadBookingDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBookingDetails,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Name
                    if (_bookingData?['patient_name'] != null ||
                        _patientData?['first_name'] != null)
                      _DetailCard(
                        title: 'Patient Name',
                        content:
                            _bookingData?['patient_name'] as String? ??
                            '${_patientData?['first_name'] ?? ''} ${_patientData?['last_name'] ?? ''}'
                                .trim(),
                        icon: Icons.person,
                      ),
                    const SizedBox(height: 16),

                    // Phone Number
                    if (_bookingData?['whatsapp_number'] != null ||
                        _patientData?['whatsapp_number'] != null)
                      _DetailCard(
                        title: 'Phone Number',
                        content:
                            (_bookingData?['whatsapp_number'] ??
                                    _patientData?['whatsapp_number'] ??
                                    'N/A')
                                as String,
                        icon: Icons.phone,
                      ),
                    if (_bookingData?['whatsapp_number'] != null ||
                        _patientData?['whatsapp_number'] != null)
                      const SizedBox(height: 16),

                    // Appointment Type
                    if (_bookingData?['appointment_type'] != null)
                      _DetailCard(
                        title: 'Appointment Type',
                        content: _bookingData!['appointment_type'] as String,
                        icon: Icons.event,
                      ),
                    const SizedBox(height: 16),

                    // Status
                    if (_bookingData?['api_status'] != null ||
                        _bookingData?['status'] != null)
                      _DetailCard(
                        title: 'Status',
                        content:
                            (_bookingData?['api_status'] ??
                                    _bookingData?['status'] ??
                                    'N/A')
                                as String,
                        icon: Icons.flag,
                      ),
                    if (_bookingData?['api_status'] != null ||
                        _bookingData?['status'] != null)
                      const SizedBox(height: 16),

                    // Issue
                    if (_bookingData?['issues'] != null &&
                        (_bookingData!['issues'] as String).isNotEmpty)
                      _DetailCard(
                        title: 'Issue',
                        content: _bookingData!['issues'] as String,
                        icon: Icons.info,
                      ),
                    if (_bookingData?['issues'] != null &&
                        (_bookingData!['issues'] as String).isNotEmpty)
                      const SizedBox(height: 16),

                    // Booking Time / Rescheduled Booking Time
                    if (_bookingData?['resheduled_booking_time'] != null &&
                        (_bookingData!['resheduled_booking_time'] as String)
                            .isNotEmpty)
                      _DetailCard(
                        title: 'Rescheduled Booking Time',
                        content: _formatDateTime(
                          _bookingData!['resheduled_booking_time'] as String?,
                        ),
                        icon: Icons.schedule,
                      )
                    else if (_bookingData?['booking_time'] != null)
                      _DetailCard(
                        title: 'Booking Time',
                        content: _formatDateTime(
                          _bookingData!['booking_time'] as String?,
                        ),
                        icon: Icons.calendar_today,
                      ),
                    if (_bookingData?['resheduled_booking_time'] != null &&
                            (_bookingData!['resheduled_booking_time'] as String)
                                .isNotEmpty ||
                        _bookingData?['booking_time'] != null)
                      const SizedBox(height: 16),

                    // Medical Report Link - Check booking first, then appointment_history
                    if (_getMedicalReportLink() != null)
                      InkWell(
                        onTap: () =>
                            _openMedicalReport(_getMedicalReportLink()!),
                        child: _DetailCard(
                          title: 'Medical Report',
                          content: 'Tap to view medical report',
                          icon: Icons.description,
                          showArrow: true,
                        ),
                      ),
                    if (_getMedicalReportLink() != null)
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
