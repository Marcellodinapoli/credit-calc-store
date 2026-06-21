/// Servizio leggero legato all'account (nessun blocco globale app).
class SessionService {
  SessionService({required this.userId});

  final String userId;

  void dispose() {}
}
