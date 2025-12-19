import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import '../../services/profile_manager.dart';
import 'appointment_details_page.dart';
import 'medical_report_viewer_page.dart';

class MeetPage extends StatefulWidget {
  const MeetPage({super.key});

  @override
  State<MeetPage> createState() => _MeetPageState();
}

class _MeetPageState extends State<MeetPage> with WidgetsBindingObserver {
  int _selectedTab = 0; // 0: All, 1: New, 2: Follow-up
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;

  // Filter states
  String? _selectedTimeFilter; // null = All, 'today', 'upcoming'
  Set<String> _selectedStatusFilters = {}; // 'PENDING', 'COMPLETED', etc.

  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppointments(isInitialLoad: true);
    // Auto-refresh appointments every 40 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted && _isRouteActive()) {
        _loadAppointments(isInitialLoad: false);
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
    if (state == AppLifecycleState.resumed && mounted && _isRouteActive()) {
      _loadAppointments(isInitialLoad: false);
    }
  }

  bool _isRouteActive() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  Future<void> _loadAppointments({bool isInitialLoad = false}) async {
    if (_isRefreshing && !isInitialLoad) {
      return;
    }

    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
      });
    } else {
      _isRefreshing = true;
    }

    try {
      final profile = await ProfileManager.instance.getProfile();
      final userId = profile.userId;

      if (userId == null) {
        setState(() {
          _appointments = [];
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
        return;
      }

      final response = await ApiMethods.getAllBookings();

      if (response.data['status'] == true && response.data['result'] != null) {
        final bookings = response.data['result'] as List<dynamic>;

        // Filter for ONLINE appointments only
        final onlineBookings = bookings.where((booking) {
          final isDeleted = booking['is_deleted'] == true;
          final appointmentMode = booking['appointment_mode'] as String?;
          return !isDeleted && 
                 appointmentMode != null && 
                 appointmentMode.toUpperCase() == 'ONLINE';
        }).toList();

        // Transform API data to our appointment format
        final appointments = onlineBookings.map((booking) {
          final bookingTime = booking['booking_time'] as String?;
          DateTime? dateTime;
          String timeStr = '';
          String dateStr = '';

          if (bookingTime != null && bookingTime.isNotEmpty) {
            try {
              dateTime = DateTime.parse(bookingTime).toLocal();
              final hour = dateTime.hour;
              final minute = dateTime.minute;
              final period = hour >= 12 ? 'PM' : 'AM';
              final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
              timeStr = '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
              dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
            } catch (e) {
              dateStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
            }
          } else {
            dateStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
          }

          final appointmentType = booking['appointment_type'] as String? ?? '';
          String type = 'Consultation';
          if (appointmentType.toUpperCase() == 'FOLLOWUP') {
            type = 'Follow-Up';
          } else if (appointmentType.isNotEmpty) {
            type = appointmentType;
          }

          final apiStatus = booking['status'] as String? ?? 'PENDING';
          String status = 'New';
          if (appointmentType.toUpperCase() == 'FOLLOWUP') {
            status = 'Follow-Up';
          } else if (apiStatus.toUpperCase() == 'COMPLETED' ||
              apiStatus.toUpperCase() == 'FINISHED' ||
              booking['is_patient_visited'] == true) {
            status = 'Finished';
          } else {
            status = 'New';
          }

          if (dateStr.isEmpty) {
            final now = DateTime.now();
            dateStr = '${now.day}/${now.month}/${now.year}';
          }

          return {
            'name': booking['patient_name'] ?? 'Unknown',
            'id': '#${booking['patient_id'] ?? booking['id'] ?? ''}',
            'time': timeStr,
            'date': dateStr,
            'type': type,
            'status': status,
            'api_status': apiStatus.toUpperCase(),
            'avatar': Icons.person,
            'booking_id': booking['id'],
            'patient_id': booking['patient_id'],
            'issues': booking['issues'] ?? '',
            'original_booking_time': bookingTime,
            'formatted_date': _formatAppointmentDate(dateStr, timeStr),
          };
        }).toList();

        setState(() {
          _appointments = appointments;
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      } else {
        setState(() {
          _appointments = [];
          if (isInitialLoad) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      print('Error loading online appointments: $e');
      setState(() {
        _appointments = [];
        if (isInitialLoad) {
          _isLoading = false;
        }
      });
    } finally {
      _isRefreshing = false;
    }
  }

  String _formatAppointmentDate(String dateStr, String timeStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final dateTime = DateTime(year, month, day);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final appointmentDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

        if (appointmentDate == today) {
          return 'Today, $timeStr';
        } else if (appointmentDate == today.add(const Duration(days: 1))) {
          return 'Tomorrow, $timeStr';
        } else {
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
          return '${day} ${months[month - 1]} $year, $timeStr';
        }
      }
    } catch (e) {
      // If parsing fails, return original
    }
    return '$dateStr, $timeStr';
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    List<Map<String, dynamic>> filtered = List.from(_appointments);

    // Apply tab filter (by appointment type)
    if (_selectedTab == 1) {
      // New
      filtered = filtered.where((apt) {
        final type = apt['type'] as String? ?? '';
        return type != 'Follow-Up';
      }).toList();
    } else if (_selectedTab == 2) {
      // Follow-up
      filtered = filtered.where((apt) {
        final type = apt['type'] as String? ?? '';
        return type == 'Follow-Up';
      }).toList();
    }

    // Apply time filter
    if (_selectedTimeFilter == 'today') {
      final today = DateTime.now();
      filtered = filtered.where((apt) {
        final dateStr = apt['date'] as String? ?? '';
        try {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            final aptDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            return aptDate.year == today.year &&
                aptDate.month == today.month &&
                aptDate.day == today.day;
          }
        } catch (e) {
          // Ignore parsing errors
        }
        return false;
      }).toList();
    } else if (_selectedTimeFilter == 'upcoming') {
      final today = DateTime.now();
      filtered = filtered.where((apt) {
        final dateStr = apt['date'] as String? ?? '';
        try {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            final aptDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            final aptDateTime = DateTime(aptDate.year, aptDate.month, aptDate.day);
            final todayDateTime = DateTime(today.year, today.month, today.day);
            return aptDateTime.isAfter(todayDateTime);
          }
        } catch (e) {
          // Ignore parsing errors
        }
        return false;
      }).toList();
    }

    // Apply status filter
    if (_selectedStatusFilters.isNotEmpty) {
      filtered = filtered.where((appointment) {
        final apiStatus = appointment['api_status'] as String? ?? '';
        return _selectedStatusFilters.contains(apiStatus);
      }).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((appointment) {
        final name = (appointment['name'] as String? ?? '').toLowerCase();
        final type = (appointment['type'] as String? ?? '').toLowerCase();
        final status = (appointment['status'] as String? ?? '').toLowerCase();
        final time = (appointment['formatted_date'] as String? ?? '').toLowerCase();
        return name.contains(query) ||
            type.contains(query) ||
            status.contains(query) ||
            time.contains(query);
      }).toList();
    }

    // Sort by date
    filtered.sort((a, b) {
      final aDate = a['date'] as String? ?? '';
      final bDate = b['date'] as String? ?? '';
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
          // Ignore parsing errors
        }
      }
      return 0;
    });

    return filtered;
  }

  Future<void> _openMedicalReport(int bookingId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch appointment details
      final response = await ApiMethods.getBookingDetails(bookingId);

      Navigator.of(context).pop(); // Close loading dialog

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['status'] == true &&
          response.data['result'] != null) {
        final result = response.data['result'] as Map<String, dynamic>;
        final booking = result['booking'] as Map<String, dynamic>?;
        final appointmentHistory = result['appointment_history'] as List<dynamic>?;

        // First check booking object
        String? medicalReportLink =
            booking?['medical_report_link_unlocked'] as String?;
        if (medicalReportLink == null || medicalReportLink.isEmpty) {
          // If not found, check appointment_history (most recent appointment with report)
          if (appointmentHistory != null && appointmentHistory.isNotEmpty) {
            for (var appointment in appointmentHistory) {
              final link = appointment['medical_report_link_unlocked'] as String?;
              if (link != null && link.isNotEmpty) {
                medicalReportLink = link;
                break;
              }
            }
          }
        }

        if (medicalReportLink != null && medicalReportLink.isNotEmpty) {
          // Open medical report in WebView
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MedicalReportViewerPage(
                  reportUrl: medicalReportLink!,
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Medical report not available'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load appointment details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading medical report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinMeeting(int bookingId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch appointment details
      final response = await ApiMethods.getBookingDetails(bookingId);

      Navigator.of(context).pop(); // Close loading dialog

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['status'] == true &&
          response.data['result'] != null) {
        final result = response.data['result'] as Map<String, dynamic>;
        final meetData = result['meet_data'] as Map<String, dynamic>?;
        final meetingUrl = meetData?['meeting_url'] as String?;

        if (meetingUrl != null && meetingUrl.isNotEmpty) {
          // Open meeting URL in external browser
          try {
            final uri = Uri.parse(meetingUrl);
            print('🔗 Attempting to launch meeting URL: $meetingUrl');
            
            // Try to launch URL - canLaunchUrl can be unreliable, so we try anyway
            bool launched = false;
            if (await canLaunchUrl(uri)) {
              print('✅ canLaunchUrl returned true, launching...');
              launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              // Even if canLaunchUrl returns false, try launching anyway
              print('⚠️ canLaunchUrl returned false, but trying to launch anyway...');
              try {
                launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                print('❌ Error launching URL: $e');
                // Try with platformDefault mode as fallback
                try {
                  launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
                } catch (e2) {
                  print('❌ Error with platformDefault mode: $e2');
                }
              }
            }
            
            if (!launched && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not open meeting URL. Please try again.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            print('❌ Error parsing or launching URL: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error opening meeting: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Meeting URL not available'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load appointment details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining meeting: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedTimeFilter = null;
      _selectedStatusFilters.clear();
    });
  }

  void _showFilterMenu() {
    String? tempTimeFilter = _selectedTimeFilter;
    Set<String> tempStatusFilters = Set<String>.from(_selectedStatusFilters);

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
                      if (tempTimeFilter != null || tempStatusFilters.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              tempTimeFilter = null;
                              tempStatusFilters.clear();
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
                        // Filter by Time
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // All option for time
                        ListTile(
                          leading: Icon(
                            Icons.list,
                            color: tempTimeFilter == null
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('All'),
                          trailing: tempTimeFilter == null
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setModalState(() {
                              tempTimeFilter = null;
                            });
                          },
                        ),
                        // Today option
                        ListTile(
                          leading: Icon(
                            Icons.today,
                            color: tempTimeFilter == 'today'
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Today'),
                          trailing: tempTimeFilter == 'today'
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setModalState(() {
                              tempTimeFilter = 'today';
                            });
                          },
                        ),
                        // Upcoming option
                        ListTile(
                          leading: Icon(
                            Icons.upcoming,
                            color: tempTimeFilter == 'upcoming'
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Upcoming'),
                          trailing: tempTimeFilter == 'upcoming'
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setModalState(() {
                              tempTimeFilter = 'upcoming';
                            });
                          },
                        ),
                        const Divider(),
                        // Filter by Status
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
                        // PENDING
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
                        // COMPLETED
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
                        // SURGERY_RECOMMENDED
                        ListTile(
                          leading: Icon(
                            Icons.medical_services,
                            color: tempStatusFilters.contains('SURGERY_RECOMMENDED')
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          title: const Text('Surgery Recommended'),
                          trailing: Checkbox(
                            value: tempStatusFilters.contains('SURGERY_RECOMMENDED'),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempStatusFilters.add('SURGERY_RECOMMENDED');
                                } else {
                                  tempStatusFilters.remove('SURGERY_RECOMMENDED');
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // Apply button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedTimeFilter = tempTimeFilter;
                          _selectedStatusFilters = Set<String>.from(tempStatusFilters);
                        });
                        Navigator.of(context).pop();
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
                        'Apply Filters',
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
                      const SizedBox(width: 48),
                      const Text(
                        'Video Consultation',
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
                        hintText: 'Search by name, type, status, time...',
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
          // Filter tabs (by appointment type)
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
                    label: 'All',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                Expanded(
                  child: _FilterTab(
                    label: 'New',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
                Expanded(
                  child: _FilterTab(
                    label: 'Follow-up',
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                  ),
                ),
              ],
            ),
          ),
          // Title and Filter icon row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Online Appointments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                Row(
                  children: [
                    // Clear filters button (if filters are active)
                    if (_selectedTimeFilter != null || _selectedStatusFilters.isNotEmpty)
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
                    // Filter icon
                    IconButton(
                      icon: Stack(
                        children: [
                          Icon(
                            Icons.filter_list,
                            color: (_selectedTimeFilter != null || _selectedStatusFilters.isNotEmpty)
                                ? AppColors.primary
                                : Colors.grey.shade600,
                          ),
                          if (_selectedTimeFilter != null || _selectedStatusFilters.isNotEmpty)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: _showFilterMenu,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Appointment cards
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadAppointments(isInitialLoad: false),
                    child: _filteredAppointments.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isNotEmpty
                                  ? 'No appointments found'
                                  : 'No online appointments',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredAppointments.length,
              itemBuilder: (context, index) {
                final appointment = _filteredAppointments[index];
                              final bookingId = appointment['booking_id'] as int?;
                return _AppointmentCard(
                  name: appointment['name'] as String,
                                procedure: appointment['type'] as String,
                                time: appointment['formatted_date'] as String,
                  status: appointment['status'] as String?,
                                bookingId: bookingId,
                                onCardTap: bookingId != null
                                    ? () {
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
                                onCaseHistory: bookingId != null
                                    ? () => _openMedicalReport(bookingId)
                                    : null,
                                onJoinMeeting: bookingId != null
                                    ? () => _joinMeeting(bookingId)
                                    : null,
                              );
                            },
                          ),
            ),
          ),
        ],
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

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({
    required this.name,
    required this.procedure,
    required this.time,
    required this.bookingId,
    this.status,
    this.onCardTap,
    this.onCaseHistory,
    this.onJoinMeeting,
  });

  final String name;
  final String procedure;
  final String time;
  final int? bookingId;
  final String? status;
  final VoidCallback? onCardTap;
  final VoidCallback? onCaseHistory;
  final VoidCallback? onJoinMeeting;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _isExpanded = false;

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
        onTap: widget.onCardTap,
        borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Row(
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
                            widget.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            widget.procedure,
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
                                  widget.time,
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
                // Expand/Collapse button
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(
                      _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: 24,
                  ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  ),
              ),
            ],
          ),
            if (_isExpanded) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                      onPressed: widget.onCaseHistory,
                    icon: Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    label: Text(
                      'Case History',
                      style: TextStyle(color: AppColors.primary, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                      onPressed: widget.onJoinMeeting,
                    icon: const Icon(
                      Icons.videocam,
                      color: Colors.white,
                      size: 26,
                    ),
                    label: const Text(
                      'Join Meeting',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }
}
