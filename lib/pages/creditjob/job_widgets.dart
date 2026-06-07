import 'package:flutter/material.dart';
import '../../job/job_models.dart';
import '../../core/job_theme.dart';

class CompanyChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const CompanyChip({super.key, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 16, color: Colors.black45),
            SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class AppliedPill extends StatelessWidget {
  const AppliedPill({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kJobBrandLight,
        border: Border.all(color: kJobBrand),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Candidatura inviata',
        style: TextStyle(color: kJobBrand, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ModeBadge extends StatelessWidget {
  final WorkMode mode;
  const ModeBadge({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    switch (mode) {
      case WorkMode.presence:
        color = const Color(0xFF2E7D32); // verde presenza
        text = 'Presenza';
        break;
      case WorkMode.hybrid:
        color = const Color(0xFFEF6C00); // arancio ibrido
        text = 'Ibrido';
        break;
      case WorkMode.remote:
        color = const Color(0xFF1565C0); // blu remote
        text = 'Remote';
        break;
    }
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

Widget rowIconText(IconData icon, String text) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, size: 18, color: Colors.black45),
    const SizedBox(width: 6),
    Text(text, style: const TextStyle(color: Colors.black87)),
  ],
);

String initials(String name) {
  final parts = name.replaceAll('.', '').trim().split(RegExp(r'\s+'));
  final chars = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join();
  return chars.toUpperCase();
}

/// Card per visualizzare un’offerta di lavoro
class JobOfferCard extends StatelessWidget {
  final JobOffer offer;
  final bool saved;
  final bool applied;
  final VoidCallback onToggleSave;
  final VoidCallback onApply;

  const JobOfferCard({
    super.key,
    required this.offer,
    required this.saved,
    required this.applied,
    required this.onToggleSave,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo e save
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: kJobBrandLight,
                  child: Text(initials(offer.company),
                      style: const TextStyle(
                          color: kJobBrand, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(offer.company,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                      color: saved ? kJobBrand : Colors.grey),
                  onPressed: onToggleSave,
                )
              ],
            ),
            const SizedBox(height: 12),
            rowIconText(Icons.location_on_outlined, offer.location),
            const SizedBox(height: 6),
            ModeBadge(mode: offer.mode),
            const SizedBox(height: 12),
            if (applied)
              const AppliedPill()
            else
              ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kJobBrand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Candidati"),
              ),
          ],
        ),
      ),
    );
  }
}
