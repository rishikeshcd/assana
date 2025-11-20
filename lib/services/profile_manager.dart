import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  const UserProfile({
    this.userId,
    this.email,
    this.role,
    this.fullName,
    this.avatar,
    this.name,
    this.designation,
    this.phoneNumber,
    this.profileImageUrl,
    this.department,
    this.userAccess,
    this.gender,
    this.joiningDate,
  });

  final int? userId;
  final String? email;
  final String? role;
  final String? fullName;
  final String? avatar;
  final String? name;
  final String? designation;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String? department;
  final String? userAccess;
  final String? gender;
  final String? joiningDate;

  UserProfile copyWith({
    int? userId,
    String? email,
    String? role,
    String? fullName,
    String? avatar,
    String? name,
    String? designation,
    String? phoneNumber,
    String? profileImageUrl,
    String? department,
    String? userAccess,
    String? gender,
    String? joiningDate,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      avatar: avatar ?? this.avatar,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      department: department ?? this.department,
      userAccess: userAccess ?? this.userAccess,
      gender: gender ?? this.gender,
      joiningDate: joiningDate ?? this.joiningDate,
    );
  }
}

class ProfileManager {
  ProfileManager._();

  static const _keyUserId = 'profile_user_id';
  static const _keyEmail = 'profile_email';
  static const _keyRole = 'profile_role';
  static const _keyFullName = 'profile_full_name';
  static const _keyAvatar = 'profile_avatar';
  static const _keyName = 'profile_name';
  static const _keyDesignation = 'profile_designation';
  static const _keyPhoneNumber = 'profile_phone_number';
  static const _keyProfileImageUrl = 'profile_image_url';
  static const _keyDepartment = 'profile_department';
  static const _keyUserAccess = 'profile_user_access';
  static const _keyGender = 'profile_gender';
  static const _keyJoiningDate = 'profile_joining_date';

  static final ProfileManager instance = ProfileManager._();

  /// Load profile from local storage
  Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      userId: prefs.getInt(_keyUserId),
      email: prefs.getString(_keyEmail),
      role: prefs.getString(_keyRole),
      fullName: prefs.getString(_keyFullName),
      avatar: prefs.getString(_keyAvatar),
      name: prefs.getString(_keyName),
      designation: prefs.getString(_keyDesignation),
      phoneNumber: prefs.getString(_keyPhoneNumber),
      profileImageUrl: prefs.getString(_keyProfileImageUrl),
      department: prefs.getString(_keyDepartment),
      userAccess: prefs.getString(_keyUserAccess),
      gender: prefs.getString(_keyGender),
      joiningDate: prefs.getString(_keyJoiningDate),
    );
  }

  /// Save profile to local storage from profile API response
  /// This saves all profile fields from the API response
  Future<void> saveProfileFromAPI(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();

    // Save all available fields from API response
    if (result['user_id'] != null) {
      await prefs.setInt(
        _keyUserId,
        result['user_id'] is int
            ? result['user_id']
            : int.tryParse(result['user_id'].toString()) ?? 0,
      );
    }
    if (result['email'] != null) {
      await prefs.setString(_keyEmail, result['email'].toString());
    }
    if (result['role'] != null) {
      await prefs.setString(_keyRole, result['role'].toString());
    }
    if (result['full_name'] != null) {
      await prefs.setString(_keyFullName, result['full_name'].toString());
    }
    if (result['name'] != null) {
      await prefs.setString(_keyName, result['name'].toString());
    }
    if (result['avatar'] != null) {
      await prefs.setString(_keyAvatar, result['avatar'].toString());
    }
    if (result['profileImageUrl'] != null) {
      await prefs.setString(
        _keyProfileImageUrl,
        result['profileImageUrl'].toString(),
      );
    }
    // Save designation - check both 'designation' and 'description' from API
    if (result['designation'] != null) {
      await prefs.setString(_keyDesignation, result['designation'].toString());
    } else if (result['description'] != null) {
      // Map 'description' from API to 'designation' in our app
      await prefs.setString(_keyDesignation, result['description'].toString());
      print(
        'Profile saved - Description mapped to Designation: ${result['description']}',
      );
    }
    // Check for phone_number (API format) first, then phoneNumber, then phone
    if (result['phone_number'] != null) {
      await prefs.setString(_keyPhoneNumber, result['phone_number'].toString());
      print('Profile saved - Phone Number: ${result['phone_number']}');
    } else if (result['phoneNumber'] != null) {
      await prefs.setString(_keyPhoneNumber, result['phoneNumber'].toString());
    } else if (result['phone'] != null) {
      await prefs.setString(_keyPhoneNumber, result['phone'].toString());
    }
    // Save additional required fields
    if (result['department'] != null) {
      await prefs.setString(_keyDepartment, result['department'].toString());
    }
    if (result['user_access'] != null) {
      await prefs.setString(_keyUserAccess, result['user_access'].toString());
    }
    if (result['gender'] != null) {
      await prefs.setString(_keyGender, result['gender'].toString());
    }
    if (result['joining_date'] != null) {
      await prefs.setString(_keyJoiningDate, result['joining_date'].toString());
    }
  }

  /// Save profile to local storage (for manual updates)
  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    if (profile.userId != null) {
      await prefs.setInt(_keyUserId, profile.userId!);
    }
    if (profile.email != null) {
      await prefs.setString(_keyEmail, profile.email!);
    }
    if (profile.role != null) {
      await prefs.setString(_keyRole, profile.role!);
    }
    if (profile.fullName != null) {
      await prefs.setString(_keyFullName, profile.fullName!);
    }
    if (profile.avatar != null) {
      await prefs.setString(_keyAvatar, profile.avatar!);
    }
    if (profile.name != null) {
      await prefs.setString(_keyName, profile.name!);
    }
    if (profile.designation != null) {
      await prefs.setString(_keyDesignation, profile.designation!);
    }
    if (profile.phoneNumber != null) {
      await prefs.setString(_keyPhoneNumber, profile.phoneNumber!);
    }
    if (profile.profileImageUrl != null) {
      await prefs.setString(_keyProfileImageUrl, profile.profileImageUrl!);
    }
    if (profile.department != null) {
      await prefs.setString(_keyDepartment, profile.department!);
    }
    if (profile.userAccess != null) {
      await prefs.setString(_keyUserAccess, profile.userAccess!);
    }
    if (profile.gender != null) {
      await prefs.setString(_keyGender, profile.gender!);
    }
    if (profile.joiningDate != null) {
      await prefs.setString(_keyJoiningDate, profile.joiningDate!);
    }
  }

  /// Clear profile data
  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyAvatar);
    await prefs.remove(_keyName);
    await prefs.remove(_keyDesignation);
    await prefs.remove(_keyPhoneNumber);
    await prefs.remove(_keyProfileImageUrl);
    await prefs.remove(_keyDepartment);
    await prefs.remove(_keyUserAccess);
    await prefs.remove(_keyGender);
    await prefs.remove(_keyJoiningDate);
  }

  /// Future: API integration example
  ///
  /// Future<UserProfile> fetchProfileFromAPI() async {
  ///   try {
  ///     final response = await http.get(Uri.parse('$apiBaseUrl/profile'));
  ///     if (response.statusCode == 200) {
  ///       final data = json.decode(response.body);
  ///       final profile = UserProfile(
  ///         name: data['name'],
  ///         designation: data['designation'],
  ///         phoneNumber: data['phoneNumber'],
  ///         profileImageUrl: data['profileImageUrl'],
  ///       );
  ///       // Cache the data locally
  ///       await saveProfile(profile);
  ///       return profile;
  ///     }
  ///   } catch (e) {
  ///     // If API fails, return cached data
  ///     return await getProfile();
  ///   }
  ///   return await getProfile();
  /// }
  ///
  /// Future<bool> updateProfileToAPI(UserProfile profile) async {
  ///   try {
  ///     final response = await http.put(
  ///       Uri.parse('$apiBaseUrl/profile'),
  ///       body: json.encode({
  ///         'name': profile.name,
  ///         'designation': profile.designation,
  ///         'phoneNumber': profile.phoneNumber,
  ///       }),
  ///       headers: {'Content-Type': 'application/json'},
  ///     );
  ///     if (response.statusCode == 200) {
  ///       await saveProfile(profile); // Cache locally
  ///       return true;
  ///     }
  ///   } catch (e) {
  ///     return false;
  ///   }
  ///   return false;
  /// }
}
