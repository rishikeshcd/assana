import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import 'procedure_details_page.dart';

class ProceduresTabWidget extends StatefulWidget {
  const ProceduresTabWidget({super.key, required this.searchQuery});

  final String searchQuery;

  @override
  State<ProceduresTabWidget> createState() => _ProceduresTabWidgetState();
}

class _ProceduresTabWidgetState extends State<ProceduresTabWidget>
    with WidgetsBindingObserver {
  int _selectedTab = 0; // 0: Scheduled, 1: Unscheduled, 2: Finished
  int _upcomingDays = 7; // Default: 7 days, options: 7, 30, 180
  bool _isLoading = false;
  List<Map<String, dynamic>> _todayProcedures = [];
  List<Map<String, dynamic>> _upcomingProcedures = [];
  List<Map<String, dynamic>> _unscheduledProcedures = [];
  List<Map<String, dynamic>> _finishedProcedures = [];
  String? _errorMessage;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProcedures(isInitialLoad: true);
    // Auto-refresh procedures every 40 seconds (only when screen is active)
    _refreshTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted && _isRouteActive()) {
        print('⏰ ProceduresTabWidget: Auto-refresh timer triggered');
        _loadProcedures(isInitialLoad: false);
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
    if (state == AppLifecycleState.resumed && mounted && _isRouteActive()) {
      print('🔄 ProceduresTabWidget: App resumed, refreshing data');
      _loadProcedures(isInitialLoad: false);
    }
  }

  @override
  void didUpdateWidget(ProceduresTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when search query changes
    if (oldWidget.searchQuery != widget.searchQuery) {
      setState(() {});
    }
  }

  bool _isRouteActive() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  Future<void> _loadProcedures({bool isInitialLoad = false}) async {
    if (_isRefreshing && !isInitialLoad) {
      print('⏸️ ProceduresTabWidget: Refresh already in progress, skipping...');
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
      // Load today and upcoming procedures
      final response = await ApiMethods.getTodayUpcomingProcedures(
        upcomingDays: _upcomingDays,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final today = data['today'] as List<dynamic>? ?? [];
        final upcoming = data['upcoming'] as List<dynamic>? ?? [];

        setState(() {
          _todayProcedures = _parseProcedures(today);
          _upcomingProcedures = _parseProcedures(upcoming);
          _errorMessage = null; // Clear any previous errors
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load procedures';
          _isLoading = false;
          _isRefreshing = false;
        });
        return;
      }
    } on DioException catch (e) {
      print(
        'Error loading today/upcoming procedures: ${e.type} - ${e.message}',
      );
      String errorMessage = 'Failed to load procedures';

      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 500) {
          errorMessage =
              'Server error. Our team has been notified. Please try again later.';
        } else if (statusCode == 401) {
          errorMessage = 'Session expired. Please login again.';
        } else if (statusCode == 403) {
          errorMessage = 'Access denied. Please check your permissions.';
        } else if (statusCode != null &&
            statusCode >= 400 &&
            statusCode < 500) {
          errorMessage = 'Request failed. Please try again.';
        } else if (statusCode != null && statusCode >= 500) {
          errorMessage = 'Server error. Please try again later.';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection and try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'No internet connection. Please check your network and try again.';
      } else if (e.message != null &&
          (e.message!.contains('Failed host lookup') ||
              e.message!.contains('SocketException') ||
              e.message!.contains('Network is unreachable'))) {
        errorMessage =
            'No internet connection. Please check your network settings.';
      }

      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    } catch (e) {
      print('Unexpected error loading today/upcoming procedures: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    // Only load unassigned and finished if main request was successful
    // Load unscheduled procedures
    try {
      final unscheduledResponse = await ApiMethods.getUnscheduledProcedures();
      if (unscheduledResponse.statusCode == 200 &&
          unscheduledResponse.data != null) {
        final unscheduled = unscheduledResponse.data as List<dynamic>? ?? [];
        setState(() {
          _unscheduledProcedures = _parseProcedures(unscheduled);
        });
      }
    } catch (e) {
      print('Error loading unscheduled procedures: $e');
    }

    // Load finished/completed procedures
    try {
      final finishedResponse = await ApiMethods.getFinishedProcedures();
      if (finishedResponse.statusCode == 200 && finishedResponse.data != null) {
        final data = finishedResponse.data;
        // Response structure: {surgeries: [...], total: number, page: number, per_page: number}
        // Note: API returns "surgeries" field for procedures
        final procedures = data['surgeries'] as List<dynamic>? ?? [];
        setState(() {
          _finishedProcedures = _parseProcedures(procedures);
        });
      }
    } catch (e) {
      print('Error loading finished procedures: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  List<Map<String, dynamic>> _parseProcedures(List<dynamic> procedures) {
    return procedures.map((procedure) {
      final scheduledDate = procedure['scheduled_date'] as String? ?? '';
      final formattedDate = _formatDateTime(scheduledDate);

      return {
        'id': procedure['id'],
        'procedure_id': procedure['procedure_id'],
        'patient_id': procedure['patient_id'],
        'appointment_id': procedure['appointment_id'],
        'prescription_id': procedure['prescription_id'],
        'scheduled_date': scheduledDate,
        'formatted_date': formattedDate,
        'status': procedure['status'] as String? ?? 'SCHEDULED',
        'procedure_name': procedure['procedure_name'] as String? ?? 'Procedure',
        'patient_name': procedure['patient_name'] as String? ?? 'Unknown',
        'step_order': procedure['step_order'],
        'created_at': procedure['created_at'],
        'updated_at': procedure['updated_at'],
      };
    }).toList();
  }

  String _formatDateTime(String dateTimeString) {
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

  List<Map<String, dynamic>> _applySearchFilter(
    List<Map<String, dynamic>> procedures,
  ) {
    if (widget.searchQuery.isEmpty) {
      return procedures;
    }

    final query = widget.searchQuery.toLowerCase();
    return procedures.where((procedure) {
      final name = (procedure['patient_name'] as String? ?? '').toLowerCase();
      final procedureName = (procedure['procedure_name'] as String? ?? '')
          .toLowerCase();
      final date = (procedure['formatted_date'] as String? ?? '').toLowerCase();
      final status = (procedure['status'] as String? ?? '').toLowerCase();

      return name.contains(query) ||
          procedureName.contains(query) ||
          date.contains(query) ||
          status.contains(query);
    }).toList();
  }

  Future<void> _showAssignDateDialog(Map<String, dynamic> procedure) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AssignDateDialog(procedure: procedure),
    );

    if (result != null && mounted) {
      // Reload procedures after assignment
      await _loadProcedures(isInitialLoad: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Upcoming days selector (only for Scheduled tab)
        if (_selectedTab == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Upcoming:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<int>(
                    value: _upcomingDays,
                    underline: const SizedBox(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 Days')),
                      DropdownMenuItem(value: 30, child: Text('1 Month')),
                      DropdownMenuItem(value: 180, child: Text('6 Months')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _upcomingDays = value;
                        });
                        _loadProcedures(isInitialLoad: false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        // Filter tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _FilterTab(
                  label: 'Scheduled',
                  isSelected: _selectedTab == 0,
                  onTap: () {
                    final previousTab = _selectedTab;
                    setState(() => _selectedTab = 0);
                    if (previousTab != 0) {
                      _loadProcedures(isInitialLoad: false);
                    }
                  },
                ),
              ),
              Expanded(
                child: _FilterTab(
                  label: 'Unscheduled',
                  isSelected: _selectedTab == 1,
                  onTap: () {
                    final previousTab = _selectedTab;
                    setState(() => _selectedTab = 1);
                    if (previousTab != 1) {
                      _loadProcedures(isInitialLoad: false);
                    }
                  },
                ),
              ),
              Expanded(
                child: _FilterTab(
                  label: 'Finished',
                  isSelected: _selectedTab == 2,
                  onTap: () {
                    final previousTab = _selectedTab;
                    setState(() => _selectedTab = 2);
                    if (previousTab != 2) {
                      _loadProcedures(isInitialLoad: false);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Content area
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                            _isRefreshing = false;
                          });
                          _loadProcedures(isInitialLoad: true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildProceduresList(),
        ),
      ],
    );
  }

  Widget _buildProceduresList() {
    List<Map<String, dynamic>> procedures = [];

    if (_selectedTab == 0) {
      // Scheduled: Show today's procedures first, then upcoming
      final filteredToday = _applySearchFilter(_todayProcedures);
      final filteredUpcoming = _applySearchFilter(_upcomingProcedures);

      if (filteredToday.isEmpty && filteredUpcoming.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: const Center(
                child: Text(
                  'No upcoming procedures',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          await _loadProcedures(isInitialLoad: false);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            // Today's Procedures Section - Always show
            if (filteredToday.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  "Today's Procedures",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ...filteredToday.map((procedure) {
                return _ProcedureCard(
                  name: procedure['patient_name'] as String,
                  procedureName: procedure['procedure_name'] as String,
                  date: procedure['formatted_date'] as String,
                  status: procedure['status'] as String?,
                  procedure: procedure,
                  isUnscheduled: false,
                  isTodaysProcedure: true,
                  onStatusChange: () => _loadProcedures(),
                );
              }),
            ],
            // Upcoming Procedures Section
            if (filteredUpcoming.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Text(
                  'Upcoming Procedures',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ...filteredUpcoming.map((procedure) {
                return _ProcedureCard(
                  name: procedure['patient_name'] as String,
                  procedureName: procedure['procedure_name'] as String,
                  date: procedure['formatted_date'] as String,
                  status: procedure['status'] as String?,
                  procedure: procedure,
                  isUnscheduled: false,
                  isTodaysProcedure: false,
                  onStatusChange: () => _loadProcedures(),
                );
              }),
            ],
          ],
        ),
      );
    } else if (_selectedTab == 1) {
      procedures = _applySearchFilter(_unscheduledProcedures);
    } else {
      procedures = _applySearchFilter(_finishedProcedures);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadProcedures(isInitialLoad: false);
      },
      child: procedures.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medical_services_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedTab == 0
                              ? 'Scheduled Procedures'
                              : _selectedTab == 1
                              ? 'Unscheduled Procedures'
                              : 'Finished Procedures',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedTab == 0
                              ? 'No scheduled procedures found'
                              : _selectedTab == 1
                              ? 'No unscheduled procedures found'
                              : 'No finished procedures found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: procedures.map((procedure) {
                return _ProcedureCard(
                  name: procedure['patient_name'] as String,
                  procedureName: procedure['procedure_name'] as String,
                  date: procedure['formatted_date'] as String,
                  status: procedure['status'] as String?,
                  procedure: procedure,
                  isUnscheduled: _selectedTab == 1,
                  onAssign: _selectedTab == 1
                      ? () => _showAssignDateDialog(procedure)
                      : null,
                );
              }).toList(),
            ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _ProcedureCard extends StatelessWidget {
  const _ProcedureCard({
    required this.name,
    required this.procedureName,
    required this.date,
    this.status,
    this.procedure,
    this.isUnscheduled = false,
    this.onAssign,
    this.isTodaysProcedure = false,
    this.onStatusChange,
  });

  final String name;
  final String procedureName;
  final String date;
  final String? status;
  final Map<String, dynamic>? procedure;
  final bool isUnscheduled;
  final VoidCallback? onAssign;
  final bool isTodaysProcedure;
  final VoidCallback? onStatusChange;

  void _showStatusDialog(BuildContext context) {
    if (procedure == null || onStatusChange == null) return;

    showDialog(
      context: context,
      builder: (context) => _StatusDialog(
        procedure: procedure!,
        currentStatus: status,
        onStatusChanged: onStatusChange!,
      ),
    );
  }

  String _formatStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
      case 'SHEDULED':
        return 'Scheduled';
      case 'ONGOING':
        return 'Ongoing';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'RESCHEDULED':
        return 'Rescheduled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: procedure != null && procedure!['id'] != null
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProcedureDetailsPage(
                      procedureId: procedure!['id'] as int,
                    ),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile picture
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person, color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: 16),
            // Middle column: Name, Procedure, Date/Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First row: Name and Schedule button aligned
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Schedule button for unscheduled procedures
                      if (isUnscheduled && onAssign != null)
                        ElevatedButton(
                          onPressed: onAssign,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Schedule',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      // Status button for today's procedures
                      else if (!isUnscheduled &&
                          procedure != null &&
                          isTodaysProcedure &&
                          onStatusChange != null)
                        ElevatedButton(
                          onPressed: () => _showStatusDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            minimumSize: const Size(8, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _formatStatusText(status ?? 'Status'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      // Status badge for upcoming procedures (non-clickable)
                      else if (!isUnscheduled &&
                          procedure != null &&
                          !isTodaysProcedure &&
                          status != null &&
                          onStatusChange == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatStatusText(status!),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        )
                      // Status button for upcoming procedures (clickable)
                      else if (!isUnscheduled &&
                          procedure != null &&
                          !isTodaysProcedure &&
                          onStatusChange != null)
                        ElevatedButton(
                          onPressed: () => _showStatusDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            minimumSize: const Size(8, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _formatStatusText(status ?? 'Status'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Procedure Name
                  Text(
                    procedureName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Date and Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      if (isUnscheduled) ...[
                        Text(
                          'Not scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignDateDialog extends StatefulWidget {
  const _AssignDateDialog({required this.procedure});

  final Map<String, dynamic> procedure;

  @override
  State<_AssignDateDialog> createState() => _AssignDateDialogState();
}

class _AssignDateDialogState extends State<_AssignDateDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
      initialTime: TimeOfDay.now(),
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

  Future<void> _assignDate() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both date and time'),
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
      final isoDate = dateTime.toIso8601String().split(
        '.',
      )[0]; // Remove milliseconds

      final procedureId = widget.procedure['id'] as int;
      final response = await ApiMethods.assignProcedureDate(
        procedureId: procedureId,
        scheduledDate: isoDate,
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.of(context).pop({'success': true});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Procedure date assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to assign date');
      }
    } catch (e) {
      print('Error assigning date: $e');
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
        'Assign Procedure Date',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient: ${widget.procedure['patient_name']}',
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                              : 'Select date',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.calendar_today, color: AppColors.primary),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Time',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTime != null
                              ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                              : 'Select time',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.access_time, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignDate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
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
              : const Text('Assign'),
        ),
      ],
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
      print(
        '🔄 Updating procedure $procedureId status from ${widget.currentStatus} to $statusToUpdate',
      );

      final response = await ApiMethods.updateProcedureStatus(
        procedureId: procedureId,
        status: statusToUpdate,
      );

      print('✅ API Response Status: ${response.statusCode}');
      print('✅ API Response Data: ${response.data}');

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
        final errorMsg = response.data?['message'] ?? 'Failed to update status';
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
            errorMessage =
                e.response!.data['message'] ??
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
            if (widget.procedure['patient_name'] != null)
              Text(
                'Patient: ${widget.procedure['patient_name']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            if (widget.currentStatus != null) ...[
              if (widget.procedure['patient_name'] != null)
                const SizedBox(height: 8),
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
