// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_form_fields.dart';
import '../../core/dimensions.dart';

// -----------------------------------------------------------------------------
// PAGE ROOT
// -----------------------------------------------------------------------------
class CreateJobOfferWizardPage extends StatefulWidget {
  final String companyId;
  final String? jobId; // 👈 modalità modifica

  const CreateJobOfferWizardPage({
    super.key,
    required this.companyId,
    this.jobId, // 👈 opzionale
  });

  @override
  State<CreateJobOfferWizardPage> createState() =>
      _CreateJobOfferWizardPageState();
}

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
class _CreateJobOfferWizardPageState
    extends State<CreateJobOfferWizardPage> {

  // ---------------------------------------------------------------------------
  // CONFIG
  // ---------------------------------------------------------------------------
  final _totalSteps = 5;
  final _minScoreToPublish = 70;

  // ---------------------------------------------------------------------------
// STATE VARIABLES
// ---------------------------------------------------------------------------
  int _currentStep = 0;
  bool _isSaving = false;
  bool _acceptedConditions = false;

  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();

  final _salaryFromCtrl = TextEditingController();
  final _salaryToCtrl = TextEditingController();

  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();

  final _benefitsCtrl = TextEditingController();
  final _positionsCtrl = TextEditingController(text: "1");

  String _contractType = "Tempo indeterminato";
  String _workMode = "In sede";
  String _schedule = "Full-time";

  final List<String> _skillOptions = [
    "Negoziazione",
    "Recupero crediti",
    "Call center",
    "Competenze organizzative",
  ];

  List<Map<String, dynamic>> _skills = [];
// ---------------------------------------------------------------------------
// LIFECYCLE
// ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    if (widget.jobId != null) {
      _loadExistingOffer();
    }
  }

  Future<void> _loadExistingOffer() async {
    final doc = await FirebaseFirestore.instance
        .collection('job_offers')
        .doc(widget.jobId)
        .get();

    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;

    _titleCtrl.text = data['title'] ?? '';
    _locationCtrl.text = data['location'] ?? '';
    _descriptionCtrl.text = data['description'] ?? '';
    _experienceCtrl.text = data['experience'] ?? '';
    _educationCtrl.text = data['education'] ?? '';

    _salaryFromCtrl.text = data['salaryFrom']?.toString() ?? '';
    _salaryToCtrl.text = data['salaryTo']?.toString() ?? '';
    _salaryMinCtrl.text = data['salaryMin']?.toString() ?? '';
    _salaryMaxCtrl.text = data['salaryMax']?.toString() ?? '';

    _benefitsCtrl.text = data['benefits'] ?? '';
    _positionsCtrl.text = data['positions']?.toString() ?? '1';

    _contractType = data['contractType'] ?? _contractType;
    _workMode = data['workMode'] ?? _workMode;
    _schedule = data['schedule'] ?? _schedule;

    if (data['skills'] is List) {
      _skills = List<Map<String, dynamic>>.from(data['skills']);
    }

    if (mounted) setState(() {});
  }
  // ---------------------------------------------------------------------------
  // VALIDATION / SCORE
  // ---------------------------------------------------------------------------
  int _calculateScore() {
    int score = 0;

    if (_titleCtrl.text.isNotEmpty) score += 10;
    if (_descriptionCtrl.text.length > 300) score += 20;
    if (_salaryMinCtrl.text.isNotEmpty &&
        _salaryMaxCtrl.text.isNotEmpty) {
      score += 20;
    }
    if (_experienceCtrl.text.isNotEmpty) score += 10;
    if (_educationCtrl.text.isNotEmpty) score += 10;
    if (_benefitsCtrl.text.isNotEmpty) score += 10;
    if (_workMode.isNotEmpty && _schedule.isNotEmpty) score += 15;
    if (_positionsCtrl.text.isNotEmpty) score += 15;

    return score;
  }

// ---------------------------------------------------------------------------
// SERVICES (Firestore)
// ---------------------------------------------------------------------------
  Future<void> _saveOffer() async {
    final score = _calculateScore();

    if (score < _minScoreToPublish) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Qualità insufficiente. Completa l'annuncio (min 70%)"),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final salaryFrom = int.tryParse(_salaryFromCtrl.text.trim());
    final salaryTo = int.tryParse(_salaryToCtrl.text.trim());
    final salaryMin = int.tryParse(_salaryMinCtrl.text.trim());
    final salaryMax = int.tryParse(_salaryMaxCtrl.text.trim());

    // ✅ Recupero nome azienda corretto
    final companySnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .get();

    final companyName =
        companySnapshot.data()?['companyName']?.toString() ?? '';

    final data = {
      "companyId": widget.companyId,
      "companyName": companyName, // ✅ ora salvato correttamente
      "title": _titleCtrl.text.trim(),
      "location": _locationCtrl.text.trim(),
      "positions": int.tryParse(_positionsCtrl.text) ?? 1,
      "contractType": _contractType,
      "workMode": _workMode,
      "schedule": _schedule,
      "description": _descriptionCtrl.text.trim(),
      "experience": _experienceCtrl.text.trim(),
      "education": _educationCtrl.text.trim(),
      "salaryFrom": salaryFrom,
      "salaryTo": salaryTo,
      "salaryMin": salaryMin,
      "salaryMax": salaryMax,
      "benefits": _benefitsCtrl.text.trim(),
      "skills": _skills,
      "qualityScore": score,
      "status": "pending",
      "applicationsCount": 0,
    };

    if (widget.jobId == null) {
      await FirebaseFirestore.instance
          .collection('job_offers')
          .add({
        ...data,
        "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance
          .collection('job_offers')
          .doc(widget.jobId)
          .update(data);
    }

    if (mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final pagePadding = Dimensions.pagePaddingInsetsFor(context);
    final bottomInset = Dimensions.overlayBottomInset(context);
    final sectionSpacing = Dimensions.sectionSpacingFor(context);
    final maxWidth = Dimensions.isPhone(context)
        ? double.infinity
        : 900.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        title: const Text("Nuova offerta di lavoro"),
      ),
      body: SafeArea(
        left: false,
        right: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                pagePadding.left,
                pagePadding.top,
                pagePadding.right,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProgressBar(),
                  SizedBox(height: sectionSpacing),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: sectionSpacing),
                      child: _buildStepContent(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 12,
                      bottom: bottomInset,
                    ),
                    child: _buildNavigation(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// ---------------------------------------------------------------------------
// UI – STEP FLOW (gestione wizard)
// ---------------------------------------------------------------------------

  Widget _buildProgressBar() {
    final score = _calculateScore();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: (_currentStep + 1) / _totalSteps,
          minHeight: 6,
          color: Colors.blue,
          backgroundColor: Colors.grey.shade200,
        ),
        const SizedBox(height: 8),
        Text(
          "Step ${_currentStep + 1} di $_totalSteps  •  Qualità annuncio: $score%",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _stepBasic();
      case 1:
        return _stepDescription();
      case 2:
        return _stepRequirements();
      case 3:
        return _stepCompensation();
      case 4:
        return _stepReview();
      default:
        return const SizedBox();
    }
  }

  Widget _buildNavigation() {

    final score = _calculateScore();

    final canPublish =
        score >= _minScoreToPublish &&
            _acceptedConditions &&
            !_isSaving;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton(
            onPressed: () => setState(() => _currentStep--),
            child: const Text("Indietro"),
          )
        else
          const SizedBox(width: 100),

        _currentStep == _totalSteps - 1
            ? ElevatedButton(
          onPressed: canPublish ? _saveOffer : null,
          child: const Text("Pubblica"),
        )
            : ElevatedButton(
          onPressed: () => setState(() => _currentStep++),
          child: const Text("Avanti"),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // UI – STEP SCREENS (contenuto singoli step)
  // ---------------------------------------------------------------------------

  Widget _stepBasic() {
    return _card([
      _field(_titleCtrl, "Titolo posizione"),
      _field(_locationCtrl, "Sede di lavoro"),
      _field(_positionsCtrl, "Numero posizioni", isNumber: true),
      const SizedBox(height: 16),
      _dropdown(
        "Tipologia contratto",
        _contractType,
        ["Tempo indeterminato", "Tempo determinato", "Stage", "Partita IVA"],
            (v) => setState(() => _contractType = v),
      ),
      _dropdown(
        "Modalità lavoro",
        _workMode,
        ["In sede", "Ibrido", "Remoto"],
            (v) => setState(() => _workMode = v),
      ),
      _dropdown(
        "Orario",
        _schedule,
        ["Full-time", "Part-time"],
            (v) => setState(() => _schedule = v),
      ),
    ]);
  }

  Widget _stepDescription() {
    return _card([
      _field(_descriptionCtrl, "Descrizione ruolo", maxLines: 6),
    ]);
  }

  Widget _stepRequirements() {
    return _card([
      _field(_experienceCtrl, "Esperienza richiesta (anni)"),
      _field(_educationCtrl, "Titolo di studio"),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _field(_salaryFromCtrl, "Stipendio da", isNumber: true)),
          const SizedBox(width: 16),
          Expanded(child: _field(_salaryToCtrl, "Stipendio a", isNumber: true)),
        ],
      ),
      const SizedBox(height: 24),
      const Text(
        "Competenze richieste",
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      ...List.generate(_skills.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _skills[index]["value"] as String?,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: _skillOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _skills[index] = {
                        "value": v,
                        "required": _skills[index]["required"] ?? false,
                      };
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: (_skills[index]["required"] ?? false) as bool,
                    onChanged: (v) {
                      setState(() {
                        _skills[index]["required"] = v ?? false;
                      });
                    },
                  ),
                  if ((_skills[index]["required"] ?? false) == true)
                    const Text(
                      "(obbligatorio)",
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () {
                  setState(() {
                    _skills.removeAt(index);
                  });
                },
              ),
            ],
          ),
        );
      }),
      TextButton.icon(
        onPressed: () {
          setState(() {
            _skills.add({
              "value": _skillOptions.first,
              "required": false,
            });
          });
        },
        icon: const Icon(Icons.add),
        label: const Text("Aggiungi competenza"),
      ),
    ]);
  }

  Widget _stepCompensation() {
    return _card([
      Row(
        children: [
          Expanded(child: _field(_salaryMinCtrl, "RAL Min", isNumber: true)),
          const SizedBox(width: 16),
          Expanded(child: _field(_salaryMaxCtrl, "RAL Max", isNumber: true)),
        ],
      ),
      const SizedBox(height: 16),
      _field(_benefitsCtrl, "Benefit", maxLines: 3),
    ]);
  }

  Widget _stepReview() {
    final score = _calculateScore();

    final salaryFrom = _salaryFromCtrl.text.trim();
    final salaryTo = _salaryToCtrl.text.trim();

    String salarySummary = "-";
    if (salaryFrom.isNotEmpty && salaryTo.isNotEmpty) {
      salarySummary = "$salaryFrom - $salaryTo";
    } else if (salaryFrom.isNotEmpty) {
      salarySummary = "Da $salaryFrom";
    } else if (salaryTo.isNotEmpty) {
      salarySummary = "Fino a $salaryTo";
    }

    final skillsSummary = _skills
        .where((s) => (s["value"] ?? "").toString().trim().isNotEmpty)
        .map((s) {
      final name = s["value"].toString();
      final required = (s["required"] ?? false) == true;
      return required ? "$name (obbligatorio)" : name;
    }).join(", ");

    return _card([
      const Text(
        "Riepilogo finale",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      _summary("Titolo", _titleCtrl.text),
      _summary("Sede", _locationCtrl.text),
      _summary("Contratto", _contractType),
      _summary("Modalità", _workMode),
      _summary("Orario", _schedule),
      _summary("Retribuzione", salarySummary),
      _summary("RAL", _buildRalSummary()),
      _summary("Titolo di studio", _educationCtrl.text),
      _summary("Esperienza richiesta", _experienceCtrl.text),
      _summary("Competenze", skillsSummary),
      _summary("Benefit", _benefitsCtrl.text),
      const SizedBox(height: 16),

      Text(
        score >= _minScoreToPublish
            ? "Pronto per la pubblicazione"
            : "Completa l'annuncio per migliorare la qualità (min 70%)",
        style: TextStyle(
          color: score >= _minScoreToPublish ? Colors.green : Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),

      const SizedBox(height: 24),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acceptedConditions,
            onChanged: (v) {
              setState(() {
                _acceptedConditions = v ?? false;
              });
            },
          ),
          Expanded(
            child: Wrap(
              children: [
                const Text(
                  "Dichiaro di aver letto e accettato le ",
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: SizedBox(
                          width: 420,
                          height: 420,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Condizioni pubblicazione",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('settings')
                                        .doc('job_offer_rules')
                                        .get(),
                                    builder: (context, snap) {
                                      if (!snap.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      final data =
                                      snap.data!.data() as Map<String, dynamic>?;

                                      final text = data?['text'] ??
                                          "Regolamento non disponibile.";

                                      return SingleChildScrollView(
                                        child: Text(text),
                                      );
                                    },
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Chiudi"),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "condizioni di pubblicazione",
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // UI – FORMATTERS (solo trasformazione dati)
  // ---------------------------------------------------------------------------

  String _buildRalSummary() {
    final min = _salaryMinCtrl.text.trim();
    final max = _salaryMaxCtrl.text.trim();
    if (min.isNotEmpty && max.isNotEmpty) return "$min - $max €";
    if (min.isNotEmpty) return "Da $min €";
    if (max.isNotEmpty) return "Fino a $max €";
    return "-";
  }

  // ---------------------------------------------------------------------------
  // UI – COMPONENTS (blocchi riutilizzabili)
  // ---------------------------------------------------------------------------

  Widget _card(List<Widget> children) {
    final cardPadding = Dimensions.isPhone(context) ? 16.0 : 24.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {int maxLines = 1, bool isNumber = false}) {
    return appFormTextField(
      label: label,
      controller: c,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      padding: const EdgeInsets.only(bottom: 16),
    );
  }

  Widget _dropdown(
      String label,
      String value,
      List<String> items,
      Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: appFormFieldDecoration(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  Widget _summary(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text("$label: ${value.isEmpty ? "-" : value}"),
    );
  }
}