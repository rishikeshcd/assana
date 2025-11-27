import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import 'surgery_details_page.dart';

class SurgeriesPage extends StatefulWidget {
  const SurgeriesPage({super.key});

  @override
  State<SurgeriesPage> createState() => _SurgeriesPageState();
}

class _SurgeriesPageState extends State<SurgeriesPage> {
  int _selectedTab = 0; // 0: Upcoming, 1: Finished, 2: Unassigned
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _todaySurgeries = [];
  List<Map<String, dynamic>> _upcomingSurgeries = [];
  List<Map<String, dynamic>> _finishedSurgeries = [];
  List<Map<String, dynamic>> _unassignedSurgeries = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSurgeries();
  }

  Future<void> _loadSurgeries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load upcoming surgeries (today + upcoming)
      final response = await ApiMethods.getTodayUpcomingSurgeries();

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final today = data['today'] as List<dynamic>? ?? [];
        final upcoming = data['upcoming'] as List<dynamic>? ?? [];

        setState(() {
          _todaySurgeries = _parseSurgeries(today);
          _upcomingSurgeries = _parseSurgeries(upcoming);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load surgeries';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      print('Error loading surgeries: ${e.type} - ${e.message}');
      String errorMessage = 'Failed to load surgeries';

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
      });
    } catch (e) {
      print('Unexpected error loading surgeries: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }

    // Load unassigned surgeries
    try {
      final unassignedResponse = await ApiMethods.getUnassignedSurgeries();
      if (unassignedResponse.statusCode == 200 &&
          unassignedResponse.data != null) {
        final unassigned = unassignedResponse.data as List<dynamic>? ?? [];
        setState(() {
          _unassignedSurgeries = _parseUnassignedSurgeries(unassigned);
        });
      }
    } catch (e) {
      print('Error loading unassigned surgeries: $e');
    }

    // Load finished/completed surgeries
    try {
      final completedResponse = await ApiMethods.getCompletedSurgeries();
      if (completedResponse.statusCode == 200 &&
          completedResponse.data != null) {
        final data = completedResponse.data;
        // Response structure: {surgeries: [...], total: number, page: number, per_page: number}
        final surgeries = data['surgeries'] as List<dynamic>? ?? [];
        setState(() {
          _finishedSurgeries = _parseSurgeries(surgeries);
        });
      }
    } catch (e) {
      print('Error loading completed surgeries: $e');
    }
  }

  List<Map<String, dynamic>> _parseSurgeries(List<dynamic> surgeries) {
    return surgeries.map((surgery) {
      final surgeryDate = surgery['surgery_date'] as String? ?? '';
      final formattedDate = _formatDateTime(surgeryDate);

      return {
        'id': surgery['id'],
        'surgery_id': surgery['surgery_id'],
        'patient_id': surgery['patient_id'],
        'appointment_id': surgery['appointment_id'],
        'surgery_date': surgeryDate,
        'formatted_date': formattedDate,
        'status': surgery['status'] ?? 'SCHEDULED',
        'name':
            surgery['patient_name'] ??
            'Patient #${surgery['patient_id'] ?? 'N/A'}',
        'procedure': surgery['surgery_name'] ?? 'Surgery',
      };
    }).toList();
  }

  List<Map<String, dynamic>> _parseUnassignedSurgeries(
    List<dynamic> surgeries,
  ) {
    return surgeries.map((surgery) {
      return {
        'id': surgery['id'],
        'surgery_id': surgery['surgery_id'],
        'patient_id': surgery['patient_id'],
        'appointment_id': surgery['appointment_id'],
        'surgery_date': surgery['surgery_date'],
        'formatted_date': 'Not scheduled',
        'status': surgery['status'] ?? 'NOT_SHEDULED',
        'name':
            surgery['patient_name'] ??
            'Patient #${surgery['patient_id'] ?? 'N/A'}',
        'procedure': surgery['surgery_name'] ?? 'Surgery',
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

  List<Map<String, dynamic>> get _filteredSurgeries {
    List<Map<String, dynamic>> surgeries = [];

    if (_selectedTab == 0) {
      // Upcoming: Show today's surgeries first, then upcoming
      surgeries = [..._todaySurgeries, ..._upcomingSurgeries];
    } else if (_selectedTab == 1) {
      surgeries = _finishedSurgeries;
    } else if (_selectedTab == 2) {
      surgeries = _unassignedSurgeries;
    }

    // Apply search filter if search is active
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      surgeries = surgeries.where((surgery) {
        final name = (surgery['name'] as String? ?? '').toLowerCase();
        final procedure = (surgery['procedure'] as String? ?? '').toLowerCase();
        final date = (surgery['formatted_date'] as String? ?? '').toLowerCase();
        final status = (surgery['status'] as String? ?? '').toLowerCase();

        return name.contains(query) ||
            procedure.contains(query) ||
            date.contains(query) ||
            status.contains(query);
      }).toList();
    }

    return surgeries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Custom header
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48), // Spacer for centering
                      const Text(
                        'Surgeries',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isSearchVisible ? Icons.close : Icons.search,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearchVisible = !_isSearchVisible;
                            if (!_isSearchVisible) {
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // Search bar
                if (_isSearchVisible)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by name, procedure, date, status...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {});
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
                    label: 'Upcoming',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                Expanded(
                  child: _FilterTab(
                    label: 'Finished',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
                Expanded(
                  child: _FilterTab(
                    label: 'Unassigned',
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                  ),
                ),
              ],
            ),
          ),
          // Surgery list
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
                          onPressed: _loadSurgeries,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildSurgeriesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSurgeriesList() {
    if (_selectedTab == 0) {
      // Upcoming tab: Show today's surgeries first, then upcoming
      final filteredToday = _applySearchFilter(_todaySurgeries);
      final filteredUpcoming = _applySearchFilter(_upcomingSurgeries);

      if (filteredToday.isEmpty && filteredUpcoming.isEmpty) {
        return const Center(child: Text('No upcoming surgeries'));
      }

      return RefreshIndicator(
        onRefresh: _loadSurgeries,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            // Today's Surgeries Section - Always show
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Text(
                "Today's Surgeries",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (filteredToday.isNotEmpty)
              ...filteredToday.map(
                (surgery) => _SurgeryCard(
                  name: surgery['name'] as String,
                  procedure: surgery['procedure'] as String,
                  date: surgery['formatted_date'] as String,
                  status: surgery['status'] as String?,
                  surgery: surgery,
                  isTodaysSurgery: true,
                  onStatusChange: () => _loadSurgeries(),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No surgeries found today',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            // Upcoming Surgeries Section
            if (filteredUpcoming.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  'Upcoming Surgeries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ...filteredUpcoming.map(
                (surgery) => _SurgeryCard(
                  name: surgery['name'] as String,
                  procedure: surgery['procedure'] as String,
                  date: surgery['formatted_date'] as String,
                  status: surgery['status'] as String?,
                  surgery: surgery,
                  isTodaysSurgery: true,
                  onStatusChange: () => _loadSurgeries(),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      );
    } else {
      // Other tabs: Finished or Unassigned
      final filtered = _filteredSurgeries;
      if (filtered.isEmpty) {
        return const Center(child: Text('No surgeries found'));
      }

      return RefreshIndicator(
        onRefresh: _loadSurgeries,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final surgery = filtered[index];
            return _SurgeryCard(
              name: surgery['name'] as String,
              procedure: surgery['procedure'] as String,
              date: surgery['formatted_date'] as String,
              isUnassigned: _selectedTab == 2,
              onAssign: _selectedTab == 2
                  ? () => _showAssignDateDialog(surgery)
                  : null,
              status: surgery['status'] as String?,
              surgery: surgery,
              isTodaysSurgery: false,
              onStatusChange: null,
            );
          },
        ),
      );
    }
  }

  List<Map<String, dynamic>> _applySearchFilter(
    List<Map<String, dynamic>> surgeries,
  ) {
    if (_searchController.text.isEmpty) {
      return surgeries;
    }

    final query = _searchController.text.toLowerCase();
    return surgeries.where((surgery) {
      final name = (surgery['name'] as String? ?? '').toLowerCase();
      final procedure = (surgery['procedure'] as String? ?? '').toLowerCase();
      final date = (surgery['formatted_date'] as String? ?? '').toLowerCase();
      final status = (surgery['status'] as String? ?? '').toLowerCase();

      return name.contains(query) ||
          procedure.contains(query) ||
          date.contains(query) ||
          status.contains(query);
    }).toList();
  }

  Future<void> _showAssignDateDialog(Map<String, dynamic> surgery) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AssignDateDialog(surgery: surgery),
    );

    if (result != null && mounted) {
      // Reload surgeries after assignment
      await _loadSurgeries();
    }
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}

class _SurgeryCard extends StatelessWidget {
  const _SurgeryCard({
    required this.name,
    required this.procedure,
    required this.date,
    this.isUnassigned = false,
    this.onAssign,
    this.status,
    this.surgery,
    this.isTodaysSurgery = false,
    this.onStatusChange,
  });

  final String name;
  final String procedure;
  final String date;
  final bool isUnassigned;
  final VoidCallback? onAssign;
  final String? status;
  final Map<String, dynamic>? surgery;
  final bool isTodaysSurgery;
  final VoidCallback? onStatusChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Clickable content area
          InkWell(
            onTap: surgery != null && surgery!['id'] != null
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SurgeryDetailsPage(
                          surgeryId: surgery!['id'] as int,
                        ),
                      ),
                    );
                  }
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.only(right: 100), // Space for button
              child: Row(
                children: [
                  // Profile picture
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          procedure,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_filled,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
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
          ),
          // Action buttons positioned at top right (not clickable for navigation)
          Positioned(
            top: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Assign button for unassigned surgeries
                if (isUnassigned && onAssign != null)
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
                      'Assign',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // Status button for today's surgeries (clickable)
                if (!isUnassigned &&
                    surgery != null &&
                    isTodaysSurgery &&
                    onStatusChange != null)
                  ElevatedButton(
                    onPressed: () => _showStatusDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                // Status label for upcoming/finished surgeries (non-clickable)
                if (!isUnassigned &&
                    surgery != null &&
                    !isTodaysSurgery &&
                    status != null)
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
                      _formatStatusText(status ?? ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatusText(String status) {
    if (status.isEmpty || status == 'Status') return 'Status';
    // Handle common status formats
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'SHEDULED') return 'SCHEDULED';
    return upperStatus;
  }

  void _showStatusDialog(BuildContext context) {
    if (surgery == null || onStatusChange == null) return;

    showDialog(
      context: context,
      builder: (context) => _StatusDialog(
        surgery: surgery!,
        currentStatus: status,
        onStatusChanged: onStatusChange!,
      ),
    );
  }
}

class _AssignDateDialog extends StatefulWidget {
  const _AssignDateDialog({required this.surgery});

  final Map<String, dynamic> surgery;

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

      final surgeryId = widget.surgery['id'] as int;
      final response = await ApiMethods.assignSurgeryDate(
        surgeryId: surgeryId,
        surgeryDate: isoDate,
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.of(context).pop({'success': true});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Surgery date assigned successfully'),
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
        'Assign Surgery Date',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                              ? _selectedTime!.format(context)
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
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignDate,
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
              : const Text('Assign'),
        ),
      ],
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

    // If no options available (e.g., already FINISHED or CANCELLED)
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
            Text(
              'Patient: ${widget.surgery['name']}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.currentStatus != null) ...[
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
