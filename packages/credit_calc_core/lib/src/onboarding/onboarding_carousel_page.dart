import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'onboarding_host_config.dart';

class OnboardingCarouselPage extends StatelessWidget {
  const OnboardingCarouselPage({super.key, this.onFinished});

  /// Store/desktop: callback senza sostituire lo stack di navigazione.
  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _ProjectCarouselHost(),
      ),
    );
  }
}

class _ProjectCarouselHost extends StatefulWidget {
  const _ProjectCarouselHost();

  @override
  State<_ProjectCarouselHost> createState() => _ProjectCarouselHostState();
}

class _ProjectCarouselHostState extends State<_ProjectCarouselHost> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _saving = false;
  bool _loading = true;

  List<_SlideData> _slides = [];

  static const Map<String, List<String>> _roleSlides = {
    'public': ['form', 'calc', 'job'],
    'work': ['form', 'calc'],
    'company': ['job'],
  };

  final Map<String, _SlideData> _slideMap = const {
    'form': _SlideData(
      title: 'CreditForm',
      subtitle: 'Formazione digitale',
      description:
          'Percorsi strutturati con video, quiz, listening e role play '
          'per una crescita professionale misurabile.',
      color: Color(0xFFFFA726),
      icon: Icons.school_outlined,
    ),
    'calc': _SlideData(
      title: 'CreditCalc',
      subtitle: 'Calcoli e simulazioni',
      description:
          'Strumenti di calcolo per simulare piani di rientro '
          'e valutazioni operative.',
      color: Color(0xFF00B0FF),
      icon: Icons.calculate_outlined,
    ),
    'job': _SlideData(
      title: 'CreditJob',
      subtitle: 'Opportunità di lavoro',
      description:
          'Gestione candidature, offerte mirate e monitoraggio '
          'dello stato delle selezioni.',
      color: Color(0xFF00C4B3),
      icon: Icons.work_outline,
    ),
  };

  final _SlideData _finalSlide = const _SlideData(
    title: 'Pronto per iniziare',
    subtitle: 'Tutto in un’unica piattaforma',
    description:
        'Ora hai una panoramica completa dei servizi disponibili. '
        'Procedi per iniziare l’esperienza.',
    color: Color(0xFF43A047),
    icon: Icons.arrow_forward_rounded,
    isFinal: true,
  );

  @override
  void initState() {
    super.initState();
    _loadSlides();
  }

  Future<void> _loadSlides() async {
    final user = FirebaseAuth.instance.currentUser;
    var role = 'public';

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      role = (doc.data()?['type'] ?? 'public').toString().toLowerCase();
    }

    final allowed = _roleSlides[role] ?? _roleSlides['public']!;

    final generated = allowed
        .where((key) => _slideMap.containsKey(key))
        .map((key) => _slideMap[key]!)
        .toList();

    generated.add(_finalSlide);

    if (!mounted) return;
    setState(() {
      _slides = generated;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next(BuildContext context) async {
    final isLast = _slides[_index].isFinal;

    if (!isLast) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_saving) return;
    _saving = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'onboardingDone': true});
    }

    if (!context.mounted) return;

    final carousel = context.findAncestorWidgetOfExactType<OnboardingCarouselPage>();
    final onFinished = carousel?.onFinished;
    if (onFinished != null) {
      onFinished();
      return;
    }

    OnboardingHostConfig.navigateToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isLast = _slides[_index].isFinal;

    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width - 32).clamp(280.0, 900.0);
    final cardHeight = (size.height - 120).clamp(400.0, 520.0);
    final compact = size.width < 720;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => _Slide(
                      slide: _slides[i],
                      compact: compact,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: i == _index ? 18 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _index
                              ? _slides[i].color
                              : Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: 280,
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _next(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _slides[_index].color,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(isLast ? 'Avanti' : 'Continua'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final IconData icon;
  final bool isFinal;

  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.icon,
    this.isFinal = false,
  });
}

class _Slide extends StatelessWidget {
  final _SlideData slide;
  final bool compact;

  const _Slide({required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      height: compact ? 180 : 260,
      width: compact ? double.infinity : null,
      decoration: BoxDecoration(
        color: slide.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        slide.icon,
        size: compact ? 88 : 120,
        color: slide.color,
      ),
    );

    final textColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          slide.title,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          slide.subtitle,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Text(
          slide.description,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 48),
      child: Center(
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconBox,
                  const SizedBox(height: 24),
                  textColumn,
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 5, child: iconBox),
                  const SizedBox(width: 40),
                  Expanded(flex: 7, child: textColumn),
                ],
              ),
      ),
    );
  }
}
