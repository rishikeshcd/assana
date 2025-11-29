import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../services/profile_manager.dart';
import '../../services/api_methods.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _originalProfile;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // Get user ID from saved profile
      final profile = await ProfileManager.instance.getProfile();
      final userId = profile.userId ?? 1; // fallback to 1 if not found

      // Fetch profile data from API
      final response = await ApiMethods.getProfileData(userId);

      if (response.data['status'] == true && response.data['result'] != null) {
        final result = response.data['result'] as Map<String, dynamic>;

        // Save profile data to local storage
        await ProfileManager.instance.saveProfileFromAPI(result);

        // Load saved profile
        final profile = await ProfileManager.instance.getProfile();

        if (mounted) {
          setState(() {
            // Use fullName from API, fallback to name if available, otherwise empty
            _nameController.text = profile.fullName ?? profile.name ?? '';
            // Leave empty if no designation from backend
            _designationController.text = profile.designation ?? '';
            // Leave empty if no phone number from backend
            _phoneController.text = profile.phoneNumber ?? '';
            _originalProfile = profile;
            _isLoading = false;
          });
        }

        // Debug: Print profile data to verify data is loaded
        print('Profile loaded from API - Avatar: ${profile.avatar}');
        print('Profile loaded from API - FullName: ${profile.fullName}');
        print('Profile loaded from API - Email: ${profile.email}');
        print('Profile loaded from API - Phone Number: ${profile.phoneNumber}');
        print('Profile loaded from API - Designation: ${profile.designation}');
      } else {
        // API returned error, try to load from cache
        final profile = await ProfileManager.instance.getProfile();
        if (mounted) {
          setState(() {
            _nameController.text = profile.fullName ?? profile.name ?? '';
            _designationController.text = profile.designation ?? '';
            _phoneController.text = profile.phoneNumber ?? '';
            _originalProfile = profile;
            _isLoading = false;
          });
        }
      }
    } on DioException catch (e) {
      print('Error fetching profile: ${e.message}');
      // On error, try to load from cache
      final profile = await ProfileManager.instance.getProfile();
      if (mounted) {
        setState(() {
          _nameController.text = profile.fullName ?? profile.name ?? '';
          _designationController.text = profile.designation ?? '';
          _phoneController.text = profile.phoneNumber ?? '';
          _originalProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      // On error, try to load from cache
      final profile = await ProfileManager.instance.getProfile();
      if (mounted) {
        setState(() {
          _nameController.text = profile.fullName ?? profile.name ?? '';
          _designationController.text = profile.designation ?? '';
          _phoneController.text = profile.phoneNumber ?? '';
          _originalProfile = profile;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) {
      // Show message that edit mode needs to be enabled first
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enable edit mode first by clicking the edit icon',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() {
                    _selectedImage = File(image.path);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() {
                    _selectedImage = File(image.path);
                  });
                }
              },
            ),
            if (_selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Cancel editing - restore original values (empty if not available)
        _nameController.text =
            _originalProfile?.fullName ?? _originalProfile?.name ?? '';
        _designationController.text = _originalProfile?.designation ?? '';
        _phoneController.text = _originalProfile?.phoneNumber ?? '';
        _passwordController.clear();
      }
    });
  }

  Future<void> _handleUpdate() async {
    // Validate form before submitting
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for phone number
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isNotEmpty && phoneNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be exactly 10 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_isEditing) return;

    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Get user ID from saved profile
      final profile = await ProfileManager.instance.getProfile();
      final userId = profile.userId ?? 1; // fallback to 1 if not found

      // Upload image first if a new image is selected
      if (_selectedImage != null) {
        print('📤 Uploading profile image...');
        try {
          final imageResponse = await ApiMethods.updateProfileImage(
            userId: userId,
            imagePath: _selectedImage!.path,
          );

          if (imageResponse.data['status'] == true &&
              imageResponse.data['result'] != null) {
            print('✅ Image uploaded successfully');
            // Save the updated avatar URL from response
            final imageResult =
                imageResponse.data['result'] as Map<String, dynamic>;
            if (imageResult['avatar'] != null) {
              // Update the profile with new avatar URL
              final updatedProfile =
                  _originalProfile?.copyWith(
                    avatar: imageResult['avatar'].toString(),
                  ) ??
                  UserProfile(avatar: imageResult['avatar'].toString());
              await ProfileManager.instance.saveProfile(updatedProfile);
              _originalProfile = updatedProfile;
            }
          } else {
            print('⚠️ Image upload failed: ${imageResponse.data}');
            // Continue with profile update even if image upload fails
          }
        } catch (e) {
          print('❌ Error uploading image: $e');
          // Continue with profile update even if image upload fails
        }
      }

      // Prepare values - only send non-empty values
      final fullName = _nameController.text.trim();
      final phoneNumber = _phoneController.text.trim();
      final description = _designationController.text.trim();

      // Call API to update profile
      // Send required fields from original profile + updated fields
      final response = await ApiMethods.updateUserProfile(
        userId: userId,
        email: _originalProfile?.email,
        role: _originalProfile?.role,
        fullName: fullName.isNotEmpty ? fullName : null,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
        description: description.isNotEmpty ? description : null,
        // Required fields from original profile
        department: _originalProfile?.department,
        userAccess: _originalProfile?.userAccess,
        gender: _originalProfile?.gender,
        joiningDate: _originalProfile?.joiningDate,
      );

      if (response.data['status'] == true && response.data['result'] != null) {
        // Update successful - save the updated data from API response
        final result = response.data['result'] as Map<String, dynamic>;
        await ProfileManager.instance.saveProfileFromAPI(result);

        // Reload profile to get updated data
        final updatedProfile = await ProfileManager.instance.getProfile();

        if (mounted) {
          setState(() {
            // Update text controllers with the new values from API
            _nameController.text =
                updatedProfile.fullName ?? updatedProfile.name ?? '';
            _designationController.text = updatedProfile.designation ?? '';
            _phoneController.text = updatedProfile.phoneNumber ?? '';
            _originalProfile = updatedProfile;
            _isEditing = false;
            _selectedImage = null; // Clear selected image after update
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data['message'] ?? 'Profile updated successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // API returned error
        if (mounted) {
          final errorMessage =
              response.data['message'] ??
              response.data['error'] ??
              'Failed to update profile';

          // Debug: Print full response for troubleshooting
          print('Update profile error response: ${response.data}');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to update profile';
      if (e.response != null) {
        errorMessage =
            e.response?.data['message'] ??
            e.response?.data['error'] ??
            'Failed to update profile';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Failed to connect to server. Please try again.';
      } else {
        errorMessage = e.message ?? 'Network error. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Future method for uploading image to server
  // Future<String> _uploadImage(File imageFile) async {
  //   // TODO: Implement image upload to your server
  //   // Example:
  //   // final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/profile/image'));
  //   // request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
  //   // request.headers['Authorization'] = 'Bearer $token';
  //   // final response = await request.send();
  //   // final responseData = await response.stream.bytesToString();
  //   // final jsonData = json.decode(responseData);
  //   // return jsonData['imageUrl'];
  //   return '';
  // }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _isEditing ? Icons.close : Icons.edit,
                color: Colors.black,
                size: 20,
              ),
              onPressed: _toggleEditMode,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Profile Picture Section
                  Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        child: ClipOval(
                          child: _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.cover)
                              : _originalProfile?.avatar != null &&
                                    _originalProfile!.avatar!.isNotEmpty &&
                                    _originalProfile!.avatar!.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: _originalProfile!.avatar!,
                                  fit: BoxFit.cover,
                                  httpHeaders: {
                                    'User-Agent':
                                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                    'Referer': 'https://www.google.com/',
                                  },
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    print('Error loading avatar: $error');
                                    return Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey.shade400,
                                    );
                                  },
                                )
                              : _originalProfile?.profileImageUrl != null &&
                                    _originalProfile!
                                        .profileImageUrl!
                                        .isNotEmpty &&
                                    _originalProfile!.profileImageUrl!
                                        .startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: _originalProfile!.profileImageUrl!,
                                  fit: BoxFit.cover,
                                  httpHeaders: {
                                    'User-Agent':
                                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                    'Referer': 'https://www.google.com/',
                                  },
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    print(
                                      'Error loading profile image: $error',
                                    );
                                    return Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey.shade400,
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  _buildInputField(
                    label: 'Name',
                    icon: Icons.person,
                    controller: _nameController,
                    placeholder: 'Enter your name',
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 20),
                  // Email Field (Read-only from login - not editable)
                  if (_originalProfile?.email != null)
                    _buildReadOnlyField(
                      label: 'Email',
                      icon: Icons.email,
                      value: _originalProfile!.email!,
                    ),
                  if (_originalProfile?.email != null)
                    // Role Field (Read-only from login)
                    // if (_originalProfile?.role != null)
                    //   _buildReadOnlyField(
                    //     label: 'Role',
                    //     icon: Icons.badge_outlined,
                    //     value: _originalProfile!.role!,
                    //   ),
                    if (_originalProfile?.role != null)
                      const SizedBox(height: 20),

                  // Form for validation
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Designation Field
                        _buildInputField(
                          label: 'Designation',
                          icon: Icons.badge,
                          controller: _designationController,
                          placeholder: 'Enter your designation',
                          enabled: _isEditing,
                        ),
                        const SizedBox(height: 20),
                        // Phone Number Field
                        _buildPhoneInputField(
                          label: 'Phone Number',
                          icon: Icons.phone,
                          controller: _phoneController,
                          placeholder: 'Enter your phone number',
                          enabled: _isEditing,
                        ),
                        const SizedBox(height: 20),
                        // Change Password Field
                        // _buildInputField(
                        //   label: 'Change Password',
                        //   icon: Icons.lock,
                        //   controller: _passwordController,
                        //   placeholder: 'Enter new password',
                        //   isPassword: true,
                        //   enabled: _isEditing,
                        // ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Update Button
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Update',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String placeholder,
    bool isPassword = false,
    bool enabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          enabled: enabled,
          readOnly: !enabled,
          style: TextStyle(
            color: enabled ? Colors.grey.shade700 : Colors.grey.shade500,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
            filled: true,
            fillColor: AppColors.cardBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String placeholder,
    bool enabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: !enabled,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (value) {
            if (enabled && value != null && value.isNotEmpty) {
              if (value.length != 10) {
                return 'Phone number must be exactly 10 digits';
              }
            }
            return null;
          },
          style: TextStyle(
            color: enabled ? Colors.grey.shade700 : Colors.grey.shade500,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
            filled: true,
            fillColor: AppColors.cardBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
