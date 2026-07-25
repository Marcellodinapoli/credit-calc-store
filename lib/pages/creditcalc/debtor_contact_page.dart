import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/dimensions.dart';
import '../../services/debtor_contact_launcher.dart';
import '../../services/debtor_message_templates.dart';
import 'installment_monitor_page.dart';

class DebtorContactPracticeOption {
  const DebtorContactPracticeOption({
    required this.key,
    required this.companyName,
    required this.creditorName,
  });

  final String key;
  final String companyName;
  final String creditorName;
}

List<DebtorContactPracticeOption> debtorContactPracticesFromEntries(
  List<CommissionEntryRecord> entries,
) {
  final seen = <String>{};
  final options = <DebtorContactPracticeOption>[];
  for (final entry in entries) {
    final company = CommissionCollectionsHelper.companyName(entry.data);
    if (company.isEmpty) continue;
    final creditorId = (entry.data['creditorId'] ?? '').toString();
    final key = '$creditorId::$company';
    if (!seen.add(key)) continue;
    options.add(
      DebtorContactPracticeOption(
        key: key,
        companyName: company,
        creditorName: CommissionCollectionsHelper.creditorName(entry.data),
      ),
    );
  }
  options.sort(
    (a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()),
  );
  return options;
}

enum _ContactChannel { whatsapp, email }

class DebtorContactPage extends StatefulWidget {
  const DebtorContactPage({super.key});

  @override
  State<DebtorContactPage> createState() => _DebtorContactPageState();
}

class _DebtorContactPageState extends State<DebtorContactPage> {
  _ContactChannel _channel = _ContactChannel.whatsapp;
  DebtorMessageKind _messageKind = DebtorMessageKind.coordinate;

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _installmentDetailCtrl = TextEditingController();

  String? _selectedCreditorId;
  String? _selectedPaymentMethodKey;
  DebtorContactPracticeOption? _selectedPractice;
  SollecitoInstallmentOption? _selectedInstallment;

  bool _busy = false;
  bool _messageEditedManually = false;
  List<CreditorRecord> _lastCreditors = const [];
  List<CommissionEntryRecord> _lastEntries = const [];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _installmentDetailCtrl.dispose();
    super.dispose();
  }

  void _onMessageKindChanged(DebtorMessageKind? kind) {
    if (kind == null) return;
    setState(() {
      _messageKind = kind;
      _messageEditedManually = kind == DebtorMessageKind.libero;
      if (kind == DebtorMessageKind.libero) {
        _messageCtrl.clear();
        _subjectCtrl.clear();
      } else {
        _applyTemplateMessage(
          creditors: _lastCreditors,
          entries: _lastEntries,
        );
      }
    });
  }

  List<CreditorPaymentMethodOption> _paymentMethodsForSelectedCreditor(
    List<CreditorRecord> creditors,
  ) {
    if (_selectedCreditorId == null) return const [];
    for (final creditor in creditors) {
      if (creditor.id == _selectedCreditorId) {
        return DebtorMessageTemplates.paymentMethodsForCreditor(creditor.data);
      }
    }
    return const [];
  }

  CreditorPaymentMethodOption? _selectedPaymentMethod(
    List<CreditorPaymentMethodOption> methods,
  ) {
    if (_selectedPaymentMethodKey == null) return null;
    for (final method in methods) {
      if (method.key == _selectedPaymentMethodKey) return method;
    }
    return null;
  }

  void _applyTemplateMessage({
    List<CreditorRecord>? creditors,
    List<CommissionEntryRecord>? entries,
  }) {
    if (_messageEditedManually && _messageKind != DebtorMessageKind.libero) {
      return;
    }

    switch (_messageKind) {
      case DebtorMessageKind.libero:
        return;
      case DebtorMessageKind.coordinate:
        final methods = creditors == null
            ? const <CreditorPaymentMethodOption>[]
            : _paymentMethodsForSelectedCreditor(creditors);
        final method = _selectedPaymentMethod(methods);
        if (method == null) {
          _messageCtrl.clear();
          return;
        }
        _messageCtrl.text = DebtorMessageTemplates.coordinateMessage(
          paymentMethodLabel: method.label,
          coordinatesText: method.coordinatesText,
          installmentDetail: _installmentDetailCtrl.text,
        );
        final creditorName = _creditorName(creditors);
        _subjectCtrl.text = DebtorMessageTemplates.emailSubjectForKind(
          DebtorMessageKind.coordinate,
          reference: creditorName,
        );
      case DebtorMessageKind.sollecito:
        final installment = _selectedInstallment;
        if (installment == null) {
          _messageCtrl.clear();
          return;
        }
        _messageCtrl.text = DebtorMessageTemplates.sollecitoMessage(
          companyName: installment.companyName,
          amount: installment.amount,
          collectionDate: installment.collectionDate,
        );
        _subjectCtrl.text = DebtorMessageTemplates.emailSubjectForKind(
          DebtorMessageKind.sollecito,
          reference: installment.companyName,
        );
    }
  }

  String _creditorName(List<CreditorRecord>? creditors) {
    if (creditors == null || _selectedCreditorId == null) return '';
    for (var i = 0; i < creditors.length; i++) {
      if (creditors[i].id == _selectedCreditorId) {
        return creditorDisplayLabel(i, creditors[i].data);
      }
    }
    return '';
  }

  List<SollecitoInstallmentOption> _installmentsForSelectedPractice(
    List<CommissionEntryRecord> entries,
  ) {
    final practice = _selectedPractice;
    if (practice == null) return const [];
    return DebtorMessageTemplates.installmentsForPractice(entries, practice.key);
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final ok = _channel == _ContactChannel.whatsapp
          ? await DebtorContactLauncher.openWhatsApp(
              phone: _phoneCtrl.text,
              message: _messageCtrl.text,
            )
          : await DebtorContactLauncher.openEmail(
              email: _emailCtrl.text,
              subject: _subjectCtrl.text,
              body: _messageCtrl.text,
            );

      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _channel == _ContactChannel.whatsapp
                  ? 'Impossibile aprire WhatsApp. Verifica il numero.'
                  : 'Impossibile aprire il client email. Verifica l\'indirizzo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _validateAndSend() {
    if (_channel == _ContactChannel.whatsapp) {
      final digits = DebtorContactLauncher.normalizePhoneForWhatsApp(
        _phoneCtrl.text,
      );
      if (digits.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserisci un numero di telefono valido.')),
        );
        return;
      }
    } else {
      if (!DebtorContactLauncher.looksLikeEmail(_emailCtrl.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserisci un indirizzo email valido.')),
        );
        return;
      }
    }
    if (_messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrivi un messaggio prima di inviare.')),
      );
      return;
    }
    if (_messageKind == DebtorMessageKind.coordinate &&
        _selectedCreditorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un creditore.')),
      );
      return;
    }
    if (_messageKind == DebtorMessageKind.coordinate &&
        _selectedPaymentMethodKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una modalità di pagamento.')),
      );
      return;
    }
    if (_messageKind == DebtorMessageKind.sollecito &&
        _selectedInstallment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona pratica e rata.')),
      );
      return;
    }
    _send();
  }

  Widget _buildChannelSelector() {
    if (Dimensions.isPhone(context)) {
      return DropdownButtonFormField<_ContactChannel>(
        value: _channel,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Canale',
          border: OutlineInputBorder(),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        items: const [
          DropdownMenuItem(
            value: _ContactChannel.whatsapp,
            child: Text('WhatsApp'),
          ),
          DropdownMenuItem(
            value: _ContactChannel.email,
            child: Text('Email'),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _channel = value);
        },
      );
    }

    return SegmentedButton<_ContactChannel>(
      segments: const [
        ButtonSegment(
          value: _ContactChannel.whatsapp,
          label: Text('WhatsApp'),
          icon: Icon(Icons.chat_outlined),
        ),
        ButtonSegment(
          value: _ContactChannel.email,
          label: Text('Email'),
          icon: Icon(Icons.mail_outline),
        ),
      ],
      selected: {_channel},
      onSelectionChanged: (values) {
        setState(() => _channel = values.first);
      },
    );
  }

  Widget _messageKindSelector() {
    return DropdownButtonFormField<DebtorMessageKind>(
      value: _messageKind,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tipo di messaggio',
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      items: [
        for (final kind in DebtorMessageKind.values)
          DropdownMenuItem(value: kind, child: Text(kind.label)),
      ],
      onChanged: _onMessageKindChanged,
    );
  }

  Widget _coordinateSection(
    List<CreditorRecord> creditors,
  ) {
    final paymentMethods = _paymentMethodsForSelectedCreditor(creditors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('debtor-creditor'),
          value: _selectedCreditorId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Creditore',
            border: OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          hint: const Text('Seleziona creditore'),
          items: [
            for (var i = 0; i < creditors.length; i++)
              DropdownMenuItem(
                value: creditors[i].id,
                child: Text(
                  creditorDisplayLabel(i, creditors[i].data),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            setState(() {
              _selectedCreditorId = id;
              _selectedPaymentMethodKey = null;
              _messageEditedManually = false;
              _applyTemplateMessage(creditors: creditors);
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('debtor-payment-$_selectedCreditorId'),
          value: _selectedPaymentMethodKey,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Modalità di pagamento',
            border: OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          hint: const Text('Seleziona modalità'),
          items: [
            for (final method in paymentMethods)
              DropdownMenuItem(
                value: method.key,
                child: Text(method.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: paymentMethods.isEmpty
              ? null
              : (key) {
                  setState(() {
                    _selectedPaymentMethodKey = key;
                    _messageEditedManually = false;
                    _applyTemplateMessage(creditors: creditors);
                  });
                },
        ),
        if (_selectedCreditorId != null && paymentMethods.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Nessuna modalità con coordinate configurate per questo creditore.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _installmentDetailCtrl,
          decoration: const InputDecoration(
            labelText: 'Dettaglio rata',
            hintText: 'Es. di marzo 2026 / n. 3 del piano',
            border: OutlineInputBorder(),
            helperText: 'Completi tu la parte "... per il pagamento della rata ..."',
          ),
          onChanged: (_) {
            setState(() {
              _messageEditedManually = false;
              _applyTemplateMessage(creditors: creditors);
            });
          },
        ),
      ],
    );
  }

  Widget _sollecitoSection(
    List<DebtorContactPracticeOption> practices,
    List<CommissionEntryRecord> entries,
  ) {
    final installments = _installmentsForSelectedPractice(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<DebtorContactPracticeOption>(
          key: const ValueKey('sollecito-practice'),
          value: _selectedPractice,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Pratica da provvigioni',
            border: OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          hint: const Text('Seleziona pratica'),
          items: [
            for (final practice in practices)
              DropdownMenuItem(
                value: practice,
                child: Text(
                  practice.creditorName.isEmpty
                      ? practice.companyName
                      : '${practice.companyName} · ${practice.creditorName}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: practices.isEmpty
              ? null
              : (practice) {
                  setState(() {
                    _selectedPractice = practice;
                    _selectedInstallment = null;
                    _messageEditedManually = false;
                    _applyTemplateMessage(entries: entries);
                  });
                },
        ),
        if (practices.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Nessuna pratica in provvigioni. Esporta un piano per abilitare il sollecito.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<SollecitoInstallmentOption>(
          key: ValueKey('sollecito-rate-${_selectedPractice?.key}'),
          value: _selectedInstallment,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Rata da sollecitare',
            border: OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          hint: const Text('Seleziona rata'),
          items: [
            for (final installment in installments)
              DropdownMenuItem(
                value: installment,
                child: Text(
                  'Rata ${installment.rateIndex}/${installment.totalRates} · '
                  '${installment.dateLabel} · ${installment.amountLabel}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: installments.isEmpty
              ? null
              : (installment) {
                  setState(() {
                    _selectedInstallment = installment;
                    _messageEditedManually = false;
                    _applyTemplateMessage(entries: entries);
                  });
                },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const InstallmentMonitorPage(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Monitora rateizzo'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'WhatsApp e email',
      current: CreditCalcNavItem.develop,
      body: StreamBuilder<List<CreditorRecord>>(
        stream: CreditorsListDataAccess.instance.watchCreditors(),
        builder: (context, creditorsSnap) {
          final creditors = creditorsSnap.data ?? const [];
          _lastCreditors = creditors;

          return StreamBuilder<List<CommissionEntryRecord>>(
            stream: CommissionEntriesDataAccess.instance.watchCommissionEntries(),
            builder: (context, entriesSnap) {
              final entries = entriesSnap.data ?? const [];
              _lastEntries = entries;
              final practices = debtorContactPracticesFromEntries(entries);

              return ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: Dimensions.scrollPadding(context),
                children: [
                  const Text(
                    'Scegli il tipo di messaggio, compila i dati e apri WhatsApp o il '
                    'client email sul dispositivo. Nessun invio passa da server esterni.',
                    style: TextStyle(color: Colors.black54, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildChannelSelector(),
                          const SizedBox(height: 16),
                          _messageKindSelector(),
                          const SizedBox(height: 16),
                          if (_messageKind == DebtorMessageKind.coordinate)
                            KeyedSubtree(
                              key: const ValueKey('section-coordinate'),
                              child: _coordinateSection(creditors),
                            )
                          else if (_messageKind == DebtorMessageKind.sollecito)
                            KeyedSubtree(
                              key: const ValueKey('section-sollecito'),
                              child: _sollecitoSection(practices, entries),
                            )
                          else
                            const Text(
                              'Scrivi liberamente il messaggio nel campo sotto.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          const SizedBox(height: 16),
                          if (_channel == _ContactChannel.whatsapp)
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Numero WhatsApp',
                                hintText: 'Es. 393331234567',
                                border: OutlineInputBorder(),
                                helperText:
                                    'Solo cifre, con prefisso internazionale senza +',
                              ),
                            )
                          else ...[
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Indirizzo email',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _subjectCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Oggetto',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _messageCtrl,
                            minLines: 6,
                            maxLines: 14,
                            decoration: InputDecoration(
                              labelText: 'Messaggio',
                              border: const OutlineInputBorder(),
                              alignLabelWithHint: true,
                              helperText: _messageKind == DebtorMessageKind.libero
                                  ? null
                                  : 'Puoi modificare il testo generato prima di inviare',
                            ),
                            onChanged: (_) {
                              if (_messageKind != DebtorMessageKind.libero) {
                                _messageEditedManually = true;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _busy ? null : _validateAndSend,
                            icon: Icon(
                              _channel == _ContactChannel.whatsapp
                                  ? Icons.open_in_new
                                  : Icons.send_outlined,
                            ),
                            label: Text(
                              _busy
                                  ? 'Apertura…'
                                  : _channel == _ContactChannel.whatsapp
                                      ? 'Apri WhatsApp'
                                      : 'Apri client email',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
