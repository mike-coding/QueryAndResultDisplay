-- drop dependent tables
DROP TABLE IF EXISTS Appointments;
DROP TABLE IF EXISTS WorksAt;
DROP TABLE IF EXISTS Vaccines;
DROP TABLE IF EXISTS PatientPhoneNumbers;
DROP TABLE IF EXISTS HealthCareProviderSchedules;
DROP TABLE IF EXISTS HealthCareCenterPhoneNumbers;
DROP TABLE IF EXISTS EHR;

-- drop referenced tables
DROP TABLE IF EXISTS HealthCareProviders;
DROP TABLE IF EXISTS HealthCareCenters;
DROP TABLE IF EXISTS Patients;
DROP TABLE IF EXISTS Batches;
DROP TABLE IF EXISTS Formulations;

-- drop views
DROP VIEW IF EXISTS View_PatientContactInfo;
DROP VIEW IF EXISTS View_SimpleBatchInformation;
DROP VIEW IF EXISTS View_ConvolutedBatchInformation;


-- define tables
CREATE TABLE Formulations (
  Formulation varchar(10) NOT NULL,
  KnownAllergen varchar(255) NOT NULL DEFAULT 'None',
  PRIMARY KEY (Formulation),
  CHECK (KnownAllergen != '')
) ENGINE=InnoDB;

CREATE TABLE Batches (
  BatchId int(11) NOT NULL AUTO_INCREMENT,
  Year year(4) DEFAULT NULL,
  Formulation varchar(10) DEFAULT NULL,
  PRIMARY KEY (BatchId),
  FOREIGN KEY (Formulation) REFERENCES Formulations (Formulation) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Vaccines (
  VialId int(11) NOT NULL AUTO_INCREMENT,
  BatchId int(11) NOT NULL,
  PRIMARY KEY (VialId,BatchId),
  FOREIGN KEY (BatchId) REFERENCES Batches (BatchId) ON DELETE CASCADE ON UPDATE CASCADE -- on batch deletion its vials are deleted
) ENGINE=InnoDB;

CREATE TABLE Patients (
  PatientId int(11) NOT NULL AUTO_INCREMENT,
  DateOfBirth date DEFAULT NULL,
  Sex varchar(100) DEFAULT NULL,
  Ethnicity varchar(100) DEFAULT NULL,
  Name varchar(100) NOT NULL,
  Email varchar(100) DEFAULT NULL,
  City varchar(100) DEFAULT NULL, 
  Street varchar(100) DEFAULT NULL,
  ZipCode varchar(100) DEFAULT NULL,
  PRIMARY KEY (PatientId),
  CHECK (ZipCode REGEXP '^[0-9]{5}(-[0-9]{4})?$'), -- zipcode standard format
  CHECK (Email REGEXP '^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'), -- regexp constrain email to standard email format eg. something@domain.web
  CHECK (Sex IN ('Male', 'Female', 'Other', 'Prefer not to say')), -- enforce discrete options for Sex
  CHECK (Name REGEXP '^[^ ]+ [^ ]+$'),  -- Ensures one space between two non-empty strings, eg. 'firstname lastname'
  INDEX idx_patient_city (City), -- The following are B-tree indexes to speed up demographic queries on patients, plus enable faster queries by name & email
  INDEX idx_patient_email (Email),
  INDEX idx_patient_zipcode (ZipCode),
  INDEX idx_patient_sex (Sex),
  INDEX idx_patient_name (Name)
) ENGINE=InnoDB;

-- trigger 1: prevent adding a date of birth in the future
DELIMITER $$
CREATE TRIGGER CheckDateOfBirth
BEFORE INSERT ON Patients
FOR EACH ROW
BEGIN
  IF NEW.DateOfBirth > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Date of birth cannot be in the future.';
  END IF;
END$$

CREATE TRIGGER CheckDateOfBirthOnUpdate
BEFORE Update ON Patients
FOR EACH ROW
BEGIN
  IF NEW.DateOfBirth > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Date of birth cannot be in the future.';
  END IF;
END$$
DELIMITER ;

CREATE TABLE EHR (
  PatientId int(11) NOT NULL,
  HealthRecord text NOT NULL, 
  PRIMARY KEY (PatientId,HealthRecord(255)),
  FOREIGN KEY (PatientId) REFERENCES Patients (PatientId) ON DELETE CASCADE ON UPDATE CASCADE -- on patient deletion their health records are deleted
) ENGINE=InnoDB;

CREATE TABLE PatientPhoneNumbers (
  PatientId int(11) NOT NULL,
  PhoneNumber varchar(100) NOT NULL,
  PRIMARY KEY (PatientId,PhoneNumber),
  FOREIGN KEY (PatientId) REFERENCES Patients (PatientId) ON DELETE CASCADE ON UPDATE CASCADE, -- on patient deletion their stored phone #s are deleted
  CHECK (PhoneNumber REGEXP '^[+]?[0-9]{10,15}$') -- regexp constraints phone # to standard format
) ENGINE=InnoDB;

CREATE TABLE HealthCareCenters (
  CenterId int(11) NOT NULL AUTO_INCREMENT, 
  CenterName varchar(100) DEFAULT NULL,
  City varchar(100) DEFAULT NULL,
  Street varchar(100) DEFAULT NULL,
  ZipCode varchar(100) DEFAULT NULL,
  PRIMARY KEY (CenterId),
  CHECK (ZipCode REGEXP '^[0-9]{5}(-[0-9]{4})?$')
) ENGINE=InnoDB;

CREATE TABLE HealthCareCenterPhoneNumbers (
  CenterId int(11) NOT NULL,
  PhoneNumber varchar(100) NOT NULL,
  PRIMARY KEY (CenterId,PhoneNumber),
  FOREIGN KEY (CenterId) REFERENCES HealthCareCenters (CenterId) ON DELETE CASCADE ON UPDATE CASCADE, -- on center deletion its phone #s are deleted
  CHECK (PhoneNumber REGEXP '^[+]?[0-9]{10,15}$') -- regexp constraints phone # to standard format
) ENGINE=InnoDB;

CREATE TABLE HealthCareProviders (
  ProviderId int(11) NOT NULL AUTO_INCREMENT,
  JobTitle varchar(100) DEFAULT NULL,
  Name varchar(100) NOT NULL,
  PRIMARY KEY (ProviderId),
  CHECK (Name REGEXP '^[^ ]+ [^ ]+$') -- Ensures one space between two non-empty strings, eg. 'firstname lastname'
) ENGINE=InnoDB;

CREATE TABLE HealthCareProviderSchedules (
  ProviderId int(11) NOT NULL,
  Schedule text NOT NULL, 
  PRIMARY KEY (ProviderId,Schedule(255)),
  FOREIGN KEY (ProviderId) REFERENCES HealthCareProviders (ProviderId) ON DELETE CASCADE ON UPDATE CASCADE -- on provider deletion their schedules are deleted
) ENGINE=InnoDB;

CREATE TABLE WorksAt (
  CenterId int(11) NOT NULL,
  ProviderId int(11) NOT NULL,
  StartDate date DEFAULT NULL,
  PRIMARY KEY (CenterId,ProviderId),
  FOREIGN KEY (CenterId) REFERENCES HealthCareCenters (CenterId) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (ProviderId) REFERENCES HealthCareProviders (ProviderId) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Appointments (
  AppointmentId int(11) NOT NULL AUTO_INCREMENT,
  PatientId int(11) DEFAULT NULL, -- if patient leaves, retain record of appointment for health care center usage statistics, physician billable hours, etc
  Time time NOT NULL,
  Date date NOT NULL, 
  ProviderId int(11) DEFAULT NULL, -- can be nullified in the event a provider leaves so the appointment can be assigned a new ProviderId
  CenterId int(11) DEFAULT NULL, -- can be nullified in the event a center closes so the appointment can be assigned a new CenterId
  VialId int(11) DEFAULT NULL,  -- Vaccine may be decided after time of booking appt.
  BatchId int(11) DEFAULT NULL, -- Same as VialId
  AdverseEffectEvent varchar(255) DEFAULT 'None', 
  PRIMARY KEY (AppointmentId),
  FOREIGN KEY (PatientId) REFERENCES Patients (PatientId) ON DELETE SET NULL ON UPDATE CASCADE,
  FOREIGN KEY (ProviderId) REFERENCES HealthCareProviders (ProviderId) ON DELETE SET NULL ON UPDATE CASCADE, 
  FOREIGN KEY (CenterId) REFERENCES HealthCareCenters (CenterId) ON DELETE SET NULL ON UPDATE CASCADE, 
  FOREIGN KEY (VialId) REFERENCES Vaccines (VialId) ON DELETE SET NULL ON UPDATE CASCADE, -- if a specific vaccine is destroyed, it can be reassigned at time of appointment
  FOREIGN KEY (BatchId) REFERENCES Batches (BatchId) ON DELETE SET NULL ON UPDATE CASCADE, -- same as VialId
  INDEX idx_appointments_batchid (BatchId) -- if issues are found with a batch, quickly find all appointments where it was administered to inform patients
) ENGINE=InnoDB;

-- trigger 2: prevent vials (BatchId, VialId combos) from being used in multiple appointments
DELIMITER $$
CREATE TRIGGER VerifyVialAvailabilityBeforeInsert
BEFORE INSERT ON Appointments
FOR EACH ROW
BEGIN
  IF EXISTS (
    SELECT 1
    FROM Appointments AS a
    WHERE a.BatchId = NEW.BatchId AND a.VialId = NEW.VialId
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The specified vaccine vial has been used in an appointment already.';
  END IF;
END$$

CREATE TRIGGER VerifyVialAvailabilityBeforeUpdate
BEFORE UPDATE ON Appointments
FOR EACH ROW
BEGIN
  IF EXISTS (
    SELECT 1
    FROM Appointments AS a
    WHERE a.BatchId = NEW.BatchId AND a.VialId = NEW.VialId AND a.AppointmentId <> NEW.AppointmentId
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The specified vaccine vial has been used in an appointment already.';
  END IF;
END$$
DELIMITER ;

-- inserting data

-- lack of the main primary key Ids being specified for these insertions is intentional, they are handled by the AUTO_INCREMENT in the table creations
INSERT INTO Formulations (Formulation, KnownAllergen) VALUES ('IIV4', 'Trace amounts of gelatin');
INSERT INTO Formulations (Formulation, KnownAllergen) VALUES ('RIV4', 'None');
INSERT INTO Formulations (Formulation, KnownAllergen) VALUES ('LAIV4', 'Egg proteins, gelatin');
INSERT INTO Formulations (Formulation, KnownAllergen) VALUES ('ccIIV4', 'None');
INSERT INTO Formulations (Formulation, KnownAllergen) VALUES ('aIIV4', 'None');

INSERT INTO Batches (Year, Formulation) VALUES (2022, 'IIV4'), (2023, 'IIV4'), (2024, 'IIV4');
INSERT INTO Batches (Year, Formulation) VALUES (2022, 'RIV4'), (2023, 'RIV4'), (2024, 'RIV4');
INSERT INTO Batches (Year, Formulation) VALUES (2022, 'LAIV4'), (2023, 'LAIV4'), (2024, 'LAIV4');
INSERT INTO Batches (Year, Formulation) VALUES (2022, 'ccIIV4'), (2023, 'ccIIV4'), (2024, 'ccIIV4');
INSERT INTO Batches (Year, Formulation) VALUES (2022, 'aIIV4'), (2023, 'aIIV4'), (2024, 'aIIV4');

INSERT INTO Vaccines (BatchId) VALUES (1),(1),(1),(1),(1);
INSERT INTO Vaccines (BatchId) VALUES (2),(2),(2),(2),(2);
INSERT INTO Vaccines (BatchId) VALUES (3),(3),(3),(3),(3);
INSERT INTO Vaccines (BatchId) VALUES (4),(4),(4),(4),(4);
INSERT INTO Vaccines (BatchId) VALUES (5),(5),(5),(5),(5);
INSERT INTO Vaccines (BatchId) VALUES (6),(6),(6),(6),(6);
INSERT INTO Vaccines (BatchId) VALUES (7),(7),(7),(7),(7);
INSERT INTO Vaccines (BatchId) VALUES (8),(8),(8),(8),(8);
INSERT INTO Vaccines (BatchId) VALUES (9),(9),(9),(9),(9);
INSERT INTO Vaccines (BatchId) VALUES (10),(10),(10),(10),(10);
INSERT INTO Vaccines (BatchId) VALUES (11),(11),(11),(11),(11);
INSERT INTO Vaccines (BatchId) VALUES (12),(12),(12),(12),(12);
INSERT INTO Vaccines (BatchId) VALUES (13),(13),(13),(13),(13);
INSERT INTO Vaccines (BatchId) VALUES (14),(14),(14),(14),(14);
INSERT INTO Vaccines (BatchId) VALUES (15),(15),(15),(15),(15);

INSERT INTO HealthCareCenters (CenterName, City, Street, ZipCode) VALUES ('UI Hospitals & Clinics', 'Iowa City', '200 Hawkins Drive', '52242');
INSERT INTO HealthCareCenters (CenterName, City, Street, ZipCode) VALUES ('UI QuickCare - Old Capitol Town Center', 'Iowa City', '201 South Clinton Street', '52240');
INSERT INTO HealthCareCenters (CenterName, City, Street, ZipCode) VALUES ('Iowa River Landing East', 'Coralville', '920 East 2nd Avenue', '52241');
INSERT INTO HealthCareCenters (CenterName, City, Street, ZipCode) VALUES ('UI QuickCare - North Liberty', 'North Liberty', '720 Pacha Parkway Suite 1', '52317');
INSERT INTO HealthCareCenters (CenterName, City, Street, ZipCode) VALUES ('West Des Moines - Jordan Creek Parkway', 'West Des Moines', '1225 Jordan Creek Parkway Suite 120', '50266');
INSERT INTO HealthCareCenters (CenterName, City, Street, ZipCode) VALUES ('Family Medicine - Bettendorf', 'Bettendorf', '865 Lincoln Road', '52722');

INSERT INTO HealthCareProviders (JobTitle, Name) VALUES ('General Practitioner', 'Priyanka Singh');
INSERT INTO HealthCareProviders (JobTitle, Name) VALUES ('Cardiologist', 'Tim Lillig');
INSERT INTO HealthCareProviders (JobTitle, Name) VALUES ('Nurse Practitioner', 'Mike Wurth');
INSERT INTO HealthCareProviders (JobTitle, Name) VALUES ('Orthopedic Surgeon', 'Padmini Srinivasan');
INSERT INTO HealthCareProviders (JobTitle, Name) VALUES ('Pulmonologist', 'Chen Sun');

INSERT INTO Patients (DateOfBirth, Sex, Ethnicity, Name, Email, City, Street, ZipCode) VALUES ('1980-04-15', 'Female', 'Caucasian', 'Emily Johnson', 'emily.johnson@example.com', 'Cedar Rapids', '123 Maple St', '52401');
INSERT INTO Patients (DateOfBirth, Sex, Ethnicity, Name, Email, City, Street, ZipCode) VALUES ('1992-08-22', 'Male', 'Hispanic', 'Carlos Ruiz', 'carlos.ruiz@example.com', 'Iowa City', '456 Oak Ave', '52240');
INSERT INTO Patients (DateOfBirth, Sex, Ethnicity, Name, Email, City, Street, ZipCode) VALUES ('1975-12-30', 'Other', 'Asian', 'Alex Kim', 'alex.kim@example.com', 'Davenport', '789 Pine Rd', '52803');
INSERT INTO Patients (DateOfBirth, Sex, Ethnicity, Name, Email, City, Street, ZipCode) VALUES ('2001-06-04', 'Female', 'African American', 'Jessica Brown', 'jessica.brown@example.com', 'Des Moines', '101 Birch Blvd', '50315');
INSERT INTO Patients (DateOfBirth, Sex, Ethnicity, Name, Email, City, Street, ZipCode) VALUES ('1988-01-19', 'Male', 'Native American', 'Michael White', 'michael.white@example.com', 'Ames', '202 Cedar Ln', '50010');
INSERT INTO Patients (DateOfBirth, Sex, Ethnicity, Name, Email, City, Street, ZipCode) VALUES ('1990-09-09', 'Prefer not to say', 'Mixed', 'Taylor Green', 'taylor.green@example.com', 'Waterloo', '303 Elm St', '50701');
INSERT INTO Patients (DateOfBirth, Sex, Ethnicity, Name, Email, City, Street, ZipCode) VALUES ('2003-03-21', 'Female', 'Middle Eastern', 'Sara Alizadeh', 'sara.alizadeh@example.com', 'West Des Moines', '404 Spruce Dr', '50265');
INSERT INTO Patients (DateOfBirth, Sex, Ethnicity, Name, Email, City, Street, ZipCode) VALUES ('1986-07-13', 'Male', 'Pacific Islander', 'Kai Turner', 'kai.turner@example.com', 'Ankeny', '505 Walnut St', '50023');

INSERT INTO HealthCareCenterPhoneNumbers (CenterId, PhoneNumber) VALUES (1, '+13195550101');
INSERT INTO HealthCareCenterPhoneNumbers (CenterId, PhoneNumber) VALUES (2, '+13195550202');
INSERT INTO HealthCareCenterPhoneNumbers (CenterId, PhoneNumber) VALUES (3, '+13195550303');
INSERT INTO HealthCareCenterPhoneNumbers (CenterId, PhoneNumber) VALUES (4, '+13195550404');
INSERT INTO HealthCareCenterPhoneNumbers (CenterId, PhoneNumber) VALUES (5, '+13195550505');
INSERT INTO HealthCareCenterPhoneNumbers (CenterId, PhoneNumber) VALUES (6, '+13195550606');

INSERT INTO HealthCareProviderSchedules (ProviderId, Schedule) VALUES (1, 'Monday - Friday: 8 AM - 5 PM');
INSERT INTO HealthCareProviderSchedules (ProviderId, Schedule) VALUES (1, 'Saturday: 9 AM - 12 PM');
INSERT INTO HealthCareProviderSchedules (ProviderId, Schedule) VALUES (2, 'Monday - Friday: 9 AM - 4 PM');
INSERT INTO HealthCareProviderSchedules (ProviderId, Schedule) VALUES (3, 'Monday - Friday: 10 AM - 6 PM');
INSERT INTO HealthCareProviderSchedules (ProviderId, Schedule) VALUES (4, 'Monday - Thursday: 7 AM - 3 PM');
INSERT INTO HealthCareProviderSchedules (ProviderId, Schedule) VALUES (4, 'Friday: 7 AM - 12 PM');
INSERT INTO HealthCareProviderSchedules (ProviderId, Schedule) VALUES (5, 'Monday - Wednesday: 8 AM - 4 PM');
INSERT INTO HealthCareProviderSchedules (ProviderId, Schedule) VALUES (5, 'Thursday - Friday: 8 AM - 2 PM');

INSERT INTO PatientPhoneNumbers (PatientId, PhoneNumber) VALUES (1, '+13195550123');
INSERT INTO PatientPhoneNumbers (PatientId, PhoneNumber) VALUES (2, '+13195550124');
INSERT INTO PatientPhoneNumbers (PatientId, PhoneNumber) VALUES (3, '+15635550125');
INSERT INTO PatientPhoneNumbers (PatientId, PhoneNumber) VALUES (4, '+15155550126');
INSERT INTO PatientPhoneNumbers (PatientId, PhoneNumber) VALUES (5, '+15155550127');
INSERT INTO PatientPhoneNumbers (PatientId, PhoneNumber) VALUES (6, '+13195550128');
INSERT INTO PatientPhoneNumbers (PatientId, PhoneNumber) VALUES (7, '+15155550129');
INSERT INTO PatientPhoneNumbers (PatientId, PhoneNumber) VALUES (8, '+15155550130');

INSERT INTO EHR (PatientId, HealthRecord) VALUES (1, 'Annual check-up completed. No issues reported. Vaccinations up to date.');
INSERT INTO EHR (PatientId, HealthRecord) VALUES (2, 'Patient diagnosed with type 2 diabetes. Recommended diet and exercise plan initiated.');
INSERT INTO EHR (PatientId, HealthRecord) VALUES (3, 'Routine dental examination performed. Cavity filled in lower molar.');
INSERT INTO EHR (PatientId, HealthRecord) VALUES (4, 'Consultation for reported migraines. MRI scheduled to rule out serious causes.');
INSERT INTO EHR (PatientId, HealthRecord) VALUES (5, 'Physical therapy sessions started for post-operative knee recovery.');
INSERT INTO EHR (PatientId, HealthRecord) VALUES (6, 'Allergy testing conducted. Patient allergic to pollen and dust mites.');
INSERT INTO EHR (PatientId, HealthRecord) VALUES (7, 'Pregnancy confirmed. Prenatal vitamins prescribed, and regular check-ups scheduled.');
INSERT INTO EHR (PatientId, HealthRecord) VALUES (8, 'Patient treated for a broken wrist. Cast applied and follow-up in six weeks.');

INSERT INTO WorksAt (CenterId, ProviderId, StartDate) VALUES (1, 1, '2021-05-01');
INSERT INTO WorksAt (CenterId, ProviderId, StartDate) VALUES (2, 2, '2020-03-15');
INSERT INTO WorksAt (CenterId, ProviderId, StartDate) VALUES (3, 3, '2019-07-20');
INSERT INTO WorksAt (CenterId, ProviderId, StartDate) VALUES (4, 4, '2022-01-10');
INSERT INTO WorksAt (CenterId, ProviderId, StartDate) VALUES (5, 5, '2018-11-05');
INSERT INTO WorksAt (CenterId, ProviderId, StartDate) VALUES (6, 1, '2022-06-01');
INSERT INTO WorksAt (CenterId, ProviderId, StartDate) VALUES (1, 3, '2022-02-15');
INSERT INTO WorksAt (CenterId, ProviderId, StartDate) VALUES (2, 5, '2021-09-20');

INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('10:00', '2023-10-05', 3, 2, 3, 1, 1, 'None');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('11:00', '2023-08-15', 1, 1, 1, 1, 5, 'Mild rash');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('09:30', '2023-11-12', 2, 5, 5, 2, 1, 'Slight fever');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('14:00', '2024-01-20', 4, 4, 4, 1, 7, 'Fatigue');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('16:00', '2024-02-25', 5, 3, 2, 1, 14, 'None');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('08:00', '2023-12-10', 6, 1, 6, 1, 12, 'Headache');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('15:00', '2024-03-15', 7, 2, 1, 1, 3, 'None');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('10:30', '2023-09-19', 8, 5, 3, 1, 11, 'Nausea');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('13:00', '2024-04-10', 1, 4, 4, 1, 9, 'Mild swelling at injection site');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('12:00', '2023-07-08', 3, 3, 5, 1, 8, 'None');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId, VialId, BatchId, AdverseEffectEvent) VALUES ('13:30', '2023-06-20', 7, 2, 1, 3, 1, 'Fatigue');
INSERT INTO Appointments (Time, Date, PatientId, ProviderId, CenterId) VALUES ('14:15', '2024-05-28', 2, 1, 1); -- this one is a future appointment

-- Creating views

-- This view is pretty simple. It filters out patient attributes to only include contact information, and attaches the stored patient phone number
CREATE VIEW View_PatientContactInfo AS
SELECT 
    p.PatientId,
    p.Name AS PatientName,
    pp.PhoneNumber AS PatientPhone,
    p.Email AS PatientEmail,
    p.Street AS PatientStreet,
    p.City AS PatientCity,
    p.ZipCode AS PatientZipCode
FROM 
    Patients p
LEFT JOIN 
    PatientPhoneNumbers pp ON p.PatientId = pp.PatientId;

-- This view combines simple batch information into tuples
CREATE VIEW View_SimpleBatchInformation AS
SELECT
    b.BatchId,
    b.Year,
    f.Formulation,
    a.AppointmentId
FROM
    Batches b
JOIN 
    Formulations f ON b.Formulation=f.Formulation
JOIN 
    Appointments a ON b.BatchId = a.BatchId
ORDER BY
    b.BatchId ASC;

-- Made this super convoluted view for some reason too, we can just ignore this 
CREATE VIEW View_ConvolutedBatchInformation AS
SELECT 
    DISTINCT b.BatchId,
    (SELECT COUNT(DISTINCT VialId) FROM Vaccines WHERE BatchId = b.BatchId) - 
    (SELECT COUNT(DISTINCT a.VialId) FROM Appointments a WHERE a.BatchId = b.BatchId) AS RemainingVials
FROM 
    Batches b
JOIN 
    Formulations f ON b.Formulation = f.Formulation
LEFT JOIN 
    Appointments a ON b.BatchId = a.BatchId
LEFT JOIN 
    Vaccines v ON v.BatchId = b.BatchId AND v.VialId = a.VialId
GROUP BY 
    b.BatchId, b.Year, f.Formulation, a.AppointmentId
ORDER BY
    b.BatchId ASC;

-- Queries
/* 
QUERY CRITERIA CHECKLIST:
=======================================
Involves join[3]: Q1, Q2, Q3, Q4, Q5
Involves aggregation[2]: Q2, Q4 
Involves subquery[1]: Q2
Involves view[1]: Q3
*/

-- Query 1: Get vaccination history for patient with Id = 1
SELECT 
    p.Name AS PatientName,
    CONCAT(b.Year, ' ', f.Formulation) AS VaccineType,
    a.Date AS VaccinationDate,
    a.AdverseEffectEvent AS AdverseEffects
FROM 
    Appointments a
JOIN 
    Patients p ON a.PatientId = p.PatientId
JOIN 
    Batches b ON a.BatchId = b.BatchId
JOIN 
    Formulations f ON b.Formulation = f.Formulation
WHERE 
	  a.Date < CURDATE() AND
    p.PatientId = 1
ORDER BY 
    a.Date DESC;

-- Query 2: Get average number of vaccinations by sex
SELECT
    t.Sex,
    AVG(t.TotalVaccinations) AS AverageVaccinations
FROM(
    SELECT
        p.Sex,
        COUNT(*) AS TotalVaccinations
    FROM
        Appointments a
    JOIN 
        Patients p ON a.PatientId = p.PatientId
    WHERE 
        a.Date < CURDATE()
    GROUP BY
        p.PatientId, p.Sex) AS t
GROUP BY t.Sex
ORDER BY 
	  AverageVaccinations DESC;
    
-- Query 3: Get VaccineType (Year_Formulation) of vaccine batches associated with adverse effect events
SELECT
	  DISTINCT CONCAT(b.Year, ' ', b.Formulation) AS VaccineType
FROM 
	  View_SimpleBatchInformation b
JOIN
	  Appointments a ON b.AppointmentId = a.AppointmentId
WHERE
	  a.AdverseEffectEvent <> 'None';
    
-- Query 4: Get the name of the health care center with the most (past) vaccination appointments
SELECT
	  c.CenterName
FROM 
	  HealthCareCenters c
JOIN
	  Appointments a ON c.CenterId = a.CenterId
WHERE
	  a.Date<CURDATE()
GROUP BY
	  c.CenterId
ORDER BY 
	  COUNT(a.AppointmentId) DESC
LIMIT 1; 

-- Query 5: Get information about upcoming appointment for patient with Id = 2
SELECT
    p.Name AS PatientName,
    hcp.Name AS HealthCareProvider,
      a.Time,
      a.Date,
      c.CenterName,
      DATEDIFF(a.Date, CURDATE()) AS DaysUntilAppointment
FROM
	  Patients p
JOIN
	  Appointments a ON p.PatientId = a.PatientId
JOIN
	  HealthCareProviders hcp ON a.ProviderId = hcp.ProviderId
JOIN
	  HealthCareCenters c ON a.CenterId = c.CenterId
WHERE
    a.Date > CURDATE() AND
    p.PatientId = 2;
      


