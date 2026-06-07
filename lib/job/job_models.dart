// lib/creditjob/job_models.dart

// ================================================================
// IMPORT
// ================================================================
import 'package:cloud_firestore/cloud_firestore.dart';

// ================================================================
// ENUM
// ================================================================
enum JobSort { newest, companyAZ, titleAZ }
enum WorkMode { presence, hybrid, remote }

// ================================================================
// MODEL JOB OFFER
// ================================================================
class JobOffer {
  final String id;
  final String title;
  final String companyId;   // UID azienda
  final String company;     // companyName
  final String location;    // location
  final bool published;     // online
  final WorkMode mode;      // workMode
  final DateTime date;      // createdAt
  final String description;

  // ================= EXTRA FIELDS FIRESTORE =================
  final String? level;
  final String? department;
  final String? role;
  final int? positions;
  final String? education;
  final String? experience;
  final String? salary;
  final String? schedule;
  final String? skills;
  final String? niceSkills;
  final String? benefits;
  final String? tasks;
  final String? referencePerson;
  final String? hrEmail;
  final DateTime? expiryDate;
  final String? status;

  JobOffer({
    required this.id,
    required this.title,
    required this.companyId,
    required this.company,
    required this.location,
    required this.published,
    required this.mode,
    required this.date,
    required this.description,
    this.level,
    this.department,
    this.role,
    this.positions,
    this.education,
    this.experience,
    this.salary,
    this.schedule,
    this.skills,
    this.niceSkills,
    this.benefits,
    this.tasks,
    this.referencePerson,
    this.hrEmail,
    this.expiryDate,
    this.status,
  });

  // ================================================================
// FACTORY FROM FIRESTORE
// ================================================================
  factory JobOffer.fromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    // 🔹 Convert skills (List<Map>) → String
    String? parsedSkills;
    if (data['skills'] is List) {
      parsedSkills = (data['skills'] as List)
          .map((e) {
        if (e is Map && e['value'] != null) {
          final name = e['value'].toString();
          final required = e['required'] == true;
          return required ? "$name (obbligatorio)" : name;
        }
        return '';
      })
          .where((e) => e.isNotEmpty)
          .join(', ');
    } else {
      parsedSkills = data['skills']?.toString();
    }

    // 🔹 Convert salary range
    String? parsedSalary;
    final salaryFrom = data['salaryFrom'];
    final salaryTo = data['salaryTo'];
    final salaryMin = data['salaryMin'];
    final salaryMax = data['salaryMax'];

    if (salaryFrom != null || salaryTo != null) {
      parsedSalary =
      "${salaryFrom ?? '-'} - ${salaryTo ?? '-'} €";
    } else if (salaryMin != null || salaryMax != null) {
      parsedSalary =
      "${salaryMin ?? '-'} - ${salaryMax ?? '-'} €";
    }

    return JobOffer(
      id: id,
      title: data['title'] ?? '',
      companyId: data['companyId'] ?? '',
      company: data['companyName'] ?? '',
      location: data['location'] ?? '',
      published: data['online'] ?? false,
      mode: _parseMode(data['workMode']),
      date: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      description: data['description'] ?? '',
      level: data['level']?.toString(),
      department: data['department']?.toString(),
      role: data['role']?.toString(),
      positions: data['positions'],
      education: data['education']?.toString(),
      experience: data['experience']?.toString(),
      salary: parsedSalary,
      schedule: data['schedule']?.toString(),
      skills: parsedSkills,
      niceSkills: data['niceSkills']?.toString(),
      benefits: data['benefits']?.toString(),
      tasks: data['tasks']?.toString(),
      referencePerson: data['referencePerson']?.toString(),
      hrEmail: data['hrEmail']?.toString(),

      // 🔥 FIX DEFINITIVO expiryDate
      expiryDate: (() {
        final raw = data['expiryDate'];

        if (raw is Timestamp) {
          return raw.toDate().toLocal();
        }

        if (raw is String) {
          return DateTime.tryParse(raw)?.toLocal();
        }

        return null;
      })(),

      status: data['status']?.toString(),
    );
  }

  // ================================================================
  // PARSER WORK MODE
  // ================================================================
  static WorkMode _parseMode(dynamic value) {
    switch (value) {
      case 'remote':
        return WorkMode.remote;
      case 'hybrid':
        return WorkMode.hybrid;
      default:
        return WorkMode.presence;
    }
  }
}

// ================================================================
// MODEL COMPANY INFO
// ================================================================
class CompanyInfo {
  final String name;
  final String companyId;
  final String vat;
  final String hqCity;

  const CompanyInfo({
    required this.name,
    required this.companyId,
    required this.vat,
    required this.hqCity,
  });

  factory CompanyInfo.fromFirestore(String id, Map<String, dynamic> data) {
    return CompanyInfo(
      name: (data['companyName'] ?? '').toString(),
      companyId: (data['companyId'] ?? id).toString(),
      vat: (data['piva'] ?? '').toString(),
      hqCity: (data['address'] ?? data['hqCity'] ?? '').toString(),
    );
  }
}