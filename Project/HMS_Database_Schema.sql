-- ============================================================================
-- HOSPITAL MANAGEMENT SYSTEM — DATABASE DESIGN (v2)
-- Updated to match the multi-portal front-end (Admin / Doctor / Receptionist)
--
-- Changes from v1:
--   * appointments.status gains 'Checked-in' (receptionist check-in step)
--   * appointments.notes added (doctor's consultation notes)
--   * everything else is unchanged — still 9 tables, 3NF
-- ============================================================================

CREATE DATABASE IF NOT EXISTS hospital_management_system;
USE hospital_management_system;

SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- 1. USERS — every login account (admin / doctor / receptionist).
--    is_active drives the "Activate / Deactivate" toggle on the admin's
--    Staff & Users page.
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    user_id         INT AUTO_INCREMENT PRIMARY KEY,
    username        VARCHAR(50)  NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    role            ENUM('admin', 'doctor', 'receptionist') NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    is_active       TINYINT(1)   NOT NULL DEFAULT 1,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- 2. DOCTORS — created by admin via the "+ Add doctor" action.
-- ----------------------------------------------------------------------------
CREATE TABLE doctors (
    doctor_id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNIQUE,
    name            VARCHAR(100) NOT NULL,
    specialization  VARCHAR(100) NOT NULL,
    department      VARCHAR(100),
    phone           VARCHAR(15),
    email           VARCHAR(100),
    years_experience INT DEFAULT 0,
    CONSTRAINT fk_doctor_user FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- 3. STAFF — receptionists, nurses, admin staff
-- ----------------------------------------------------------------------------
CREATE TABLE staff (
    staff_id        INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNIQUE,
    name            VARCHAR(100) NOT NULL,
    designation     VARCHAR(50)  NOT NULL,
    department      VARCHAR(100),
    phone           VARCHAR(15),
    CONSTRAINT fk_staff_user FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- 4. PATIENTS
-- ----------------------------------------------------------------------------
CREATE TABLE patients (
    patient_id      INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    age             INT NOT NULL,
    gender          ENUM('M','F','Other') NOT NULL,
    contact_no      VARCHAR(15) NOT NULL,
    address         VARCHAR(255),
    blood_group     VARCHAR(5),
    registered_on   DATE NOT NULL DEFAULT (CURRENT_DATE)
);

-- ----------------------------------------------------------------------------
-- 5. ROOMS — receptionist/admin can add rooms via "+ Add room".
-- ----------------------------------------------------------------------------
CREATE TABLE rooms (
    room_no         VARCHAR(10) PRIMARY KEY,
    room_type       ENUM('General','Semi-Private','Private','ICU') NOT NULL,
    floor           INT NOT NULL DEFAULT 1,
    charge_per_day  DECIMAL(10,2) NOT NULL,
    status          ENUM('Available','Occupied','Maintenance') NOT NULL DEFAULT 'Available'
);

-- ----------------------------------------------------------------------------
-- 6. APPOINTMENTS
--    status now covers the receptionist's check-in step, and notes holds
--    the doctor's consultation notes recorded through "Consult".
-- ----------------------------------------------------------------------------
CREATE TABLE appointments (
    appointment_id   INT AUTO_INCREMENT PRIMARY KEY,
    patient_id       INT NOT NULL,
    doctor_id        INT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    reason           VARCHAR(255),
    priority         ENUM('Emergency','Critical','General') NOT NULL DEFAULT 'General',
    status           ENUM('Scheduled','Checked-in','Completed','Cancelled') NOT NULL DEFAULT 'Scheduled',
    notes            TEXT NULL,
    CONSTRAINT fk_appt_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_appt_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
        ON DELETE RESTRICT,
    INDEX idx_appt_patient (patient_id),
    INDEX idx_appt_doctor_date (doctor_id, appointment_date)
);

-- ----------------------------------------------------------------------------
-- 7. ADMISSIONS — created by "Admit patient", closed by "Discharge".
-- ----------------------------------------------------------------------------
CREATE TABLE admissions (
    admission_id    INT AUTO_INCREMENT PRIMARY KEY,
    patient_id      INT NOT NULL,
    room_no         VARCHAR(10) NOT NULL,
    doctor_id       INT NOT NULL,
    admission_date  DATE NOT NULL,
    discharge_date  DATE,
    diagnosis       VARCHAR(255),
    CONSTRAINT fk_adm_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_adm_room FOREIGN KEY (room_no) REFERENCES rooms(room_no)
        ON DELETE RESTRICT,
    CONSTRAINT fk_adm_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
        ON DELETE RESTRICT,
    INDEX idx_adm_patient (patient_id),
    INDEX idx_adm_doctor (doctor_id)
);

-- ----------------------------------------------------------------------------
-- 8. PRESCRIPTIONS — created directly, or from a doctor's "Consult" action.
-- ----------------------------------------------------------------------------
CREATE TABLE prescriptions (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id      INT NOT NULL,
    doctor_id       INT NOT NULL,
    appointment_id  INT,
    medicines       TEXT NOT NULL,
    date_issued     DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_presc_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_presc_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_presc_appt FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
        ON DELETE SET NULL,
    INDEX idx_presc_patient (patient_id),
    INDEX idx_presc_doctor (doctor_id)
);

-- ----------------------------------------------------------------------------
-- 9. BILLING
-- ----------------------------------------------------------------------------
CREATE TABLE billing (
    billing_id      INT AUTO_INCREMENT PRIMARY KEY,
    patient_id      INT NOT NULL,
    admission_id    INT,
    appointment_id  INT,
    amount          DECIMAL(10,2) NOT NULL,
    payment_mode    ENUM('Cash','Card','UPI','Insurance') NOT NULL DEFAULT 'Cash',
    payment_status  ENUM('Paid','Pending','Partial') NOT NULL DEFAULT 'Pending',
    billing_date    DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_bill_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_bill_admission FOREIGN KEY (admission_id) REFERENCES admissions(admission_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_bill_appt FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
        ON DELETE SET NULL,
    INDEX idx_bill_patient (patient_id),
    INDEX idx_bill_status (payment_status)
);

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- USEFUL QUERIES (for the report / viva)
-- ============================================================================

-- Today's queue, receptionist + doctor view combined (priority scheduling)
-- SELECT a.appointment_id, p.name AS patient, d.name AS doctor, a.appointment_time,
--        a.priority, a.status
-- FROM appointments a
-- JOIN patients p ON p.patient_id = a.patient_id
-- JOIN doctors d ON d.doctor_id = a.doctor_id
-- WHERE a.appointment_date = CURDATE()
-- ORDER BY FIELD(a.priority,'Emergency','Critical','General'), a.appointment_time;

-- Revenue collected, grouped by payment mode (admin overview)
-- SELECT payment_mode, SUM(amount) AS collected
-- FROM billing WHERE payment_status = 'Paid'
-- GROUP BY payment_mode;

-- One patient's full record (used by the "View record" modal)
-- SELECT * FROM appointments WHERE patient_id = ?;
-- SELECT * FROM prescriptions WHERE patient_id = ?;
-- SELECT * FROM admissions WHERE patient_id = ?;
-- SELECT * FROM billing WHERE patient_id = ?;
