import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/gestionale_connector_config.dart';
import '../models/gestionale_pratica.dart';

class GestionaleConnectorException implements Exception {
  GestionaleConnectorException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Client Credixa Connettore — pratiche in affido per consulenti esterni.
class CreditCalcGestionaleService {
  CreditCalcGestionaleService._();
  static final CreditCalcGestionaleService instance =
      CreditCalcGestionaleService._();

  static const _kUserId = 'credixa_cc_user_id';
  static const _kTenantSlug = 'credixa_cc_tenant_slug';
  static const _kTenantId = 'credixa_cc_tenant_id';
  static const _kEmail = 'credixa_cc_email';
  static const _kName = 'credixa_cc_name';

  final _secure = const FlutterSecureStorage();

  GestionaleCreditCalcProfile? _cached;

  GestionaleCreditCalcProfile? get cachedProfile => _cached;

  Future<GestionaleCreditCalcProfile?> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kUserId);
    final tenantSlug = prefs.getString(_kTenantSlug);
    final tenantId = prefs.getString(_kTenantId);
    final email = prefs.getString(_kEmail);
    final name = prefs.getString(_kName);
    if (userId == null ||
        tenantSlug == null ||
        tenantId == null ||
        email == null ||
        name == null) {
      _cached = null;
      return null;
    }
    _cached = GestionaleCreditCalcProfile(
      id: userId,
      email: email,
      name: name,
      tenantSlug: tenantSlug,
      tenantId: tenantId,
    );
    return _cached;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kTenantSlug);
    await prefs.remove(_kTenantId);
    await prefs.remove(_kEmail);
    await prefs.remove(_kName);
    await _secure.delete(key: 'credixa_cc_password');
    _cached = null;
  }

  Future<GestionaleCreditCalcProfile> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    final slug = tenantSlug.trim().isEmpty
        ? GestionaleConnectorConfig.defaultTenantSlug
        : tenantSlug.trim().toLowerCase();
    final data = await _postJson(
      GestionaleConnectorConfig.creditCalcPath(slug, '/login'),
      {
        'tenantSlug': slug,
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
    final profileMap = Map<String, dynamic>.from(data['profile'] as Map);
    final profile = GestionaleCreditCalcProfile(
      id: '${profileMap['id']}',
      email: '${profileMap['email']}',
      name: '${profileMap['name']}',
      tenantSlug: '${data['tenantSlug'] ?? slug}',
      tenantId: '${data['tenantId']}',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, profile.id);
    await prefs.setString(_kTenantSlug, profile.tenantSlug);
    await prefs.setString(_kTenantId, profile.tenantId);
    await prefs.setString(_kEmail, profile.email);
    await prefs.setString(_kName, profile.name);
    _cached = profile;
    return profile;
  }

  /// Dopo login app (stessa email/password): tenta sessione gestionale CreditCalc.
  /// Fallisce in silenzio se non è consulente abilitato o le credenziali non coincidono.
  Future<bool> tryAutoLinkFromAppLogin({
    required String email,
    required String password,
    String? tenantSlug,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final pwd = password;
    if (trimmedEmail.isEmpty || pwd.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final slug = (tenantSlug?.trim().isNotEmpty == true)
        ? tenantSlug!.trim().toLowerCase()
        : (prefs.getString(_kTenantSlug)?.trim().isNotEmpty == true
            ? prefs.getString(_kTenantSlug)!.trim().toLowerCase()
            : GestionaleConnectorConfig.defaultTenantSlug);

    try {
      await login(tenantSlug: slug, email: trimmedEmail, password: pwd);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureSession() async {
    final profile = _cached ?? await loadSavedSession();
    if (profile == null) {
      throw GestionaleConnectorException(
        'Collega l’account gestionale (consulente esterno).',
        statusCode: 401,
      );
    }
    await _postJson(
      GestionaleConnectorConfig.creditCalcPath(profile.tenantSlug, '/session'),
      {'userId': profile.id},
    );
  }

  Future<List<GestionalePraticaListItem>> listPratiche({
    int take = 50,
    int skip = 0,
  }) async {
    final profile = await _requireProfile();
    final data = await _postJson(
      GestionaleConnectorConfig.creditCalcPath(profile.tenantSlug, '/pratiche'),
      {'userId': profile.id, 'take': take, 'skip': skip},
    );
    final items = (data['items'] as List? ?? const [])
        .map((e) => GestionalePraticaListItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
    return items;
  }

  Future<GestionalePraticaDetail> getPratica(String praticaId) async {
    final profile = await _requireProfile();
    final data = await _postJson(
      GestionaleConnectorConfig.creditCalcPath(
        profile.tenantSlug,
        '/pratiche/$praticaId',
      ),
      {'userId': profile.id},
    );
    final pratica = Map<String, dynamic>.from(data['pratica'] as Map);
    final note = (data['note'] as List? ?? const [])
        .map((e) => GestionaleNota.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    List<Map<String, dynamic>> maps(String key) => (data[key] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return GestionalePraticaDetail(
      raw: pratica,
      note: note,
      debitoreRecapiti: maps('debitoreRecapiti'),
      garanti: maps('garanti'),
      garanteRecapiti: maps('garanteRecapiti'),
      rate: maps('rate'),
      incassi: maps('incassi'),
      fatture: maps('fatture'),
      documenti: maps('documenti'),
    );
  }

  Future<void> inviaLavorazione({
    required String praticaId,
    String? nota,
    String? codiceScarico,
  }) async {
    final profile = await _requireProfile();
    await _postJson(
      GestionaleConnectorConfig.creditCalcPath(
        profile.tenantSlug,
        '/pratiche/$praticaId/lavorazione',
      ),
      {
        'userId': profile.id,
        if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
        if (codiceScarico != null && codiceScarico.trim().isNotEmpty)
          'codiceScarico': codiceScarico.trim().toUpperCase(),
      },
    );
  }

  Future<GestionaleCreditCalcProfile> _requireProfile() async {
    final profile = _cached ?? await loadSavedSession();
    if (profile == null) {
      throw GestionaleConnectorException(
        'Sessione gestionale assente. Effettua il collegamento.',
        statusCode: 401,
      );
    }
    return profile;
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final key = GestionaleConnectorConfig.apiKey.trim();
    if (key.isNotEmpty) {
      headers['X-Connector-Key'] = key;
    }

    late http.Response res;
    try {
      res = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      throw GestionaleConnectorException(
        'Connettore non raggiungibile ($url). Verifica che sia avviato.',
      );
    }

    Map<String, dynamic> json = {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          json = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        /* ignore */
      }
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = json['error']?.toString() ??
          'Errore connettore (${res.statusCode})';
      throw GestionaleConnectorException(err, statusCode: res.statusCode);
    }
    return json;
  }
}

/// Codici scarico principali (allineati al catalogo Credixa).
const kCodiciScaricoCreditCalc = <String, String>{
  'PTC': 'Pagato / chiuso',
  'PPC': 'Promessa pagamento',
  'MOV': 'Inesigibile',
  'LPP': 'Piano di rientro',
  'LPT': 'Resa mandante',
};
