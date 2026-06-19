import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'user_subscription_service.dart';

/// Pubblico target del checkout Stripe.
enum SubscriptionBillingAudience {
  individual,
  company,
}

/// Integrazione Stripe Checkout / Customer Portal per cambio piano autonomo.
///
/// Configurare [checkoutUrls] e [customerPortalUrl] quando Stripe è attivo
/// (Payment Link per piano o endpoint backend che crea la Checkout Session).
abstract final class SubscriptionBillingService {
  /// Portale cliente Stripe (gestione metodo di pagamento, upgrade, annullo).
  static String? customerPortalUrl;

  /// URL checkout per piano. Chiavi: `individual:plus`, `company:starter`, …
  static final Map<String, String> checkoutUrls = {};

  static bool get isCheckoutConfigured => checkoutUrls.isNotEmpty;

  static bool get isPortalConfigured {
    final url = customerPortalUrl;
    return url != null && url.trim().isNotEmpty;
  }

  static String checkoutKey(SubscriptionBillingAudience audience, String planId) =>
      '${audience.name}:$planId';

  static bool planUsesStripeCheckout(String planId) => planId != 'free';

  /// Passa a un piano a pagamento: apre Stripe Checkout.
  /// Il piano gratuito viene applicato subito in app.
  static Future<void> changePlan({
    required SubscriptionBillingAudience audience,
    required String planId,
  }) async {
    if (!planUsesStripeCheckout(planId)) {
      await UserSubscriptionService.changePlan(planId);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Accedi per modificare il piano.');
    }

    final url = checkoutUrls[checkoutKey(audience, planId)];
    if (url == null || url.trim().isEmpty) {
      throw StateError(
        'Il pagamento Stripe non è ancora attivo. '
        'A breve potrai completare il cambio piano dalla sezione pagamenti.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final uri = Uri.parse(url).replace(
      queryParameters: {
        ...Uri.parse(url).queryParameters,
        'client_reference_id': uid,
        if (user?.email != null) 'prefilled_email': user!.email!,
      },
    );

    final opened = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('Impossibile aprire la pagina di pagamento Stripe.');
    }
  }

  /// Annullamento o gestione abbonamento tramite Stripe Customer Portal.
  static Future<void> openCustomerPortal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Accedi per gestire l\'abbonamento.');
    }

    final portal = customerPortalUrl?.trim();
    if (portal == null || portal.isEmpty) {
      throw StateError(
        'Il portale pagamenti Stripe non è ancora attivo. '
        'A breve potrai gestire l\'abbonamento in autonomia.',
      );
    }

    final uri = Uri.parse(portal).replace(
      queryParameters: {
        ...Uri.parse(portal).queryParameters,
        'client_reference_id': uid,
      },
    );

    final opened = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('Impossibile aprire il portale pagamenti Stripe.');
    }
  }
}
