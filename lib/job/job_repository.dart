import 'package:cloud_firestore/cloud_firestore.dart';

import 'job_models.dart';

class JobRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CompanyInfo> companies = [];
  List<JobOffer> offers = [];

  Future<void>? _loadFuture;

  Future<void> ensureLoaded() => _loadFuture ??= _loadAll();

  Future<void> _loadAll() async {
    await refreshOffers();
  }

  Future<void> refreshCompanies() async {
    // Le aziende si caricano on-demand con fetchCompanyById (solo quelle autorizzate).
    companies = [];
  }

  Future<void> refreshOffers() async {
    final snapshot = await _firestore
        .collection('job_offers')
        .where('status', isEqualTo: 'approved')
        .where('online', isEqualTo: true)
        .get();

    offers = snapshot.docs
        .map((doc) => JobOffer.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  CompanyInfo? companyOf(String name) {
    try {
      return companies.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  Future<CompanyInfo?> fetchCompanyById(String companyId) async {
    if (companyId.isEmpty) return null;

    final cached = companyOfById(companyId);
    if (cached != null) return cached;

    try {
      final doc = await _firestore.collection('companies').doc(companyId).get();
      if (!doc.exists) return null;

      final info = CompanyInfo.fromFirestore(doc.id, doc.data()!);
      companies = [
        ...companies.where((c) => c.companyId != companyId),
        info,
      ];
      return info;
    } catch (_) {
      return null;
    }
  }

  CompanyInfo? companyOfById(String companyId) {
    try {
      return companies.firstWhere((c) => c.companyId == companyId);
    } catch (_) {
      return null;
    }
  }
}
