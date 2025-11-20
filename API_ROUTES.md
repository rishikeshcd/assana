# ASSANA App - API Routes Documentation

## Base URL
```
https://api.assana.com/v1
```

## Authentication

### 1. Login
- **Endpoint:** `POST /auth/login`
- **Description:** Authenticate user with email and password
- **Request Body:**
  ```json
  {
    "email": "user@example.com",
    "password": "password123"
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "token": "jwt_token_here",
    "refreshToken": "refresh_token_here",
    "user": {
      "id": "user_id",
      "email": "user@example.com",
      "name": "User Name"
    }
  }
  ```

### 2. Logout
- **Endpoint:** `POST /auth/logout`
- **Description:** Logout user and invalidate token
- **Headers:** `Authorization: Bearer {token}`
- **Response:**
  ```json
  {
    "success": true,
    "message": "Logged out successfully"
  }
  ```

### 3. Refresh Token
- **Endpoint:** `POST /auth/refresh`
- **Description:** Refresh access token using refresh token
- **Request Body:**
  ```json
  {
    "refreshToken": "refresh_token_here"
  }
  ```

---

## User Profile

### 4. Get User Profile
- **Endpoint:** `GET /profile`
- **Description:** Get current user's profile information
- **Headers:** `Authorization: Bearer {token}`
- **Response:**
  ```json
  {
    "id": "user_id",
    "name": "Dr. John Doe",
    "email": "doctor@example.com",
    "designation": "Colo-rectal surgeon",
    "phoneNumber": "8253728226",  
    "profileImageUrl": "https://api.assana.com/images/profile.jpg",
    "createdAt": "2024-01-01T00:00:00Z"
  }
  ```

### 5. Update User Profile
- **Endpoint:** `PUT /profile`
- **Description:** Update user profile information
- **Headers:** `Authorization: Bearer {token}`
- **Request Body:**
  ```json
  {
    "name": "Dr. John Doe",
    "designation": "Colo-rectal surgeon",
    "phoneNumber": "8253728226"
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "message": "Profile updated successfully",
    "data": { /* updated profile */ }
  }
  ```

### 6. Upload Profile Image
- **Endpoint:** `POST /profile/image`
- **Description:** Upload or update profile picture
- **Headers:** `Authorization: Bearer {token}`, `Content-Type: multipart/form-data`
- **Request Body:** Form data with `image` file
- **Response:**
  ```json
  {
    "success": true,
    "imageUrl": "https://api.assana.com/images/profile_new.jpg"
  }
  ```

### 7. Change Password
- **Endpoint:** `POST /profile/change-password`
- **Description:** Change user password
- **Headers:** `Authorization: Bearer {token}`
- **Request Body:**
  ```json
  {
    "currentPassword": "old_password",
    "newPassword": "new_password"
  }
  ```

---

## Dashboard / Home

### 8. Get Dashboard Statistics
- **Endpoint:** `GET /dashboard/stats`
- **Description:** Get dashboard statistics and counts
- **Headers:** `Authorization: Bearer {token}`
- **Response:**
  ```json
  {
    "totalAppointments": 45,
    "todayAppointments": 8,
    "upcomingAppointments": 12,
    "finishedAppointments": 33
  }
  ```

### 9. Get Appointments List
- **Endpoint:** `GET /appointments`
- **Description:** Get list of appointments with optional status filter
- **Headers:** `Authorization: Bearer {token}`
- **Query Parameters:**
  - `status` (optional): `all`, `finished`, `upcoming`
- **Response:**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "appt_123",
        "appointmentId": "#12847",
        "patientName": "Emma Wilson",
        "time": "08:00 AM",
        "date": "2025-11-12",
        "type": "Consultation",
        "status": "Finished",
        "patientAvatar": "https://api.assana.com/images/patient1.jpg"
      }
    ]
  }
  ```
- **Note:** Search and filtering by name/ID/type should be done client-side after fetching data

---

## Surgeries

### 10. Get Surgeries List
- **Endpoint:** `GET /surgeries`
- **Description:** Get list of surgeries with optional status filter
- **Headers:** `Authorization: Bearer {token}`
- **Query Parameters:**
  - `status` (optional): `ongoing`, `finished`, `post_surgery`
- **Response:**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "surg_123",
        "patientName": "Robert Johnson",
        "procedure": "Appendectomy",
        "date": "2025-11-12",
        "time": "07:45 AM",
        "status": "Ongoing",
        "patientId": "patient_123",
        "patientAvatar": "https://api.assana.com/images/patient1.jpg",
        "surgeon": "Dr. John Doe",
        "room": "OR-101"
      }
    ]
  }
  ```
- **Note:** Search by name, procedure, date should be done client-side after fetching data

### 11. Get Surgery Details
- **Endpoint:** `GET /surgeries/{surgeryId}`
- **Description:** Get detailed information about a surgery
- **Headers:** `Authorization: Bearer {token}`
- **Response:**
  ```json
  {
    "id": "surg_123",
    "patientName": "Robert Johnson",
    "procedure": "Appendectomy",
    "date": "2025-11-12",
    "time": "07:45 AM",
    "status": "Ongoing",
    "patientId": "patient_123",
    "surgeon": "Dr. John Doe",
    "assistant": "Dr. Jane Smith",
    "room": "OR-101",
    "notes": "Patient preparation completed",
    "estimatedDuration": "2 hours"
  }
  ```

### 12. Update Surgery Status
- **Endpoint:** `PATCH /surgeries/{surgeryId}/status`
- **Description:** Update surgery status
- **Headers:** `Authorization: Bearer {token}`
- **Request Body:**
  ```json
  {
    "status": "finished" // or "ongoing", "post_surgery"
  }
  ```

---

## Video Consultations (Meet)

### 13. Get Video Consultations
- **Endpoint:** `GET /consultations`
- **Description:** Get list of video consultation appointments
- **Headers:** `Authorization: Bearer {token}`
- **Query Parameters:**
  - `type` (optional): `all`, `new`, `followup`
- **Response:**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "cons_123",
        "patientName": "Sarah Johnson",
        "type": "New", // or "Followup"
        "procedure": "New Patient",
        "status": "Confirmed",
        "date": "2025-11-12",
        "time": "2:30 PM",
        "duration": "30min",
        "patientId": "patient_123",
        "patientAvatar": "https://api.assana.com/images/patient1.jpg",
        "meetingLink": "https://meet.assana.com/room123",
        "meetingId": "room123"
      }
    ]
  }
  ```
- **Note:** Search and date filtering should be done client-side after fetching data

### 14. Get Consultation Details
- **Endpoint:** `GET /consultations/{consultationId}`
- **Description:** Get detailed information about a consultation
- **Headers:** `Authorization: Bearer {token}`
- **Response:**
  ```json
  {
    "id": "cons_123",
    "patientName": "Sarah Johnson",
    "type": "New",
    "procedure": "New Patient",
    "status": "Confirmed",
    "date": "2025-11-12",
    "time": "2:30 PM",
    "duration": "30min",
    "meetingLink": "https://meet.assana.com/room123",
    "meetingId": "room123",
    "caseHistory": {
      "previousConsultations": [],
      "medicalHistory": [],
      "notes": []
    }
  }
  ```

### 15. Get Case History
- **Endpoint:** `GET /consultations/{consultationId}/case-history`
- **Description:** Get patient's case history for a consultation
- **Headers:** `Authorization: Bearer {token}`
- **Response:**
  ```json
  {
    "patientId": "patient_123",
    "previousConsultations": [
      {
        "id": "cons_122",
        "date": "2025-10-15",
        "type": "Followup",
        "notes": "Patient follow-up consultation"
      }
    ],
    "medicalHistory": [
      {
        "condition": "Hypertension",
        "diagnosedDate": "2024-01-01",
        "status": "Under Control"
      }
    ],
    "prescriptions": [],
    "labReports": []
  }
  ```

### 16. Join Meeting
- **Endpoint:** `POST /consultations/{consultationId}/join`
- **Description:** Generate or get meeting link to join video consultation
- **Headers:** `Authorization: Bearer {token}`
- **Response:**
  ```json
  {
    "success": true,
    "meetingLink": "https://meet.assana.com/room123",
    "meetingId": "room123",
    "token": "meeting_token_here"
  }
  ```

### 17. Update Consultation Status
- **Endpoint:** `PATCH /consultations/{consultationId}/status`
- **Description:** Update consultation status
- **Headers:** `Authorization: Bearer {token}`
- **Request Body:**
  ```json
  {
    "status": "completed" // or "confirmed", "cancelled"
  }
  ```

---

## Settings

### 18. Get User Settings
- **Endpoint:** `GET /settings`
- **Description:** Get user preferences and settings
- **Headers:** `Authorization: Bearer {token}`
- **Response:**
  ```json
  {
    "theme": "light", // or "dark"
    "notifications": {
      "enabled": true,
      "email": true,
      "push": true,
      "sms": false
    },
    "language": "en"
  }
  ```

### 19. Update Theme
- **Endpoint:** `PATCH /settings/theme`
- **Description:** Update theme preference
- **Headers:** `Authorization: Bearer {token}`
- **Request Body:**
  ```json
  {
    "theme": "light" // or "dark"
  }
  ```

### 20. Update Notification Settings
- **Endpoint:** `PATCH /settings/notifications`
- **Description:** Update notification preferences
- **Headers:** `Authorization: Bearer {token}`
- **Request Body:**
  ```json
  {
    "enabled": true,
    "email": true,
    "push": true,
    "sms": false
  }
  ```

---

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "success": false,
  "error": "Validation error",
  "message": "Invalid input data",
  "errors": {
    "email": ["Email is required"],
    "password": ["Password must be at least 8 characters"]
  }
}
```

### 401 Unauthorized
```json
{
  "success": false,
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}
```

### 404 Not Found
```json
{
  "success": false,
  "error": "Not Found",
  "message": "Resource not found"
}
```

### 500 Internal Server Error
```json
{
  "success": false,
  "error": "Internal Server Error",
  "message": "An unexpected error occurred"
}
```

---

## Notes

1. **Authentication:** Most endpoints require a Bearer token in the Authorization header
2. **Client-Side Filtering:** Search and filtering by name/ID/date should be done in the app after fetching data from the API
3. **Status Filtering:** Only status/type filters are sent to the API to reduce data transfer
4. **Date Format:** All dates should be in ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ssZ)
5. **Image URLs:** Profile images and avatars are returned as full URLs

