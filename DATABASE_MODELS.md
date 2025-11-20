# ASSANA App - Database Models

## Database Schema Overview

This document defines the database models and relationships for the ASSANA application.

---

## 1. Users Table

Stores user/doctor information and authentication data.

```sql
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    designation VARCHAR(255),
    phone_number VARCHAR(20),
    profile_image_url TEXT,
    role VARCHAR(50) DEFAULT 'doctor', -- 'doctor', 'admin', etc.
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_role (role)
);
```

**Model Fields:**
- `id` (String, UUID) - Primary key
- `email` (String) - Unique email address
- `password_hash` (String) - Hashed password
- `name` (String, nullable) - User's full name
- `designation` (String, nullable) - Job title/designation
- `phone_number` (String, nullable) - Phone number
- `profile_image_url` (String, nullable) - URL to profile image
- `role` (String) - User role (default: 'doctor')
- `is_active` (Boolean) - Account status
- `created_at` (DateTime) - Account creation timestamp
- `updated_at` (DateTime) - Last update timestamp

---

## 2. Appointments Table

Stores appointment information for the home/dashboard page.

```sql
CREATE TABLE appointments (
    id VARCHAR(36) PRIMARY KEY,
    appointment_id VARCHAR(50) UNIQUE NOT NULL, -- e.g., "#12847"
    doctor_id VARCHAR(36) NOT NULL,
    patient_name VARCHAR(255) NOT NULL,
    patient_id VARCHAR(36),
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    type VARCHAR(100), -- 'Consultation', 'Follow-Up', 'Assessment', 'Review'
    status VARCHAR(50) NOT NULL, -- 'Finished', 'Upcoming', 'Cancelled'
    patient_avatar_url TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_doctor_id (doctor_id),
    INDEX idx_appointment_date (appointment_date),
    INDEX idx_status (status),
    INDEX idx_appointment_id (appointment_id)
);
```

**Model Fields:**
- `id` (String, UUID) - Primary key
- `appointment_id` (String) - Unique appointment identifier (e.g., "#12847")
- `doctor_id` (String) - Foreign key to users table
- `patient_name` (String) - Patient's name
- `patient_id` (String, nullable) - Patient ID if exists in system
- `appointment_date` (Date) - Date of appointment
- `appointment_time` (Time) - Time of appointment
- `type` (String, nullable) - Appointment type
- `status` (String) - Appointment status
- `patient_avatar_url` (String, nullable) - Patient profile image URL
- `notes` (String, nullable) - Additional notes
- `created_at` (DateTime) - Creation timestamp
- `updated_at` (DateTime) - Last update timestamp

---

## 3. Surgeries Table

Stores surgery information.

```sql
CREATE TABLE surgeries (
    id VARCHAR(36) PRIMARY KEY,
    doctor_id VARCHAR(36) NOT NULL,
    patient_name VARCHAR(255) NOT NULL,
    patient_id VARCHAR(36),
    procedure VARCHAR(255) NOT NULL,
    surgery_date DATE NOT NULL,
    surgery_time TIME NOT NULL,
    status VARCHAR(50) NOT NULL, -- 'Ongoing', 'Finished', 'Post Surgery', 'Cancelled'
    patient_avatar_url TEXT,
    surgeon VARCHAR(255),
    assistant VARCHAR(255),
    room VARCHAR(100),
    estimated_duration VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_doctor_id (doctor_id),
    INDEX idx_surgery_date (surgery_date),
    INDEX idx_status (status)
);
```

**Model Fields:**
- `id` (String, UUID) - Primary key
- `doctor_id` (String) - Foreign key to users table
- `patient_name` (String) - Patient's name
- `patient_id` (String, nullable) - Patient ID if exists in system
- `procedure` (String) - Surgery procedure name
- `surgery_date` (Date) - Date of surgery
- `surgery_time` (Time) - Time of surgery
- `status` (String) - Surgery status
- `patient_avatar_url` (String, nullable) - Patient profile image URL
- `surgeon` (String, nullable) - Surgeon name
- `assistant` (String, nullable) - Assistant surgeon name
- `room` (String, nullable) - Operating room number
- `estimated_duration` (String, nullable) - Estimated duration
- `notes` (String, nullable) - Additional notes
- `created_at` (DateTime) - Creation timestamp
- `updated_at` (DateTime) - Last update timestamp

---

## 4. Consultations Table

Stores video consultation appointments.

```sql
CREATE TABLE consultations (
    id VARCHAR(36) PRIMARY KEY,
    doctor_id VARCHAR(36) NOT NULL,
    patient_name VARCHAR(255) NOT NULL,
    patient_id VARCHAR(36),
    type VARCHAR(50) NOT NULL, -- 'New', 'Followup'
    procedure VARCHAR(255),
    consultation_date DATE NOT NULL,
    consultation_time TIME NOT NULL,
    duration VARCHAR(50), -- e.g., "30min"
    status VARCHAR(50) NOT NULL, -- 'Confirmed', 'Completed', 'Cancelled', 'Pending'
    patient_avatar_url TEXT,
    meeting_link TEXT,
    meeting_id VARCHAR(255),
    meeting_token TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_doctor_id (doctor_id),
    INDEX idx_consultation_date (consultation_date),
    INDEX idx_type (type),
    INDEX idx_status (status)
);
```

**Model Fields:**
- `id` (String, UUID) - Primary key
- `doctor_id` (String) - Foreign key to users table
- `patient_name` (String) - Patient's name
- `patient_id` (String, nullable) - Patient ID if exists in system
- `type` (String) - Consultation type ('New' or 'Followup')
- `procedure` (String, nullable) - Procedure/consultation type
- `consultation_date` (Date) - Date of consultation
- `consultation_time` (Time) - Time of consultation
- `duration` (String, nullable) - Consultation duration
- `status` (String) - Consultation status
- `patient_avatar_url` (String, nullable) - Patient profile image URL
- `meeting_link` (String, nullable) - Video meeting URL
- `meeting_id` (String, nullable) - Meeting room ID
- `meeting_token` (String, nullable) - Meeting access token
- `created_at` (DateTime) - Creation timestamp
- `updated_at` (DateTime) - Last update timestamp

---

## 5. Case History Table

Stores patient case history for consultations.

```sql
CREATE TABLE case_history (
    id VARCHAR(36) PRIMARY KEY,
    consultation_id VARCHAR(36) NOT NULL,
    patient_id VARCHAR(36),
    history_type VARCHAR(50) NOT NULL, -- 'previous_consultation', 'medical_history', 'prescription', 'lab_report'
    title VARCHAR(255),
    description TEXT,
    date DATE,
    metadata JSON, -- For storing additional structured data
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (consultation_id) REFERENCES consultations(id) ON DELETE CASCADE,
    INDEX idx_consultation_id (consultation_id),
    INDEX idx_patient_id (patient_id),
    INDEX idx_history_type (history_type)
);
```

**Model Fields:**
- `id` (String, UUID) - Primary key
- `consultation_id` (String) - Foreign key to consultations table
- `patient_id` (String, nullable) - Patient ID
- `history_type` (String) - Type of history entry
- `title` (String, nullable) - Title of the entry
- `description` (String, nullable) - Description/details
- `date` (Date, nullable) - Date of the event
- `metadata` (JSON, nullable) - Additional structured data
- `created_at` (DateTime) - Creation timestamp
- `updated_at` (DateTime) - Last update timestamp

---

## 6. User Settings Table

Stores user preferences and settings.

```sql
CREATE TABLE user_settings (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) UNIQUE NOT NULL,
    theme VARCHAR(20) DEFAULT 'light', -- 'light', 'dark'
    notifications_enabled BOOLEAN DEFAULT TRUE,
    email_notifications BOOLEAN DEFAULT TRUE,
    push_notifications BOOLEAN DEFAULT TRUE,
    sms_notifications BOOLEAN DEFAULT FALSE,
    language VARCHAR(10) DEFAULT 'en',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
);
```

**Model Fields:**
- `id` (String, UUID) - Primary key
- `user_id` (String) - Foreign key to users table (unique)
- `theme` (String) - Theme preference
- `notifications_enabled` (Boolean) - Master notification toggle
- `email_notifications` (Boolean) - Email notification preference
- `push_notifications` (Boolean) - Push notification preference
- `sms_notifications` (Boolean) - SMS notification preference
- `language` (String) - Language preference
- `created_at` (DateTime) - Creation timestamp
- `updated_at` (DateTime) - Last update timestamp

---

## 7. Refresh Tokens Table

Stores refresh tokens for JWT authentication.

```sql
CREATE TABLE refresh_tokens (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    token VARCHAR(500) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_token (token),
    INDEX idx_expires_at (expires_at)
);
```

**Model Fields:**
- `id` (String, UUID) - Primary key
- `user_id` (String) - Foreign key to users table
- `token` (String) - Refresh token string
- `expires_at` (DateTime) - Token expiration timestamp
- `created_at` (DateTime) - Creation timestamp

---

## Entity Relationship Diagram (ERD)

```
┌─────────────┐
│    users    │
│─────────────│
│ id (PK)     │
│ email       │◄─────┐
│ password    │      │
│ name        │      │
│ designation │      │
│ ...         │      │
└─────────────┘      │
                     │
      ┌──────────────┼──────────────┐
      │              │              │
      │              │              │
┌─────▼──────┐ ┌─────▼──────┐ ┌─────▼──────────┐
│appointments│ │  surgeries │ │ consultations  │
│────────────│ │────────────│ │────────────────│
│ id (PK)    │ │ id (PK)    │ │ id (PK)        │
│ doctor_id  │ │ doctor_id  │ │ doctor_id (FK) │
│ patient_   │ │ patient_   │ │ patient_       │
│   name     │ │   name     │ │   name         │
│ status     │ │ status     │ │ type           │
│ ...        │ │ ...        │ │ meeting_link   │
└────────────┘ └────────────┘ └─────┬──────────┘
                                     │
                            ┌────────▼─────────┐
                            │  case_history    │
                            │──────────────────│
                            │ id (PK)          │
                            │ consultation_id  │
                            │ history_type     │
                            │ ...              │
                            └──────────────────┘

┌─────────────┐      ┌──────────────────┐
│    users    │      │  user_settings   │
│─────────────│      │──────────────────│
│ id (PK)     │──────│ id (PK)          │
│ ...         │      │ user_id (FK)     │
└─────────────┘      │ theme            │
                     │ notifications_   │
                     │   enabled        │
                     │ ...              │
                     └──────────────────┘

┌─────────────┐      ┌──────────────────┐
│    users    │      │ refresh_tokens   │
│─────────────│      │──────────────────│
│ id (PK)     │──────│ id (PK)          │
│ ...         │      │ user_id (FK)     │
└─────────────┘      │ token            │
                     │ expires_at       │
                     └──────────────────┘
```

---

## Indexes Summary

**Performance Indexes:**
- `users.email` - For login lookups
- `appointments.doctor_id` - For filtering appointments by doctor
- `appointments.appointment_date` - For date-based queries
- `appointments.status` - For status filtering
- `surgeries.doctor_id` - For filtering surgeries by doctor
- `surgeries.surgery_date` - For date-based queries
- `surgeries.status` - For status filtering
- `consultations.doctor_id` - For filtering consultations by doctor
- `consultations.consultation_date` - For date-based queries
- `consultations.type` - For type filtering
- `case_history.consultation_id` - For joining with consultations
- `refresh_tokens.token` - For token validation
- `refresh_tokens.expires_at` - For cleanup of expired tokens

---

## Data Types Reference

- **VARCHAR(n)** - Variable length string (max n characters)
- **TEXT** - Long text field (unlimited length)
- **BOOLEAN** - True/false value
- **DATE** - Date only (YYYY-MM-DD)
- **TIME** - Time only (HH:MM:SS)
- **TIMESTAMP** - Date and time (YYYY-MM-DD HH:MM:SS)
- **JSON** - JSON object storage
- **UUID/VARCHAR(36)** - Unique identifier (UUID format)

---

## Notes

1. **UUIDs**: All primary keys use UUID format for better distribution and security
2. **Soft Deletes**: Consider adding `deleted_at` timestamp for soft delete functionality
3. **Audit Trail**: `created_at` and `updated_at` fields track record lifecycle
4. **Foreign Keys**: All foreign keys have `ON DELETE CASCADE` to maintain referential integrity
5. **Indexes**: Indexes are created on frequently queried fields for performance
6. **JSON Fields**: `metadata` in case_history allows flexible data storage
7. **Normalization**: Patient information is stored directly in tables (denormalized) for performance, but `patient_id` allows linking to a patients table if needed in future

---

## Future Enhancements

Consider adding these tables if needed:

1. **patients** - Dedicated patient table for better data management
2. **notifications** - Store notification history
3. **audit_logs** - Track all data changes for compliance
4. **appointment_reminders** - Schedule and track reminders
5. **prescriptions** - Store prescription details
6. **lab_reports** - Store lab test results






