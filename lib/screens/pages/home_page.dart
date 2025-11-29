import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import '../../services/profile_manager.dart';
import 'appointment_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.userName});

  final String userName;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedTab = 0; // 0 = All, 1 = Today, 2 = Upcoming
  Set<String> _selectedFilters =
      {}; // Empty = All, can select: 'New', 'Follow-Up', 'Finished'
  Set<String> _selectedStatusFilters = {
    'PENDING',
  }; // Default: Only PENDING, can select: 'COMPLETED', 'PENDING', 'SURGERY_RECOMMENDED'
  Set<String> _selectedAppointmentModeFilters =
      {}; // Empty = All, can select: 'PHYSICAL', 'ONLINE'

  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  bool _isInitialLoad = true; // Track if this is the first load
  Timer? _refreshTimer;
  bool _isRefreshing = false; // Prevent multiple simultaneous refreshes
  String? _designation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('🏠 HomePage initState called');
    _loadDesignation();
    _loadAppointments(isInitialLoad: true);
    // Auto-refresh appointments every 40 seconds (only when screen is active)
    _refreshTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted && _isRouteActive()) {
        print('⏰ HomePage: Auto-refresh timer triggered');
        _loadAppointments(isInitialLoad: false);
      }
    });
    print('✅ Timer started (40 seconds interval)');
  }

  Future<void> _loadDesignation() async {
    try {
      // First try to get from local storage
      var profile = await ProfileManager.instance.getProfile();

      // If designation is not in local storage, fetch from API
      if (profile.designation == null || profile.designation!.isEmpty) {
        final userId = profile.userId;
        if (userId != null) {
          try {
            final response = await ApiMethods.getProfileData(userId);
            if (response.data['status'] == true &&
                response.data['result'] != null) {
              final result = response.data['result'] as Map<String, dynamic>;
              // Save profile data to local storage
              await ProfileManager.instance.saveProfileFromAPI(result);
              // Reload profile
              profile = await ProfileManager.instance.getProfile();
            }
          } catch (e) {
            print('Error fetching profile from API: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _designation = profile.designation;
        });
      }
    } catch (e) {
      print('Error loading designation: $e');
    }
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
      print('🔄 HomePage: App resumed, refreshing data');
      _loadAppointments(isInitialLoad: false);
    }
  }

  // Check if this route is currently active/visible
  bool _isRouteActive() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  Future<void> _loadAppointments({bool isInitialLoad = false}) async {
    // Prevent multiple simultaneous API calls
    if (_isRefreshing && !isInitialLoad) {
      print('⏸️ Refresh already in progress, skipping...');
      return;
    }

    print('🔄 _loadAppointments() called (isInitialLoad: $isInitialLoad)');

    // Only show loading indicator on initial load
    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
      });
    } else {
      // Mark as refreshing for background updates
      _isRefreshing = true;
    }

    try {
      print('📋 Getting profile...');
      // Get current user's ID
      final profile = await ProfileManager.instance.getProfile();
      print('✅ Profile loaded');

      // Use userId from profile
      final userId = profile.userId;

      print('=== LOADING APPOINTMENTS ===');
      print('Current User ID: $userId (from profile: ${profile.userId})');
      print('Profile data: userId=${profile.userId}, email=${profile.email}');

      if (profile.userId == null) {
        print('⚠️ WARNING: Profile userId is null, user may need to re-login');
        // If no userId, we can't load appointments - user should re-login
        setState(() {
          _appointments = [];
          if (isInitialLoad) {
            _isLoading = false;
            _isInitialLoad = false;
          }
        });
        return;
      }

      // Fetch all bookings from API
      print('📡 Calling API: /v1/nurse/get-all-bookings');
      print('   Base URL should be: https://assana-test.vercel.app');
      final response = await ApiMethods.getAllBookings();
      print('✅ API call completed');
      print('📥 API Response Status Code: ${response.statusCode}');
      print('📥 API Response Data: ${response.data}');
      print('📥 API Response Data Type: ${response.data.runtimeType}');

      if (response.data['status'] == true && response.data['result'] != null) {
        final bookings = response.data['result'] as List<dynamic>;
        print('✅ API Success: Found ${bookings.length} total bookings');

        // Show all bookings from API (no filtering)
        print('📋 Total bookings from API: ${bookings.length}');

        // Only exclude deleted bookings
        final filteredBookings = bookings
            .where((booking) => booking['is_deleted'] != true)
            .toList();

        print('✅ After excluding deleted: ${filteredBookings.length} bookings');

        // Print sample booking data
        if (filteredBookings.isNotEmpty) {
          print('📋 Sample booking data:');
          print('   First booking: ${filteredBookings.first}');
        }

        // Transform API data to our appointment format
        final appointments = filteredBookings.map((booking) {
          // Parse booking_time to extract date and time
          final bookingTime = booking['booking_time'] as String?;
          DateTime? dateTime;
          String timeStr = '';
          String dateStr = '';

          print('   Processing booking ID: ${booking['id']}');
          print('   - assigned_doctor_id: ${booking['assigned_doctor_id']}');
          print('   - booking_time: $bookingTime');
          print('   - appointment_type: ${booking['appointment_type']}');
          print('   - status: ${booking['status']}');

          if (bookingTime != null && bookingTime.isNotEmpty) {
            try {
              // Parse the date string - handle timezone issues
              dateTime = DateTime.parse(bookingTime);
              // Convert to local timezone for display
              dateTime = dateTime.toLocal();
              print(
                '   - Parsed dateTime (UTC): ${DateTime.parse(bookingTime)}',
              );
              print('   - Parsed dateTime (Local): $dateTime');
              print('   - Current device time: ${DateTime.now()}');
              print(
                '   - Device timezone offset: ${DateTime.now().timeZoneOffset}',
              );

              // Format time as HH:MM AM/PM
              final hour = dateTime.hour;
              final minute = dateTime.minute;
              final period = hour >= 12 ? 'PM' : 'AM';
              final displayHour = hour > 12
                  ? hour - 12
                  : (hour == 0 ? 12 : hour);
              timeStr =
                  '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
              // Format date - use local date
              dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
              print('   - Formatted date: $dateStr');
              print('   - Formatted time: $timeStr');
            } catch (e) {
              print('   ❌ Error parsing booking_time "$bookingTime": $e');
              print('   ❌ Stack trace: ${StackTrace.current}');
              // Set a fallback date to prevent empty date strings
              dateStr =
                  '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
            }
          } else {
            print('   ⚠️ booking_time is null or empty');
            // Set a fallback date to prevent empty date strings
            dateStr =
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
          }

          // Map appointment_type to type
          final appointmentType = booking['appointment_type'] as String? ?? '';
          String type = 'Consultation';
          if (appointmentType.toUpperCase() == 'FOLLOWUP') {
            type = 'Follow-Up';
          } else if (appointmentType.isNotEmpty) {
            type = appointmentType;
          }

          // Map status from API to our status format
          // Priority: appointment_type (FOLLOWUP) -> status (PENDING/COMPLETED)
          final apiStatus = booking['status'] as String? ?? 'PENDING';
          String status = 'New';

          // If appointment_type is FOLLOWUP, status should be Follow-Up
          if (appointmentType.toUpperCase() == 'FOLLOWUP') {
            status = 'Follow-Up';
          }
          // If status is COMPLETED or FINISHED, or patient visited, it's Finished
          else if (apiStatus.toUpperCase() == 'COMPLETED' ||
              apiStatus.toUpperCase() == 'FINISHED' ||
              booking['is_patient_visited'] == true) {
            status = 'Finished';
          }
          // Otherwise (PENDING, CONFIRMED, etc.) it's New
          else {
            status = 'New';
          }

          print(
            '   - Mapped status: $status (from API status: $apiStatus, type: $appointmentType)',
          );
          print('   - Mapped type: $type');

          // Ensure dateStr is never empty - use current date as fallback
          if (dateStr.isEmpty) {
            final now = DateTime.now();
            dateStr = '${now.day}/${now.month}/${now.year}';
            print('   ⚠️ Using fallback date: $dateStr');
          }

          final appointment = {
            'name': booking['patient_name'] ?? 'Unknown',
            'id': '#${booking['patient_id'] ?? booking['id'] ?? ''}',
            'time': timeStr,
            'date': dateStr,
            'type': type,
            'status': status, // For display (New, Follow-Up, Finished)
            'api_status': apiStatus
                .toUpperCase(), // Original API status for filtering
            'avatar': Icons.person,
            'booking_id': booking['id'],
            'patient_id': booking['patient_id'],
            'issues': booking['issues'] ?? '',
            'original_booking_time': bookingTime, // Keep original for debugging
          };

          print('   ✅ Created appointment: $appointment\n');
          return appointment;
        }).toList();

        print('✅ Transformed to ${appointments.length} appointments');
        if (appointments.isNotEmpty) {
          print('📋 Sample appointment:');
          print('   Name: ${appointments.first['name']}');
          print('   ID: ${appointments.first['id']}');
          print('   Date: ${appointments.first['date']}');
          print('   Time: ${appointments.first['time']}');
          print('   Status: ${appointments.first['status']}');
          print('   Type: ${appointments.first['type']}');
        }

        // Update state - only set loading to false on initial load
        // Only update if data actually changed to avoid unnecessary rebuilds
        final hasChanged =
            _appointments.length != appointments.length ||
            !_appointments.every(
              (apt) => appointments.any(
                (newApt) => newApt['booking_id'] == apt['booking_id'],
              ),
            );

        if (hasChanged || isInitialLoad) {
          setState(() {
            _appointments = appointments;
            if (isInitialLoad) {
              _isLoading = false;
              _isInitialLoad = false;
            }
          });
        }

        print(
          '✅ Appointments loaded successfully! (${appointments.length} appointments)',
        );
        print('=== END LOADING APPOINTMENTS ===\n');
      } else {
        print('❌ API returned error or no data:');
        print('   Status: ${response.data['status']}');
        print('   Message: ${response.data['message']}');
        print('   Result: ${response.data['result']}');
        print('   Result is null: ${response.data['result'] == null}');
        setState(() {
          _appointments = [];
          if (isInitialLoad) {
            _isLoading = false;
            _isInitialLoad = false;
          }
        });
        print('=== END LOADING APPOINTMENTS ===\n');
      }
    } on DioException catch (e) {
      print('❌ DioException Error loading appointments:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      if (e.response != null) {
        print('   Status Code: ${e.response?.statusCode}');
        print('   Response Data: ${e.response?.data}');
      }

      String errorMessage = 'Failed to load appointments';

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
        _isLoading = false;
        _isInitialLoad = false;
        _isRefreshing = false; // Reset refreshing flag on error
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      print('=== END LOADING APPOINTMENTS ===\n');
    } catch (e) {
      print('❌ General Error loading appointments: $e');
      print('   Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
        _isRefreshing = false; // Reset refreshing flag on error
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      print('=== END LOADING APPOINTMENTS ===\n');
    } finally {
      // Always reset refreshing flag
      _isRefreshing = false;
    }
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    // Start with all appointments
    var filtered = List<Map<String, dynamic>>.from(_appointments);

    // Apply tab filter (All, Today, or Upcoming)
    final today = DateTime.now();
    final todayStr = '${today.day}/${today.month}/${today.year}';

    if (_selectedTab == 1) {
      // Today tab - show only today's appointments
      filtered = filtered.where((appointment) {
        final aptDate = appointment['date'] as String? ?? '';
        return aptDate == todayStr;
      }).toList();
    } else if (_selectedTab == 2) {
      // Upcoming tab - show only future appointments
      filtered = filtered.where((appointment) {
        final aptDate = appointment['date'] as String? ?? '';
        if (aptDate.isEmpty) return false;
        try {
          final parts = aptDate.split('/');
          if (parts.length == 3) {
            final aptDateTime = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            final todayStart = DateTime(today.year, today.month, today.day);
            final aptDateStart = DateTime(
              aptDateTime.year,
              aptDateTime.month,
              aptDateTime.day,
            );
            return aptDateStart.isAfter(todayStart);
          }
        } catch (e) {
          return false;
        }
        return false;
      }).toList();
    }
    // _selectedTab == 0 (All) - no date filtering

    // Apply appointment type filters if any are selected
    if (_selectedFilters.isNotEmpty) {
      filtered = filtered.where((appointment) {
        return _selectedFilters.contains(appointment['status'] as String);
      }).toList();
    }

    // Apply API status filters (COMPLETED, PENDING, SURGERY_RECOMMENDED)
    if (_selectedStatusFilters.isNotEmpty) {
      filtered = filtered.where((appointment) {
        final apiStatus = appointment['api_status'] as String? ?? '';
        return _selectedStatusFilters.contains(apiStatus);
      }).toList();
    }

    // Apply appointment mode filters (PHYSICAL, ONLINE) - all are PHYSICAL for now
    if (_selectedAppointmentModeFilters.isNotEmpty) {
      filtered = filtered.where((appointment) {
        // Currently all appointments are considered PHYSICAL
        // If PHYSICAL is selected, show all (since all are physical)
        // If ONLINE is selected, show none (since none are online yet)
        if (_selectedAppointmentModeFilters.contains('PHYSICAL')) {
          return true; // All appointments are physical
        }
        return false; // No online appointments yet
      }).toList();
    }

    // Sort appointments by date
    filtered.sort((a, b) {
      final aDate = a['date'] as String? ?? '';
      final bDate = b['date'] as String? ?? '';

      // If both are today or both are not today, sort by date
      if (aDate.isNotEmpty && bDate.isNotEmpty) {
        try {
          final aParts = aDate.split('/');
          final bParts = bDate.split('/');
          if (aParts.length == 3 && bParts.length == 3) {
            final aDateTime = DateTime(
              int.parse(aParts[2]),
              int.parse(aParts[1]),
              int.parse(aParts[0]),
            );
            final bDateTime = DateTime(
              int.parse(bParts[2]),
              int.parse(bParts[1]),
              int.parse(bParts[0]),
            );
            return aDateTime.compareTo(bDateTime);
          }
        } catch (e) {
          // If parsing fails, keep original order
        }
      }

      return 0;
    });

    return filtered;
  }

  String _formatAppointmentDate(String dateStr) {
    if (dateStr.isEmpty) return 'Date not set';

    final today = DateTime.now();
    final todayStr = '${today.day}/${today.month}/${today.year}';

    // If it's today, return "Today"
    if (dateStr == todayStr) {
      return 'Today';
    }

    // Otherwise, format the date nicely
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

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

        return '$day ${months[month - 1]} $year';
      }
    } catch (e) {
      // If parsing fails, return the original string
      return dateStr;
    }

    return dateStr;
  }

  String _getCurrentDateString() {
    final now = DateTime.now();
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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

    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final day = now.day;

    return '$weekday, $month $day';
  }

  void _clearAllFilters() {
    setState(() {
      _selectedFilters.clear();
      _selectedStatusFilters.clear();
      _selectedAppointmentModeFilters.clear();
    });
  }

  void _showFilterMenu() {
    // Create a local copy of selected filters for the bottom sheet
    Set<String> tempFilters = Set<String>.from(_selectedFilters);
    Set<String> tempStatusFilters = Set<String>.from(_selectedStatusFilters);
    Set<String> tempAppointmentModeFilters = Set<String>.from(
      _selectedAppointmentModeFilters,
    );

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
                          'Filter Appointments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Clear filters button in drawer
                      if (tempFilters.isNotEmpty ||
                          tempStatusFilters.isNotEmpty ||
                          tempAppointmentModeFilters.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              tempFilters.clear();
                              tempStatusFilters.clear();
                              tempAppointmentModeFilters.clear();
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
                        // Filter by Appointment Mode (First)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Appointment Mode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // All option for appointment mode
                        ListTile(
                          leading: Icon(
                            Icons.list,
                            color: tempAppointmentModeFilters.isEmpty
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('All'),
                          trailing: tempAppointmentModeFilters.isEmpty
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setModalState(() {
                              tempAppointmentModeFilters.clear();
                            });
                          },
                        ),
                        // Physical option
                        ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color:
                                tempAppointmentModeFilters.contains('PHYSICAL')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Physical'),
                          trailing: Checkbox(
                            value: tempAppointmentModeFilters.contains(
                              'PHYSICAL',
                            ),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempAppointmentModeFilters.add('PHYSICAL');
                                } else {
                                  tempAppointmentModeFilters.remove('PHYSICAL');
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                        // Online option
                        ListTile(
                          leading: Icon(
                            Icons.video_call,
                            color: tempAppointmentModeFilters.contains('ONLINE')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Online'),
                          trailing: Checkbox(
                            value: tempAppointmentModeFilters.contains(
                              'ONLINE',
                            ),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempAppointmentModeFilters.add('ONLINE');
                                } else {
                                  tempAppointmentModeFilters.remove('ONLINE');
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const Divider(),
                        // Filter by Status (Second)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // All option for status
                        ListTile(
                          leading: Icon(
                            Icons.list,
                            color: tempStatusFilters.isEmpty
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('All'),
                          trailing: tempStatusFilters.isEmpty
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setModalState(() {
                              tempStatusFilters.clear();
                            });
                          },
                        ),
                        // PENDING option
                        ListTile(
                          leading: Icon(
                            Icons.pending,
                            color: tempStatusFilters.contains('PENDING')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Pending'),
                          trailing: Checkbox(
                            value: tempStatusFilters.contains('PENDING'),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempStatusFilters.add('PENDING');
                                } else {
                                  tempStatusFilters.remove('PENDING');
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                        // COMPLETED option
                        ListTile(
                          leading: Icon(
                            Icons.check_circle,
                            color: tempStatusFilters.contains('COMPLETED')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Completed'),
                          trailing: Checkbox(
                            value: tempStatusFilters.contains('COMPLETED'),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempStatusFilters.add('COMPLETED');
                                } else {
                                  tempStatusFilters.remove('COMPLETED');
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                        // SURGERY_RECOMMENDED option
                        ListTile(
                          leading: Icon(
                            Icons.medical_services,
                            color:
                                tempStatusFilters.contains(
                                  'SURGERY_RECOMMENDED',
                                )
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Surgery Recommended'),
                          trailing: Checkbox(
                            value: tempStatusFilters.contains(
                              'SURGERY_RECOMMENDED',
                            ),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempStatusFilters.add('SURGERY_RECOMMENDED');
                                } else {
                                  tempStatusFilters.remove(
                                    'SURGERY_RECOMMENDED',
                                  );
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const Divider(),
                        // Filter by Appointment Type (Last)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Appointment Type',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // All option for appointment type
                        ListTile(
                          leading: Icon(
                            Icons.list,
                            color: tempFilters.isEmpty
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('All'),
                          trailing: tempFilters.isEmpty
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setModalState(() {
                              tempFilters.clear();
                            });
                          },
                        ),
                        // New option
                        ListTile(
                          leading: Icon(
                            Icons.fiber_new,
                            color: tempFilters.contains('New')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('New'),
                          trailing: Checkbox(
                            value: tempFilters.contains('New'),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempFilters.add('New');
                                } else {
                                  tempFilters.remove('New');
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                        // Follow-Up option
                        ListTile(
                          leading: Icon(
                            Icons.update,
                            color: tempFilters.contains('Follow-Up')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Follow-Up'),
                          trailing: Checkbox(
                            value: tempFilters.contains('Follow-Up'),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempFilters.add('Follow-Up');
                                } else {
                                  tempFilters.remove('Follow-Up');
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
                          _selectedFilters = Set<String>.from(tempFilters);
                          _selectedStatusFilters = Set<String>.from(
                            tempStatusFilters,
                          );
                          _selectedAppointmentModeFilters = Set<String>.from(
                            tempAppointmentModeFilters,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header section with pink background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEF7684),
                  Color(0xFFEB5466), // #EB5466
                  // #EF7684
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome Back',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.userName.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_designation != null &&
                              _designation!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _designation!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Container(
                    //   padding: const EdgeInsets.all(10),
                    //   decoration: BoxDecoration(
                    //     color: Colors.white.withValues(alpha: 0.2),
                    //     shape: BoxShape.circle,
                    //   ),
                    //   child: const Icon(
                    //     Icons.notifications_outlined,
                    //     color: Colors.white,
                    //     size: 24,
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 20),
                // Date and appointments card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFEF7684), // Lighter pink
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCurrentDateString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Total Appointments',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${_appointments.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
          // Today's Schedule section
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Reset error state and reload
                setState(() {
                  _isRefreshing = false;
                });
                await _loadAppointments(isInitialLoad: true);
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Appointments",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Clear filters button
                            if (_selectedFilters.isNotEmpty ||
                                _selectedStatusFilters.isNotEmpty ||
                                _selectedAppointmentModeFilters.isNotEmpty)
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
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.filter_list,
                                color:
                                    (_selectedFilters.isNotEmpty ||
                                        _selectedStatusFilters.isNotEmpty ||
                                        _selectedAppointmentModeFilters
                                            .isNotEmpty)
                                    ? AppColors.primary
                                    : Colors.grey,
                              ),
                              onPressed: _showFilterMenu,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Tabs for All, Today, and Upcoming
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTab = 0;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedTab == 0
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'All',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 0
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTab = 1;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedTab == 1
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Today',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 1
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTab = 2;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 2
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedTab == 2
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Upcoming',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 2
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Loading indicator or Appointment cards
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_filteredAppointments.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No appointments found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._filteredAppointments.map((appointment) {
                        final bookingId = appointment['booking_id'] as int?;
                        print('📋 Appointment card - booking_id: $bookingId');
                        return InkWell(
                          onTap: bookingId != null
                              ? () {
                                  print(
                                    '🔵 Clicked appointment with booking_id: $bookingId',
                                  );
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AppointmentDetailsPage(
                                            bookingId: bookingId,
                                          ),
                                    ),
                                  );
                                }
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        appointment['avatar'] as IconData,
                                        color: AppColors.primary,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            appointment['name'] as String,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF333333),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'ID: ${appointment['id']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          // Issues row (below ID)
                                          if (appointment['issues'] != null &&
                                              (appointment['issues'] as String)
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/images/stethoscope.svg',
                                                  width: 14,
                                                  height: 14,
                                                  colorFilter: ColorFilter.mode(
                                                    AppColors.primary,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    appointment['issues']
                                                        as String,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          // Date and Time in same row
                                          Row(
                                            children: [
                                              // Date
                                              Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatAppointmentDate(
                                                  appointment['date']
                                                          as String? ??
                                                      '',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              // Time
                                              Icon(
                                                Icons.access_time_filled,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                appointment['time'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Appointment Type badge at top right
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      appointment['type'] as String? ??
                                          'Consultation',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
