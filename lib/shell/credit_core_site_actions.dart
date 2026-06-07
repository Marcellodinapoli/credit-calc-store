import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openCreditCoreSite(BuildContext context, [String? userType]) async {
  var resolvedType = userType;
  if (resolvedType == null) {
    resolvedType = 'public';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      resolvedType = (doc.data()?['type'] ?? 'public').toString();
    }
  }

  final uri = Uri.parse(CreditCoreSiteUrls.siteUrlForUserType(resolvedType));
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Impossibile aprire ${CreditCoreSiteUrls.portalLabelForUserType(resolvedType)} '
          '(${uri.host})',
        ),
      ),
    );
  }
}

class UserSiteStream extends StatelessWidget {
  final Widget Function(String? userType, String siteHost) builder;

  const UserSiteStream({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return builder('public', CreditCoreSiteUrls.publicHost);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final userType = snap.data?.data()?['type']?.toString();
        final siteHost = CreditCoreSiteUrls.hostForUserType(userType);
        return builder(userType, siteHost);
      },
    );
  }
}

class CreditCoreSiteListTile extends StatelessWidget {
  final bool dense;
  final VoidCallback? onBeforeOpen;

  const CreditCoreSiteListTile({
    super.key,
    this.dense = false,
    this.onBeforeOpen,
  });

  @override
  Widget build(BuildContext context) {
    return UserSiteStream(
      builder: (userType, siteHost) {
        final portal = CreditCoreSiteUrls.portalLabelForUserType(userType);
        return ListTile(
          dense: dense,
          leading: Icon(Icons.language, size: dense ? 20 : 24),
          title: Text(
            'Vai al sito CreditCore',
            style: TextStyle(fontSize: dense ? 14 : 16),
          ),
          subtitle: Text('$portal · $siteHost'),
          onTap: () {
            onBeforeOpen?.call();
            openCreditCoreSite(context, userType);
          },
        );
      },
    );
  }
}

class CreditCoreSiteIconButton extends StatelessWidget {
  const CreditCoreSiteIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return UserSiteStream(
      builder: (userType, siteHost) {
        final portal = CreditCoreSiteUrls.portalLabelForUserType(userType);
        return IconButton(
          tooltip: 'Sito CreditCore $portal ($siteHost)',
          onPressed: () => openCreditCoreSite(context, userType),
          icon: const Icon(Icons.language),
        );
      },
    );
  }
}
