class GestionalePraticaListItem {
  const GestionalePraticaListItem({
    required this.id,
    this.numero,
    this.stato,
    this.codiceScarico,
    this.residuo,
    this.numeroMandante,
    this.updatedAt,
    this.debitore,
    this.mandanteCodice,
    this.mandanteNome,
  });

  final String id;
  final String? numero;
  final String? stato;
  final String? codiceScarico;
  final double? residuo;
  final String? numeroMandante;
  final DateTime? updatedAt;
  final String? debitore;
  final String? mandanteCodice;
  final String? mandanteNome;

  factory GestionalePraticaListItem.fromJson(Map<String, dynamic> json) {
    return GestionalePraticaListItem(
      id: '${json['id']}',
      numero: json['numero']?.toString(),
      stato: json['stato']?.toString(),
      codiceScarico: json['codiceScarico']?.toString(),
      residuo: json['residuo'] == null
          ? null
          : double.tryParse(json['residuo'].toString()),
      numeroMandante: json['numeroMandante']?.toString(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      debitore: json['debitore']?.toString(),
      mandanteCodice: json['mandanteCodice']?.toString(),
      mandanteNome: json['mandanteNome']?.toString(),
    );
  }
}

class GestionaleNota {
  const GestionaleNota({
    required this.id,
    this.nota,
    this.createdAt,
    this.userName,
    this.fissata = false,
    this.importante = false,
  });

  final String id;
  final String? nota;
  final DateTime? createdAt;
  final String? userName;
  final bool fissata;
  final bool importante;

  factory GestionaleNota.fromJson(Map<String, dynamic> json) {
    return GestionaleNota(
      id: '${json['id']}',
      nota: json['nota']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      userName: json['userName']?.toString(),
      fissata: json['fissata'] == true,
      importante: json['importante'] == true,
    );
  }
}

class GestionalePraticaDetail {
  const GestionalePraticaDetail({
    required this.raw,
    required this.note,
    this.debitoreRecapiti = const [],
    this.garanti = const [],
    this.garanteRecapiti = const [],
    this.rate = const [],
    this.incassi = const [],
    this.fatture = const [],
    this.documenti = const [],
  });

  final Map<String, dynamic> raw;
  final List<GestionaleNota> note;
  final List<Map<String, dynamic>> debitoreRecapiti;
  final List<Map<String, dynamic>> garanti;
  final List<Map<String, dynamic>> garanteRecapiti;
  final List<Map<String, dynamic>> rate;
  final List<Map<String, dynamic>> incassi;
  final List<Map<String, dynamic>> fatture;
  final List<Map<String, dynamic>> documenti;

  String get id => '${raw['Id'] ?? raw['id'] ?? ''}';
  String? get numero => _s(raw['Numero'] ?? raw['numero']);
  String? get stato => _s(raw['Stato'] ?? raw['stato']);
  String? get codiceScarico =>
      _s(raw['CodiceScarico'] ?? raw['codiceScarico']);
  DateTime? get codiceScaricoAt =>
      _d(raw['CodiceScaricoAt'] ?? raw['codiceScaricoAt']);
  DateTime? get dataAffido => _d(raw['DataAffido'] ?? raw['dataAffido']);
  DateTime? get scadenza => _d(raw['Scadenza'] ?? raw['scadenza']);
  DateTime? get promessaAt => _d(raw['PromessaAt'] ?? raw['promessaAt']);
  String? get promessaMetodo =>
      _s(raw['PromessaMetodo'] ?? raw['promessaMetodo']);
  String? get numeroMandante =>
      _s(raw['NumeroMandante'] ?? raw['numeroMandante']);
  String? get contratto => _s(raw['Contratto'] ?? raw['contratto']);
  String? get commessa => _s(raw['Commessa'] ?? raw['commessa']);

  double? get residuo => _n(raw['Residuo'] ?? raw['residuo']);
  double? get capitale => _n(raw['Capitale'] ?? raw['capitale']);
  double? get interessi => _n(raw['Interessi'] ?? raw['interessi']);
  double? get spese => _n(raw['Spese'] ?? raw['spese']);
  double? get speseRecupero =>
      _n(raw['SpeseRecupero'] ?? raw['speseRecupero']);
  double? get importoRata => _n(raw['ImportoRata'] ?? raw['importoRata']);
  double? get rateArretrate =>
      _n(raw['RateArretrate'] ?? raw['rateArretrate']);
  double? get nettoDaPagare =>
      _n(raw['NettoDaPagare'] ?? raw['nettoDaPagare']);
  double? get totIncassato =>
      _n(raw['TotIncassato'] ?? raw['totIncassato']);
  double? get importoTotale =>
      _n(raw['ImportoTotale'] ?? raw['importoTotale']);
  double? get promessaImporto =>
      _n(raw['PromessaImporto'] ?? raw['promessaImporto']);
  int? get numeroRateScadute {
    final v = raw['NumeroRateScadute'] ?? raw['numeroRateScadute'];
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  String get debitore {
    final c = (raw['DebitoreCognome'] ?? '').toString();
    final n = (raw['DebitoreNome'] ?? '').toString();
    return '$c $n'.trim();
  }

  String? get debitoreCf =>
      _s(raw['DebitoreCodiceFiscale'] ?? raw['DebitoreCF']);
  String? get debitoreTelefono => _s(raw['DebitoreTelefono']);
  String? get debitoreEmail => _s(raw['DebitoreEmail']);
  String? get debitoreIndirizzo {
    final ind = _s(raw['DebitoreIndirizzo']);
    final cap = _s(raw['DebitoreCap']);
    final citta = _s(raw['DebitoreCitta']);
    final prov = _s(raw['DebitoreProvincia']);
    final parts = [
      if (ind != null) ind,
      if (cap != null || citta != null)
        [cap, citta].whereType<String>().join(' '),
      if (prov != null) '($prov)',
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  String? get mandante {
    final rs = _s(raw['MandanteRagioneSociale']);
    final cod = _s(raw['MandanteCodice']);
    if (rs != null && cod != null) return '$rs ($cod)';
    return rs ?? cod;
  }

  String? get assegnatarioName => _s(raw['AssegnatarioName']);

  List<Map<String, dynamic>> recapitiGarante(String garanteId) {
    return garanteRecapiti
        .where((r) => '${r['GaranteId'] ?? r['garanteId']}' == garanteId)
        .toList();
  }

  static String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _n(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  static DateTime? _d(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

class GestionaleCreditCalcProfile {
  const GestionaleCreditCalcProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.tenantSlug,
    required this.tenantId,
  });

  final String id;
  final String email;
  final String name;
  final String tenantSlug;
  final String tenantId;
}
