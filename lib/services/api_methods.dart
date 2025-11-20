import 'package:dio/dio.dart';
import 'api_service.dart';

class ApiMethods {
  static final ApiService _api = ApiService();

  // ========== AUTHENTICATION ==========

  /// Login Verification
  /// POST /auth/login/login-verification
  /// Response: {status: true, message: "Login successful", result: {email, role, full_name, avatar, token}}
  static Future<Response> loginVerification({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/login/login-verification',
      data: {'email': email, 'password': password},
    );

    // Handle response format: {status, message, result: {token, ...}}
    if (response.data['status'] == true &&
        response.data['result'] != null &&
        response.data['result']['token'] != null) {
      _api.setToken(response.data['result']['token']);
    }

    return response;
  }

  /// Logout
  /// POST /auth/logout
  static Future<Response> logout() async {
    final response = await _api.post('/auth/logout');
    _api.clearToken();
    return response;
  }

  /// Refresh Token
  /// POST /auth/refresh
  static Future<Response> refreshToken(String refreshToken) async {
    return await _api.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
  }

  // ========== PROFILE ==========

  /// Get User Profile Data
  /// GET /v1/user/get-profile-data/{userId}
  /// Requires Authorization token
  static Future<Response> getProfileData(int userId) async {
    return await _api.get('/v1/user/get-profile-data/$userId');
  }

  /// Get User Profile (legacy)
  /// GET /profile
  static Future<Response> getProfile() async {
    return await _api.get('/profile');
  }

  /// Update User Profile
  /// PUT /v1/user/update-user/{userId}
  /// Requires Authorization token
  static Future<Response> updateUserProfile({
    required int userId,
    String? email,
    String? role,
    String? fullName,
    String? department,
    String? userAccess,
    String? phoneNumber,
    String? description,
    String? gender,
    String? joiningDate,
  }) async {
    final data = <String, dynamic>{'user_id': userId.toString()};

    // Only add fields if they are not null and not empty
    if (email != null && email.isNotEmpty) data['email'] = email;
    if (role != null && role.isNotEmpty) data['role'] = role;
    if (fullName != null && fullName.isNotEmpty) data['full_name'] = fullName;
    if (department != null && department.isNotEmpty)
      data['department'] = department;
    if (userAccess != null && userAccess.isNotEmpty)
      data['user_access'] = userAccess;
    if (phoneNumber != null && phoneNumber.isNotEmpty)
      data['phone_number'] = phoneNumber;
    if (description != null && description.isNotEmpty)
      data['description'] = description;
    if (gender != null && gender.isNotEmpty) data['gender'] = gender;
    if (joiningDate != null && joiningDate.isNotEmpty)
      data['joining_date'] = joiningDate;

    return await _api.put('/v1/user/update-user/$userId', data: data);
  }

  /// Update User Profile (legacy)
  /// PUT /profile
  static Future<Response> updateProfile({
    String? name,
    String? designation,
    String? phoneNumber,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (designation != null) data['designation'] = designation;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;

    return await _api.put('/profile', data: data);
  }

  /// Update Profile Image
  /// PATCH /v1/user/update-profile-image/{userId}
  /// Requires Authorization token
  /// Body: form-data with 'file' key
  static Future<Response> updateProfileImage({
    required int userId,
    required String imagePath,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imagePath),
    });

    return await _api.patch(
      '/v1/user/update-profile-image/$userId',
      data: formData,
    );
  }

  /// Upload Profile Image (legacy)
  /// POST /profile/image
  static Future<Response> uploadProfileImage(String imagePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imagePath),
    });

    return await _api.post('/profile/image', data: formData);
  }

  /// Change Password
  /// POST /profile/change-password
  static Future<Response> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await _api.post(
      '/profile/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  // ========== DASHBOARD ==========

  /// Get Dashboard Statistics
  /// GET /dashboard/stats
  static Future<Response> getDashboardStats() async {
    return await _api.get('/dashboard/stats');
  }

  // ========== APPOINTMENTS ==========

  /// Get All Bookings (Nurse endpoint - returns all bookings)
  /// GET /v1/nurse/get-all-bookings
  /// Requires Authorization token
  static Future<Response> getAllBookings() async {
    return await _api.get('/v1/nurse/get-upcomming-bookings');
  }

  /// Get Appointments List (filter by status only - then filter locally)
  /// GET /appointments?status=upcoming
  static Future<Response> getAppointments({
    String? status, // 'all', 'finished', 'upcoming'
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'all') {
      queryParams['status'] = status;
    }

    return await _api.get('/appointments', queryParams: queryParams);
  }

  /// Get Single Appointment
  /// GET /appointments/{appointmentId}
  static Future<Response> getAppointment(String appointmentId) async {
    return await _api.get('/appointments/$appointmentId');
  }

  /// Create Appointment
  /// POST /appointments
  static Future<Response> createAppointment({
    required String patientId,
    required String date,
    required String time,
    required String type,
    String? reason,
  }) async {
    return await _api.post(
      '/appointments',
      data: {
        'patientId': patientId,
        'date': date,
        'time': time,
        'type': type,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Update Appointment
  /// PUT /appointments/{appointmentId}
  static Future<Response> updateAppointment({
    required String appointmentId,
    String? date,
    String? time,
    String? type,
  }) async {
    final data = <String, dynamic>{};
    if (date != null) data['date'] = date;
    if (time != null) data['time'] = time;
    if (type != null) data['type'] = type;

    return await _api.put('/appointments/$appointmentId', data: data);
  }

  /// Cancel Appointment
  /// DELETE /appointments/{appointmentId}
  static Future<Response> cancelAppointment(String appointmentId) async {
    return await _api.delete('/appointments/$appointmentId');
  }

  // ========== SURGERIES ==========

  /// Get Surgeries List (filter by status only - then filter locally)
  /// GET /surgeries?status=ongoing
  static Future<Response> getSurgeries({
    String? status, // 'ongoing', 'finished', 'post_surgery'
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) {
      queryParams['status'] = status;
    }

    return await _api.get('/surgeries', queryParams: queryParams);
  }

  /// Get Surgery Details
  /// GET /surgeries/{surgeryId}
  static Future<Response> getSurgery(String surgeryId) async {
    return await _api.get('/surgeries/$surgeryId');
  }

  /// Update Surgery Status
  /// PATCH /surgeries/{surgeryId}/status
  static Future<Response> updateSurgeryStatus({
    required String surgeryId,
    required String status, // 'ongoing', 'finished', 'post_surgery'
  }) async {
    return await _api.patch(
      '/surgeries/$surgeryId/status',
      data: {'status': status},
    );
  }

  // ========== CONSULTATIONS ==========

  /// Get Video Consultations (filter by type only - then filter locally)
  /// GET /consultations?type=new
  static Future<Response> getConsultations({
    String? type, // 'all', 'new', 'followup'
  }) async {
    final queryParams = <String, dynamic>{};
    if (type != null && type != 'all') {
      queryParams['type'] = type;
    }

    return await _api.get('/consultations', queryParams: queryParams);
  }

  /// Get Consultation Details
  /// GET /consultations/{consultationId}
  static Future<Response> getConsultation(String consultationId) async {
    return await _api.get('/consultations/$consultationId');
  }

  /// Get Case History
  /// GET /consultations/{consultationId}/case-history
  static Future<Response> getCaseHistory(String consultationId) async {
    return await _api.get('/consultations/$consultationId/case-history');
  }

  /// Join Meeting
  /// POST /consultations/{consultationId}/join
  static Future<Response> joinConsultation(String consultationId) async {
    return await _api.post('/consultations/$consultationId/join');
  }

  /// Update Consultation Status
  /// PATCH /consultations/{consultationId}/status
  static Future<Response> updateConsultationStatus({
    required String consultationId,
    required String status, // 'confirmed', 'completed', 'cancelled'
  }) async {
    return await _api.patch(
      '/consultations/$consultationId/status',
      data: {'status': status},
    );
  }

  // ========== SETTINGS ==========

  /// Get User Settings
  /// GET /settings
  static Future<Response> getSettings() async {
    return await _api.get('/settings');
  }

  /// Update Theme
  /// PATCH /settings/theme
  static Future<Response> updateTheme(String theme) async {
    return await _api.patch('/settings/theme', data: {'theme': theme});
  }

  /// Update Notification Settings
  /// PATCH /settings/notifications
  static Future<Response> updateNotificationSettings({
    required bool enabled,
    bool? email,
    bool? push,
    bool? sms,
  }) async {
    final data = <String, dynamic>{'enabled': enabled};
    if (email != null) data['email'] = email;
    if (push != null) data['push'] = push;
    if (sms != null) data['sms'] = sms;

    return await _api.patch('/settings/notifications', data: data);
  }
}
