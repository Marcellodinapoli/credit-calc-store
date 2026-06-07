// lib/pages/creditjob/creditjob_shell.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/job_theme.dart';
import '../../job/job_repository.dart';

import 'job_offers_page.dart';
import 'gestione_lavori_page.dart';

class CreditJobShell extends StatefulWidget {
  const CreditJobShell({super.key});

  @override
  State<CreditJobShell> createState() => _CreditJobShellState();
}

class _CreditJobShellState extends State<CreditJobShell> {
  final JobRepository _repo = JobRepository();

  /// Preferiti e candidature gestiti localmente (demo).
  final Set<String> _saved = <String>{};
  final Set<String> _applied = <String>{};

  Future<String?> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data()?['type'];
  }

  void _toggleSave(String id) {
    setState(() {
      if (_saved.contains(id)) {
        _saved.remove(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rimosso dai preferiti')),
        );
      } else {
        _saved.add(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aggiunto ai preferiti')),
        );
      }
    });
  }

  void _apply(String id) {
    if (_applied.contains(id)) return;
    setState(() {
      _applied.add(id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Candidatura inviata (demo).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Applica il tema Job e instrada in base al tipo utente
    return Theme(
      data: buildJobTheme(),
      child: FutureBuilder<String?>(
        future: _loadUserType(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userType = snapshot.data;

          // AZIENDA → Gestione lavori
          if (userType == 'company') {
            return const GestioneLavoriPage();
          }

          // UTENTE / WORK → Offerte di lavoro
          return JobOffersPage(
            repo: _repo,
            saved: _saved,
            applied: _applied,
            onToggleSave: _toggleSave,
            onApply: _apply,
          );
        },
      ),
    );
  }
}
