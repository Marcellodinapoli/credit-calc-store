import 'package:flutter/material.dart';

/// Sezione ecosistema CreditCore (CreditForm / CreditCalc / CreditJob).
class CreditCoreEcosystemSection {
  final String id;
  final String title;
  final String subtitle;
  final String body;
  final List<String> highlights;

  const CreditCoreEcosystemSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.highlights,
  });

  IconData get icon => switch (id) {
        'creditcalc' => Icons.calculate_outlined,
        'creditjob' => Icons.work_outline,
        _ => Icons.school_outlined,
      };

  Color get color => switch (id) {
        'creditcalc' => const Color(0xFF00B0FF),
        'creditjob' => const Color(0xFF00C4B3),
        _ => const Color(0xFFFFA726),
      };

  CreditCoreEcosystemSection copyWith({
    String? title,
    String? subtitle,
    String? body,
    List<String>? highlights,
  }) {
    return CreditCoreEcosystemSection(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      highlights: highlights ?? this.highlights,
    );
  }
}

const defaultEcosystemSectionIds = ['creditform', 'creditcalc', 'creditjob'];

const defaultEcosystemSections = <CreditCoreEcosystemSection>[
  CreditCoreEcosystemSection(
    id: 'creditform',
    title: 'CreditForm',
    subtitle: 'Formazione digitale',
    body:
        'Percorsi formativi strutturati con video, quiz, listening e role play '
        'per misurare i progressi e allenare le competenze operative nel credito.',
    highlights: [
      'Corsi e video formativi',
      'Quiz e listening',
      'Warm-Up AI e Roleplay AI',
      'Training contestazioni',
    ],
  ),
  CreditCoreEcosystemSection(
    id: 'creditcalc',
    title: 'CreditCalc',
    subtitle: 'Strumenti operativi',
    body:
        'Simulazioni, calcoli e strumenti per gestire creditori, piani di rientro, '
        'provvigioni e attività sul territorio con dati salvati sul profilo.',
    highlights: [
      'Creditori e anagrafiche',
      'Piani di rientro e saldo/stralcio',
      'Provvigioni e incassi',
      'Itinerario e agenda attività',
    ],
  ),
  CreditCoreEcosystemSection(
    id: 'creditjob',
    title: 'CreditJob',
    subtitle: 'Opportunità professionali',
    body:
        'Collegamenti tra aziende e professionisti: ricerca offerte, candidature '
        'e monitoraggio dello stato delle selezioni in un unico ambiente.',
    highlights: [
      'Offerte di lavoro',
      'Candidature e salvataggio annunci',
      'Monitoraggio selezioni',
    ],
  ),
];

CreditCoreEcosystemSection defaultEcosystemSectionForId(String id) {
  for (final section in defaultEcosystemSections) {
    if (section.id == id) return section;
  }
  return defaultEcosystemSections.first;
}
