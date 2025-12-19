import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import 'surgery_details_page.dart';
import 'procedure_details_page.dart';

class SurgeriesPage extends StatefulWidget {
  const SurgeriesPage({super.key});

  @override
  State<SurgeriesPage> createState() => _SurgeriesPageState();
}

class _SurgeriesPageState extends State<SurgeriesPage>
    with WidgetsBindingObserver {
  Set<String> _selectedTypeFilters =
      {}; // Empty = All, can select: 'SURGERY', 'PROCEDURE'
  int _selectedTab = 0; // 0: Scheduled, 1: Unscheduled, 2: Finished
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;
  bool _isLoading = false;
  // Surgeries data
  List<Map<String, dynamic>> _todaySurgeries = [];
  List<Map<String, dynamic>> _upcomingSurgeries = [];
  List<Map<String, dynamic>> _finishedSurgeries = [];
  List<Map<String, dynamic>> _unassignedSurgeries = [];
  // Procedures data
  List<Map<String, dynamic>> _todayProcedures = [];
  List<Map<String, dynamic>> _upcomingProcedures = [];
  List<Map<String, dynamic>> _finishedProcedures = [];
  List<Map<String, dynamic>> _unscheduledProcedures = [];
  String? _errorMessage;
  Timer? _refreshTimer;
  bool _isRefreshing = false; // Prevent multiple simultaneous refreshes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllData(isInitialLoad: true);
    // Auto-refresh every 40 seconds (only when screen is active)
    _refreshTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted && _isRouteActive()) {
        print('⏰ SurgeriesPage: Auto-refresh timer triggered');
        _loadAllData(isInitialLoad: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app comes to foreground and this route is active
    if (state == AppLifecycleState.resumed && mounted && _isRouteActive()) {
      print('🔄 SurgeriesPage: App resumed, refreshing data');
      _loadAllData(isInitialLoad: false);
    }
  }

  // Check if this route is currently active/visible
  bool _isRouteActive() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  Future<void> _loadAllData({bool isInitialLoad = false}) async {
    // Reset refreshing flag to allow refresh
    _isRefreshing = false;
    // Load both surgeries and procedures
    await Future.wait([
      _loadSurgeries(isInitialLoad: isInitialLoad),
      _loadProcedures(isInitialLoad: isInitialLoad),
    ]);
    // Force a rebuild after data is loaded
    if (mounted) {
      setState(() {
        // Explicitly trigger rebuild with current state
      });
    }
  }

  Future<void> _loadSurgeries({bool isInitialLoad = false}) async {
    // Prevent multiple simultaneous API calls
    if (_isRefreshing && !isInitialLoad) {
      print('⏸️ SurgeriesPage: Refresh already in progress, skipping...');
      return;
    }

    // Only show loading indicator on initial load
    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      // Mark as refreshing for background updates
      _isRefreshing = true;
    }

    try {
      // Load upcoming surgeries (today + upcoming) - hardcoded to 100 days
      print('📅 Loading surgeries with upcomingDays: 100');
      final response = await ApiMethods.getTodayUpcomingSurgeries(
        upcomingDays: 100,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final today = data['today'] as List<dynamic>? ?? [];
        final upcoming = data['upcoming'] as List<dynamic>? ?? [];

        // Parse surgeries and filter out FINISHED/COMPLETED ones from today/upcoming
        final parsedToday = _parseSurgeries(today);
        final parsedUpcoming = _parseSurgeries(upcoming);

        // Filter out FINISHED/COMPLETED surgeries from today and upcoming lists
        // FINISHED surgeries should only appear in the Finished tab
        final filteredToday = parsedToday.where((surgery) {
          final status = (surgery['status'] as String? ?? '').toUpperCase();
          return status != 'COMPLETED' && status != 'FINISHED';
        }).toList();

        final filteredUpcoming = parsedUpcoming.where((surgery) {
          final status = (surgery['status'] as String? ?? '').toUpperCase();
          return status != 'COMPLETED' && status != 'FINISHED';
        }).toList();

        setState(() {
          // Clear old data first to ensure fresh data
          _todaySurgeries = [];
          _upcomingSurgeries = [];
          // Then set new data
          _todaySurgeries = filteredToday;
          _upcomingSurgeries = filteredUpcoming;
          print('📋 Parsed surgeries:');
          print('   Today (before filter): ${parsedToday.length}');
          print('   Today (after filter): ${_todaySurgeries.length}');
          print('   Upcoming (before filter): ${parsedUpcoming.length}');
          print('   Upcoming (after filter): ${_upcomingSurgeries.length}');
          _errorMessage = null; // Clear any previous errors
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load surgeries';
          _isLoading = false;
          _isRefreshing = false; // Reset refreshing flag on error
        });
        // Don't continue loading other data if main request failed
        return;
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
        _isRefreshing = false; // Reset refreshing flag on error
      });
      // Don't continue loading other data if main request failed
      return;
    } catch (e) {
      print('Unexpected error loading surgeries: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
        _isRefreshing = false; // Reset refreshing flag on error
      });
      // Don't continue loading other data if main request failed
      return;
    }

    // Only load unassigned and completed if main request was successful
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
      // Don't set error message here, just log it
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
      // Don't set error message here, just log it
    } finally {
      // Always reset refreshing flag
      _isRefreshing = false;
    }
  }

  Future<void> _loadProcedures({bool isInitialLoad = false}) async {
    // Prevent multiple simultaneous API calls
    if (_isRefreshing && !isInitialLoad) {
      print(
        '⏸️ SurgeriesPage: Procedures refresh already in progress, skipping...',
      );
      return;
    }

    // Only show loading indicator on initial load
    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      // Mark as refreshing for background updates
      _isRefreshing = true;
    }

    try {
      // Load upcoming procedures (today + upcoming) - hardcoded to 100 days
      print('📅 Loading procedures with upcomingDays: 100');
      final response = await ApiMethods.getTodayUpcomingProcedures(
        upcomingDays: 100,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final today = data['today'] as List<dynamic>? ?? [];
        final upcoming = data['upcoming'] as List<dynamic>? ?? [];

        print('📋 Procedures API response:');
        print('   Today procedures: ${today.length}');
        print('   Upcoming procedures: ${upcoming.length}');
        print('   Total procedures: ${today.length + upcoming.length}');

        // Parse procedures and filter out COMPLETED ones from today/upcoming
        final parsedToday = _parseProcedures(today);
        final parsedUpcoming = _parseProcedures(upcoming);

        // Filter out COMPLETED procedures from today and upcoming lists
        // COMPLETED procedures should only appear in the Finished tab
        final filteredToday = parsedToday.where((proc) {
          final status = (proc['status'] as String? ?? '').toUpperCase();
          return status != 'COMPLETED' && status != 'FINISHED';
        }).toList();

        final filteredUpcoming = parsedUpcoming.where((proc) {
          final status = (proc['status'] as String? ?? '').toUpperCase();
          return status != 'COMPLETED' && status != 'FINISHED';
        }).toList();

        setState(() {
          // Clear old data first to ensure fresh data
          _todayProcedures = [];
          _upcomingProcedures = [];
          // Then set new data
          _todayProcedures = filteredToday;
          _upcomingProcedures = filteredUpcoming;
          print('📋 Parsed procedures:');
          print('   Today (before filter): ${parsedToday.length}');
          print('   Today (after filter): ${_todayProcedures.length}');
          print('   Upcoming (before filter): ${parsedUpcoming.length}');
          print('   Upcoming (after filter): ${_upcomingProcedures.length}');
          _errorMessage = null; // Clear any previous errors
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load procedures';
          _isLoading = false;
          _isRefreshing = false; // Reset refreshing flag on error
        });
        return;
      }
    } on DioException catch (e) {
      print('Error loading procedures: ${e.type} - ${e.message}');
      // Don't set error message for procedures, just log it
      setState(() {
        if (isInitialLoad) {
          _isLoading = false;
        }
        _isRefreshing = false;
      });
      return;
    } catch (e) {
      print('Unexpected error loading procedures: $e');
      setState(() {
        if (isInitialLoad) {
          _isLoading = false;
        }
        _isRefreshing = false;
      });
      return;
    }

    // Only load unassigned and completed if main request was successful
    // Load unscheduled procedures
    try {
      final unscheduledResponse = await ApiMethods.getUnscheduledProcedures();
      if (unscheduledResponse.statusCode == 200 &&
          unscheduledResponse.data != null) {
        final unscheduled = unscheduledResponse.data as List<dynamic>? ?? [];
        print(
          '📋 Unscheduled procedures API returned ${unscheduled.length} items',
        );

        // Remove duplicates from API response based on ID
        final seenIds = <int>{};
        final uniqueUnscheduled = unscheduled.where((proc) {
          final id = proc['id'] as int?;
          if (id == null) return false;
          if (seenIds.contains(id)) {
            print('⚠️ Duplicate procedure ID found in API response: $id');
            return false;
          }
          seenIds.add(id);
          return true;
        }).toList();

        print(
          '📋 After deduplication: ${uniqueUnscheduled.length} unique unscheduled procedures',
        );

        setState(() {
          _unscheduledProcedures = _parseProcedures(uniqueUnscheduled);
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
        print('📋 Finished procedures API response: $data');

        // Response structure: {surgeries: [...], total: number, page: number, per_page: number}
        // Note: API returns "surgeries" field for procedures
        final procedures =
            data['surgeries'] as List<dynamic>? ??
            data['procedures'] as List<dynamic>? ??
            (data is List ? data : <dynamic>[]);

        print('📋 Found ${procedures.length} finished procedures');
        if (procedures.isNotEmpty) {
          print('📋 Sample finished procedure: ${procedures.first}');
        }

        setState(() {
          _finishedProcedures = _parseProcedures(procedures);
        });
      }
    } catch (e) {
      print('Error loading finished procedures: $e');
    } finally {
      // Always reset refreshing flag
      _isRefreshing = false;
    }
  }

  List<Map<String, dynamic>> _parseProcedures(List<dynamic> procedures) {
    return procedures.map((procedure) {
      // Try multiple possible date fields for finished procedures
      final scheduledDate =
          procedure['scheduled_date'] as String? ??
          procedure['completed_date'] as String? ??
          procedure['finished_date'] as String? ??
          procedure['date'] as String? ??
          '';

      // Debug: Print available date fields
      if (scheduledDate.isEmpty) {
        print(
          '⚠️ Procedure ${procedure['id']} has no date. Available fields: ${procedure.keys.toList()}',
        );
      }

      String formattedDate;
      if (scheduledDate.isEmpty) {
        formattedDate = 'Not scheduled';
      } else {
        formattedDate = _formatDateTime(scheduledDate);
        // If formatting failed and returned empty, use fallback
        if (formattedDate.isEmpty) {
          formattedDate = 'Not scheduled';
        }
      }

      return {
        'id': procedure['id'],
        'procedure_id': procedure['procedure_id'],
        'patient_id': procedure['patient_id'],
        'appointment_id': procedure['appointment_id'],
        'prescription_id': procedure['prescription_id'],
        'scheduled_date': scheduledDate,
        'formatted_date': formattedDate,
        'status': procedure['status'] as String? ?? 'SCHEDULED',
        'name':
            procedure['patient_name'] as String? ??
            'Patient #${procedure['patient_id'] ?? 'N/A'}',
        'procedure': procedure['procedure_name'] as String? ?? 'Procedure',
        'type': 'PROCEDURE', // Mark as procedure
      };
    }).toList();
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
        'type': 'SURGERY', // Mark as surgery
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
        'type': 'SURGERY', // Mark as surgery
      };
    }).toList();
  }

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) {
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
      print('Error parsing date: $dateTimeString - $e');
      // Return empty string so caller can handle it
      return '';
    }
  }

  DateTime _parseDateForSorting(String dateTimeString) {
    if (dateTimeString.isEmpty) {
      return DateTime(
        0,
      ); // Return epoch for items without dates (will sort first)
    }

    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      print('Error parsing date for sorting: $dateTimeString - $e');
      return DateTime(0);
    }
  }

  String _getPageTitle() {
    return 'Procedures';
  }

  void _clearAllFilters() {
    setState(() {
      _selectedTypeFilters.clear();
    });
  }

  void _showFilterMenu() {
    // Create a local copy of selected filters for the bottom sheet
    Set<String> tempTypeFilters = Set<String>.from(_selectedTypeFilters);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 0, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: Text(
                          'Filter',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Clear filters button in drawer
                      if (tempTypeFilters.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              tempTypeFilters.clear();
                            });
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Filter by Type
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Type',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // All option
                        ListTile(
                          leading: Icon(
                            Icons.list,
                            color: tempTypeFilters.isEmpty
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('All'),
                          trailing: tempTypeFilters.isEmpty
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setModalState(() {
                              tempTypeFilters.clear();
                            });
                          },
                        ),
                        // Surgeries option
                        ListTile(
                          leading: Icon(
                            Icons.medical_services,
                            color: tempTypeFilters.contains('SURGERY')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Surgeries'),
                          trailing: Checkbox(
                            value: tempTypeFilters.contains('SURGERY'),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempTypeFilters.add('SURGERY');
                                } else {
                                  tempTypeFilters.remove('SURGERY');
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                        // Procedures option
                        ListTile(
                          leading: Icon(
                            Icons.healing,
                            color: tempTypeFilters.contains('PROCEDURE')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Procedures'),
                          trailing: Checkbox(
                            value: tempTypeFilters.contains('PROCEDURE'),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempTypeFilters.add('PROCEDURE');
                                } else {
                                  tempTypeFilters.remove('PROCEDURE');
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Apply button (fixed at bottom)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedTypeFilters = Set<String>.from(
                            tempTypeFilters,
                          );
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getCombinedData() {
    List<Map<String, dynamic>> allData = [];

    // Get surgeries based on selected tab
    List<Map<String, dynamic>> surgeries = [];
    if (_selectedTab == 0) {
      surgeries = [..._todaySurgeries, ..._upcomingSurgeries];
    } else if (_selectedTab == 1) {
      surgeries = _unassignedSurgeries;
    } else if (_selectedTab == 2) {
      surgeries = _finishedSurgeries;
    }

    // Get procedures based on selected tab
    List<Map<String, dynamic>> procedures = [];
    if (_selectedTab == 0) {
      procedures = [..._todayProcedures, ..._upcomingProcedures];
    } else if (_selectedTab == 1) {
      procedures = _unscheduledProcedures;
    } else if (_selectedTab == 2) {
      procedures = _finishedProcedures;
    }

    // Combine and filter by type
    if (_selectedTypeFilters.isEmpty) {
      // Show all
      allData = [...surgeries, ...procedures];
    } else {
      if (_selectedTypeFilters.contains('SURGERY')) {
        allData.addAll(surgeries);
      }
      if (_selectedTypeFilters.contains('PROCEDURE')) {
        allData.addAll(procedures);
      }
    }

    // Remove duplicates based on ID and type
    final seenIds = <String>{};
    allData = allData.where((item) {
      final id = '${item['type']}_${item['id']}';
      if (seenIds.contains(id)) {
        return false; // Duplicate found, skip it
      }
      seenIds.add(id);
      return true;
    }).toList();

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      allData = allData.where((item) {
        final name = (item['name'] as String? ?? '').toLowerCase();
        final procedure = (item['procedure'] as String? ?? '').toLowerCase();
        final date = (item['formatted_date'] as String? ?? '').toLowerCase();
        final status = (item['status'] as String? ?? '').toLowerCase();

        return name.contains(query) ||
            procedure.contains(query) ||
            date.contains(query) ||
            status.contains(query);
      }).toList();
    }

    return allData;
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
                    horizontal: 25,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48), // Spacer for centering
                      Text(
                        _getPageTitle(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      // Search icon
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
                // Filter section (below title)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 1,
                  ),

                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Clear filters button
                      if (_selectedTypeFilters.isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearAllFilters,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (_selectedTypeFilters.isNotEmpty)
                        const SizedBox(width: 8),
                      // Filter icon
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: _selectedTypeFilters.isNotEmpty
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                        onPressed: _showFilterMenu,
                      ),
                    ],
                  ),
                ),
                // Search bar
                if (_isSearchVisible)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 3,
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
          // Content area (Surgeries or Procedures)
          Expanded(
            child: Column(
              children: [
                // Filter tabs
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 10,
                  ),
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
                              _loadAllData(isInitialLoad: false);
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
                              _loadAllData(isInitialLoad: false);
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
                              _loadAllData(isInitialLoad: false);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Combined list
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
                                  _loadAllData(isInitialLoad: true);
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
                      : _buildCombinedList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedList() {
    final allData = _getCombinedData();

    if (_selectedTab == 0) {
      // Scheduled: Show today's first, then upcoming - all mixed and sorted
      // Get today's items (surgeries + procedures)
      final todayItems = <Map<String, dynamic>>[];
      for (final item in allData) {
        if (item['type'] == 'SURGERY') {
          final isToday = _todaySurgeries.any((ts) => ts['id'] == item['id']);
          if (isToday) {
            todayItems.add(item);
          }
        } else if (item['type'] == 'PROCEDURE') {
          final isToday = _todayProcedures.any((tp) => tp['id'] == item['id']);
          if (isToday) {
            todayItems.add(item);
          }
        }
      }

      // Get upcoming items (surgeries + procedures)
      final upcomingItems = <Map<String, dynamic>>[];
      for (final item in allData) {
        if (item['type'] == 'SURGERY') {
          final isUpcoming = _upcomingSurgeries.any(
            (us) => us['id'] == item['id'],
          );
          if (isUpcoming) {
            upcomingItems.add(item);
          }
        } else if (item['type'] == 'PROCEDURE') {
          final isUpcoming = _upcomingProcedures.any(
            (up) => up['id'] == item['id'],
          );
          if (isUpcoming) {
            upcomingItems.add(item);
          }
        }
      }

      // Sort by date and time
      todayItems.sort((a, b) {
        final dateA = _parseDateForSorting(
          a['scheduled_date'] ?? a['surgery_date'] ?? '',
        );
        final dateB = _parseDateForSorting(
          b['scheduled_date'] ?? b['surgery_date'] ?? '',
        );
        return dateA.compareTo(dateB);
      });

      upcomingItems.sort((a, b) {
        final dateA = _parseDateForSorting(
          a['scheduled_date'] ?? a['surgery_date'] ?? '',
        );
        final dateB = _parseDateForSorting(
          b['scheduled_date'] ?? b['surgery_date'] ?? '',
        );
        return dateA.compareTo(dateB);
      });

      print('📋 After filtering:');
      print('   Today items: ${todayItems.length}');
      print('   Upcoming items: ${upcomingItems.length}');
      print('   Total to display: ${todayItems.length + upcomingItems.length}');

      final isEmpty = todayItems.isEmpty && upcomingItems.isEmpty;

      return RefreshIndicator(
        onRefresh: () async {
          await _loadAllData(isInitialLoad: false);
        },
        child: isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const Center(
                      child: Text(
                        'No upcoming surgeries or procedures',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Today's (mixed surgeries and procedures)
                  if (todayItems.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        "Today's",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    ...todayItems.map((item) {
                      if (item['type'] == 'SURGERY') {
                        return _SurgeryCard(
                          name: item['name'] as String,
                          procedure: item['procedure'] as String,
                          date: item['formatted_date'] as String,
                          status: item['status'] as String?,
                          surgery: item,
                          isTodaysSurgery: true,
                          onStatusChange: () async {
                            await _loadAllData();
                          },
                        );
                      } else {
                        final status = item['status'] as String? ?? '';
                        final statusUpper = status.toUpperCase();
                        final canChangeStatus =
                            statusUpper == 'RESCHEDULED' ||
                            statusUpper == 'SCHEDULED' ||
                            statusUpper == 'SHEDULED' ||
                            statusUpper == 'ONGOING';
                        return _buildProcedureCard(
                          item,
                          true,
                          onStatusChange: canChangeStatus
                              ? () => _loadAllData()
                              : null,
                        );
                      }
                    }),
                  ],
                  // Upcoming (mixed surgeries and procedures)
                  if (upcomingItems.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.only(
                        top: todayItems.isNotEmpty ? 16 : 8,
                        bottom: 12,
                      ),
                      child: Text(
                        'Upcoming',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    ...upcomingItems.map((item) {
                      if (item['type'] == 'SURGERY') {
                        final status = item['status'] as String? ?? '';
                        final statusUpper = status.toUpperCase();
                        final canChangeStatus =
                            statusUpper == 'RESCHEDULED' ||
                            statusUpper == 'SCHEDULED' ||
                            statusUpper == 'SHEDULED' ||
                            statusUpper == 'ONGOING';
                        return _SurgeryCard(
                          name: item['name'] as String,
                          procedure: item['procedure'] as String,
                          date: item['formatted_date'] as String,
                          status: item['status'] as String?,
                          surgery: item,
                          isTodaysSurgery: false,
                          onStatusChange: canChangeStatus
                              ? () async {
                                  await _loadAllData();
                                }
                              : null,
                        );
                      } else {
                        final status = item['status'] as String? ?? '';
                        final statusUpper = status.toUpperCase();
                        final canChangeStatus =
                            statusUpper == 'RESCHEDULED' ||
                            statusUpper == 'SCHEDULED' ||
                            statusUpper == 'SHEDULED' ||
                            statusUpper == 'ONGOING';
                        return _buildProcedureCard(
                          item,
                          false,
                          onStatusChange: canChangeStatus
                              ? () async {
                                  await _loadAllData();
                                }
                              : null,
                        );
                      }
                    }),
                  ],
                ],
              ),
      );
    } else {
      // Unscheduled or Finished: Show flat list
      final isEmpty = allData.isEmpty;

      return RefreshIndicator(
        onRefresh: () async {
          await _loadAllData(isInitialLoad: false);
        },
        child: isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Text(
                        _selectedTab == 1
                            ? 'No unscheduled surgeries or procedures'
                            : 'No finished surgeries or procedures',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: allData.length,
                itemBuilder: (context, index) {
                  final item = allData[index];
                  if (item['type'] == 'SURGERY') {
                    return _SurgeryCard(
                      name: item['name'] as String,
                      procedure: item['procedure'] as String,
                      date: item['formatted_date'] as String,
                      isUnassigned: _selectedTab == 1,
                      onAssign: _selectedTab == 1
                          ? () => _showAssignDateDialog(item)
                          : null,
                      status: item['status'] as String?,
                      surgery: item,
                      isTodaysSurgery: false,
                      onStatusChange: null,
                    );
                  } else {
                    return _buildProcedureCard(item, false);
                  }
                },
              ),
      );
    }
  }

  Widget _buildProcedureCard(
    Map<String, dynamic> procedure,
    bool isToday, {
    Future<void> Function()? onStatusChange,
  }) {
    final isUnscheduled = _selectedTab == 1;
    final status = procedure['status'] as String? ?? '';
    final statusUpper = status.toUpperCase();
    final canChangeStatus =
        onStatusChange != null &&
        (isToday ||
            statusUpper == 'RESCHEDULED' ||
            statusUpper == 'SCHEDULED' ||
            statusUpper == 'SHEDULED' ||
            statusUpper == 'ONGOING');
    final statusChangeCallback = onStatusChange; // Store for use in button
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: procedure['id'] != null
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProcedureDetailsPage(
                      procedureId: procedure['id'] as int,
                    ),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          procedure['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isUnscheduled)
                        ElevatedButton(
                          onPressed: () =>
                              _showAssignDateDialogForProcedure(procedure),
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
                      else if (canChangeStatus && statusChangeCallback != null)
                        ElevatedButton(
                          onPressed: () => _showProcedureStatusDialog(
                            context,
                            procedure,
                            statusChangeCallback,
                          ),
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
                            _formatProcedureStatusText(status),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (!isUnscheduled && status.isNotEmpty)
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
                            _formatProcedureStatusText(status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Procedure Name with label
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: const Text(
                          'Procedure',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          procedure['procedure'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUnscheduled
                            ? 'Unscheduled'
                            : procedure['formatted_date'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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

  String _formatProcedureStatusText(String status) {
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

  void _showProcedureStatusDialog(
    BuildContext context,
    Map<String, dynamic> procedure,
    Future<void> Function() onStatusChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => _ProcedureStatusDialog(
        procedure: procedure,
        currentStatus: procedure['status'] as String?,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

  Future<void> _showAssignDateDialogForProcedure(
    Map<String, dynamic> procedure,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AssignProcedureDateDialog(procedure: procedure),
    );

    if (result != null && mounted) {
      // Reload all data after assignment
      await _loadAllData();
    }
  }

  // Old method - kept for reference but not used
  // Old method removed - using _buildCombinedList instead
  /*
  Widget _buildSurgeriesList() {
    if (_selectedTab == 0) {
      // Upcoming tab: Show today's surgeries first, then upcoming
      final filteredToday = _applySearchFilter(_todaySurgeries);
      final filteredUpcoming = _applySearchFilter(_upcomingSurgeries);

      return RefreshIndicator(
        onRefresh: () async {
          await _loadSurgeries(isInitialLoad: false);
        },
        child: filteredToday.isEmpty && filteredUpcoming.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const Center(
                      child: Text(
                        'No upcoming surgeries',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                        onStatusChange: () => _loadAllData(),
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
                        onStatusChange: () => _loadAllData(),
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

      return RefreshIndicator(
        onRefresh: () async {
          await _loadSurgeries(isInitialLoad: false);
        },
        child: filtered.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Text(
                        _selectedTab == 2
                            ? 'No unassigned surgeries'
                            : 'No finished surgeries',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final surgery = filtered[index];
                  return _SurgeryCard(
                    name: surgery['name'] as String,
                    procedure: surgery['procedure'] as String,
                    date: surgery['formatted_date'] as String,
                    isUnassigned: _selectedTab == 1,
                    onAssign: _selectedTab == 1
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
  */

  Future<void> _showAssignDateDialog(Map<String, dynamic> surgery) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AssignDateDialog(surgery: surgery),
    );

    if (result != null && mounted) {
      // Reload all data after assignment
      await _loadAllData();
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
  final Future<void> Function()? onStatusChange;

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
        onTap: surgery != null && surgery!['id'] != null
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        SurgeryDetailsPage(surgeryId: surgery!['id'] as int),
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
            // Middle column: Name, Surgery, Date/Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First row: Name and Status button aligned
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
                      // Status button/label aligned with name
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
                            'Schedule',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (!isUnassigned &&
                          surgery != null &&
                          (isTodaysSurgery ||
                              (status != null &&
                                  (status!.toUpperCase() == 'RESCHEDULED' ||
                                      status!.toUpperCase() == 'SCHEDULED' ||
                                      status!.toUpperCase() == 'SHEDULED' ||
                                      status!.toUpperCase() == 'ONGOING'))) &&
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
                      else if (!isUnassigned &&
                          surgery != null &&
                          !isTodaysSurgery &&
                          status != null &&
                          status!.toUpperCase() != 'RESCHEDULED' &&
                          status!.toUpperCase() != 'SCHEDULED' &&
                          status!.toUpperCase() != 'SHEDULED' &&
                          status!.toUpperCase() != 'ONGOING')
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
                  const SizedBox(height: 4),
                  // Surgery Name with label
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Surgery',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          procedure,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
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

      print('✅ Assign Date API Response Status: ${response.statusCode}');
      print('✅ Assign Date API Response Data: ${response.data}');

      // Check HTTP status code and response body status field (if it exists)
      // If status field doesn't exist, treat HTTP 200 as success
      // If status field exists and is false, treat as error
      final hasStatusField = response.data != null &&
          response.data is Map &&
          response.data.containsKey('status');
      final isStatusFalse = hasStatusField && response.data['status'] == false;

      if (response.statusCode == 200 && !isStatusFalse && mounted) {
        Navigator.of(context).pop({'success': true});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Surgery date assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Extract error message from response body
        final errorMsg = response.data?['message'] ??
            'Failed to assign date';
        throw Exception(errorMsg);
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

class _AssignProcedureDateDialog extends StatefulWidget {
  const _AssignProcedureDateDialog({required this.procedure});

  final Map<String, dynamic> procedure;

  @override
  State<_AssignProcedureDateDialog> createState() =>
      _AssignProcedureDateDialogState();
}

class _AssignProcedureDateDialogState
    extends State<_AssignProcedureDateDialog> {
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

      print('✅ Assign Date API Response Status: ${response.statusCode}');
      print('✅ Assign Date API Response Data: ${response.data}');

      // Check both HTTP status code AND response body status field
      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['status'] == true &&
          mounted) {
        Navigator.of(context).pop({'success': true});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Procedure date assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Extract error message from response body
        final errorMsg = response.data?['message'] ??
            'Failed to assign date';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error assigning procedure date: $e');
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
  final Future<void> Function() onStatusChanged;

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
        // Await the callback to ensure data is refreshed
        await widget.onStatusChanged();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to $_selectedStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Extract error message from response body
        final errorMsg = response.data?['message'] ??
            'Failed to update status';
        throw Exception(errorMsg);
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

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.surgery, required this.onRescheduled});

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
      final isoDate = dateTime.toIso8601String().split(
        '.',
      )[0]; // Remove milliseconds

      final surgeryId = widget.surgery['id'] as int;
      final response = await ApiMethods.rescheduleSurgery(
        surgeryId: surgeryId,
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
            content: Text('Surgery rescheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Extract error message from response body
        final errorMsg = response.data?['message'] ??
            'Failed to reschedule surgery';
        throw Exception(errorMsg);
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
                    Icon(
                      Icons.calendar_today,
                      color: AppColors.primary,
                      size: 20,
                    ),
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
                    Icon(Icons.access_time, color: AppColors.primary, size: 20),
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
          child: const Text('Cancel'),
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

class _ProcedureStatusDialog extends StatefulWidget {
  const _ProcedureStatusDialog({
    required this.procedure,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> procedure;
  final String? currentStatus;
  final Future<void> Function() onStatusChanged;

  @override
  State<_ProcedureStatusDialog> createState() => _ProcedureStatusDialogState();
}

class _ProcedureStatusDialogState extends State<_ProcedureStatusDialog> {
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

      // Check HTTP status code and response body status field (if it exists)
      // If status field doesn't exist, treat HTTP 200 as success
      // If status field exists and is false, treat as error
      final hasStatusField = response.data != null &&
          response.data is Map &&
          response.data.containsKey('status');
      final isStatusFalse = hasStatusField && response.data['status'] == false;

      if (response.statusCode == 200 && !isStatusFalse && mounted) {
        Navigator.of(context).pop();
        // Await the callback to ensure data is refreshed
        await widget.onStatusChanged();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to $_selectedStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
