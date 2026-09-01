import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_constants.dart';
import '../paste/paste.dart';
import '../report/report.dart';
import '../stats/stats.dart';

part 'res_quill_guide.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

enum _Screen { start, selection, input, validation, report }

enum _InputMode { paste, manual, example }

enum _ButtonTone { primary, secondary, tertiary }

const _spreadsheetBoundaryMessage =
    'CSV files and raw Excel sheets contain raw rows. Res-Quill checks '
    't-test output from SPSS, R, JASP, jamovi, Excel ToolPak, or APA-style '
    'reports. Paste that output instead.';

const _currentLimitsMessage =
    'Today: Student, Welch, paired, and one-sample t-tests only. Paste SPSS, '
    'R, JASP, jamovi, Excel ToolPak, or APA output. No raw CSV/Excel data '
    'computation. No cloud. No accounts.';

class _PasteExample {
  const _PasteExample({
    required this.id,
    required this.label,
    required this.controlLabel,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String controlLabel;
  final String assetPath;
}

const _pasteExamples = [
  _PasteExample(
    id: 'spss-independent',
    label: 'SPSS table: choose Student or Welch',
    controlLabel: 'SPSS Student/Welch',
    assetPath: 'assets/examples/paste_text/spss_independent_samples.txt',
  ),
  _PasteExample(
    id: 'spss-one-sample',
    label: 'SPSS one-sample table',
    controlLabel: 'SPSS one-sample',
    assetPath: 'assets/examples/paste_text/spss_one_sample.txt',
  ),
  _PasteExample(
    id: 'spss-p-rounded-zero',
    label: 'SPSS .000 becomes p < .001',
    controlLabel: 'SPSS p < .001',
    assetPath: 'assets/examples/paste_text/spss_one_sample_p_is_000.txt',
  ),
  _PasteExample(
    id: 'apa-sentence-ci',
    label: 'APA sentence with CI',
    controlLabel: 'APA sentence with CI',
    assetPath: 'assets/examples/paste_text/apa_sentence_welch.txt',
  ),
  _PasteExample(
    id: 'intentional-mistake',
    label: 'Example with a mistake in it',
    controlLabel: 'Mistake: should fail',
    assetPath: 'assets/examples/paste_text/intentional_mistake_welch.txt',
  ),
];

class _MainAppState extends State<MainApp> with TickerProviderStateMixin {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _guideRegistry = _GuideTargetRegistry();

  bool _lightTheme = false;
  bool _preferencesLoaded = false;
  _Screen _screen = _Screen.start;
  _InputMode _inputMode = _InputMode.paste;
  TTestKind _manualKind = TTestKind.independentWelch;
  _PasteExample _selectedExample = _pasteExamples.first;
  SharedPreferences? _preferences;
  Set<String> _seenGuideScreens = <String>{};
  _GuideSession? _guideSession;
  _Screen? _pulsingGuideScreen;
  late final AnimationController _guidePulseController;
  Timer? _guidePulseTimer;

  final _pasteController = TextEditingController();
  final _outcomeController = TextEditingController(text: 'scores');
  final _alphaController = TextEditingController(text: '.05');
  final _confidenceController = TextEditingController(text: '.95');
  final _primaryLabelController = TextEditingController();
  final _secondaryLabelController = TextEditingController();
  final _primaryNController = TextEditingController();
  final _secondaryNController = TextEditingController();
  final _primaryMeanController = TextEditingController();
  final _secondaryMeanController = TextEditingController();
  final _primarySdController = TextEditingController();
  final _secondarySdController = TextEditingController();
  final _referenceMeanController = TextEditingController();
  final _pairedMeanDifferenceController = TextEditingController();
  final _pairedDifferenceSdController = TextEditingController();
  final _pairedCorrelationController = TextEditingController();
  final _reportedTController = TextEditingController();
  final _reportedDfController = TextEditingController();
  final _reportedPController = TextEditingController();
  final _reportedMeanDifferenceController = TextEditingController();
  final _reportedSeController = TextEditingController();
  final _ciLowerController = TextEditingController();
  final _ciUpperController = TextEditingController();

  ReportedPValueTail _manualTail = ReportedPValueTail.twoTailed;
  TTestPasteParseResult? _pasteResult;
  PasteTTestCandidate? _selectedCandidate;
  ReportedPValueTail? _confirmedPasteTail;
  String? _inputError;

  TTestValidationInput? _validationInput;
  List<ValidationCheck> _validationChecks = const [];
  TTestResult? _computedResult;
  TTestReportContext _reportContext = const TTestReportContext();
  TTestReportOptions _reportOptions = TTestReportOptions();
  EvidenceSourceRegistry _evidenceSources = EvidenceSourceRegistry();
  TTestReportOutput? _report;
  String _copyStatus = '';

  @override
  void initState() {
    super.initState();
    _guidePulseController = AnimationController(
      vsync: this,
      duration: _guidePulseDuration,
    );
    HardwareKeyboard.instance.addHandler(_handleGuideKeyEvent);
    unawaited(_loadPreferences());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGuideKeyEvent);
    _guidePulseTimer?.cancel();
    _guidePulseController.dispose();
    _pasteController.dispose();
    _outcomeController.dispose();
    _alphaController.dispose();
    _confidenceController.dispose();
    _primaryLabelController.dispose();
    _secondaryLabelController.dispose();
    _primaryNController.dispose();
    _secondaryNController.dispose();
    _primaryMeanController.dispose();
    _secondaryMeanController.dispose();
    _primarySdController.dispose();
    _secondarySdController.dispose();
    _referenceMeanController.dispose();
    _pairedMeanDifferenceController.dispose();
    _pairedDifferenceSdController.dispose();
    _pairedCorrelationController.dispose();
    _reportedTController.dispose();
    _reportedDfController.dispose();
    _reportedPController.dispose();
    _reportedMeanDifferenceController.dispose();
    _reportedSeController.dispose();
    _ciLowerController.dispose();
    _ciUpperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = _lightTheme ? ThemeMode.light : ThemeMode.dark;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppText.displayName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _themeData(Brightness.light),
      darkTheme: _themeData(Brightness.dark),
      home: Builder(
        builder: (context) {
          final colors = _RqColors.of(context);
          return Scaffold(
            backgroundColor: colors.background,
            body: _GuideScope(
              registry: _guideRegistry,
              openCardGuide: _openCardGuide,
              pulsingScreen: _pulsingGuideScreen,
              pulseAnimation: _guidePulseController,
              child: Stack(
                children: [
                  const _BackgroundLayer(),
                  Positioned.fill(child: _currentScreen()),
                  Positioned(
                    top: 18,
                    left: 18,
                    right: 18,
                    child: _TopControls(
                      isLight: _lightTheme,
                      onReplayGuide: () => _startGuide(_screen),
                      onToggleTheme: _toggleTheme,
                      onSettings: _showSettings,
                    ),
                  ),
                  _GuideOverlay(
                    registry: _guideRegistry,
                    session: _guideSession,
                    onBack: _previousGuideTip,
                    onNext: _nextGuideTip,
                    onClose: _closeGuide,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final savedTheme = preferences.getString(_themePreferenceKey);
    final seenScreens =
        preferences.getStringList(_guideSeenScreensPreferenceKey) ?? const [];
    setState(() {
      _preferences = preferences;
      _lightTheme = savedTheme == _themePreferenceLight;
      _seenGuideScreens = seenScreens.toSet();
      _preferencesLoaded = true;
    });
    _afterScreenChanged();
  }

  Future<SharedPreferences> _readyPreferences() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      _preferences = preferences;
    }
    return preferences;
  }

  void _toggleTheme() {
    final nextIsLight = !_lightTheme;
    setState(() => _lightTheme = nextIsLight);
    unawaited(_writeThemePreference(nextIsLight));
  }

  Future<void> _writeThemePreference(bool isLight) async {
    final preferences = await _readyPreferences();
    await preferences.setString(
      _themePreferenceKey,
      isLight ? _themePreferenceLight : _themePreferenceDark,
    );
  }

  void _showSettings() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }
    showDialog<void>(
      context: navigatorContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _SettingsDialog(
              isLight: _lightTheme,
              onReplayGuide: () {
                Navigator.of(dialogContext).pop();
                _startGuide(_screen);
              },
              onResetSeen: () {
                Navigator.of(dialogContext).pop();
                _resetGuideSeenState();
              },
              onToggleTheme: () {
                _toggleTheme();
                setDialogState(() {});
              },
            );
          },
        );
      },
    );
  }

  void _resetGuideSeenState() {
    _guidePulseTimer?.cancel();
    _guidePulseController.stop();
    setState(() {
      _seenGuideScreens = <String>{};
      _pulsingGuideScreen = null;
    });
    unawaited(_removeSeenGuidePreference());
    _afterScreenChanged();
  }

  Future<void> _removeSeenGuidePreference() async {
    final preferences = await _readyPreferences();
    await preferences.remove(_guideSeenScreensPreferenceKey);
  }

  void _afterScreenChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleScreenEntered();
      }
    });
  }

  void _handleScreenEntered() {
    if (!_preferencesLoaded || _guideSession != null) {
      return;
    }
    if (_screen == _Screen.start) {
      if (!_seenGuideScreens.contains(_screen.guideStorageId)) {
        _startGuide(_Screen.start);
      }
      return;
    }
    _pulseGuideButtons(_screen);
  }

  void _markGuideScreenSeen(_Screen screen) {
    final storageId = screen.guideStorageId;
    if (_seenGuideScreens.contains(storageId)) {
      return;
    }
    _seenGuideScreens = {..._seenGuideScreens, storageId};
    unawaited(_writeSeenGuideScreens());
  }

  Future<void> _writeSeenGuideScreens() async {
    final preferences = await _readyPreferences();
    await preferences.setStringList(
      _guideSeenScreensPreferenceKey,
      _seenGuideScreens.toList()..sort(),
    );
  }

  void _pulseGuideButtons(_Screen screen, {bool force = false}) {
    if (screen == _Screen.start || _guideStepsFor(screen).isEmpty) {
      return;
    }
    if (!force && _seenGuideScreens.contains(screen.guideStorageId)) {
      return;
    }
    _markGuideScreenSeen(screen);
    _guidePulseTimer?.cancel();
    _guidePulseController.stop();
    _guidePulseController.value = 0;
    setState(() => _pulsingGuideScreen = screen);
    if (!MediaQuery.disableAnimationsOf(context)) {
      _guidePulseController.repeat(period: _guidePulseDuration);
    }
    _guidePulseTimer = Timer(
      _guidePulseTotal + const Duration(milliseconds: 40),
      _stopGuidePulse,
    );
  }

  void _stopGuidePulse() {
    if (_pulsingGuideScreen == null) {
      return;
    }
    _guidePulseTimer?.cancel();
    _guidePulseController.stop();
    if (mounted) {
      setState(() => _pulsingGuideScreen = null);
    } else {
      _pulsingGuideScreen = null;
    }
  }

  void _startGuide(_Screen screen) {
    final steps = _guideStepsFor(screen);
    if (steps.isEmpty) {
      return;
    }
    _stopGuidePulse();
    _markGuideScreenSeen(screen);
    setState(() {
      _guideSession = _GuideSession(screen: screen, index: 0);
    });
  }

  void _openCardGuide(_Screen screen, String targetId) {
    final steps = _guideStepsFor(screen);
    final index = steps.indexWhere((step) => step.targetId == targetId);
    if (index < 0) {
      return;
    }
    _stopGuidePulse();
    _markGuideScreenSeen(screen);
    setState(() {
      _guideSession = _GuideSession(
        screen: screen,
        index: index,
        singleTargetId: targetId,
      );
    });
  }

  void _closeGuide() {
    if (_guideSession == null) {
      return;
    }
    setState(() => _guideSession = null);
    _afterScreenChanged();
  }

  void _nextGuideTip() {
    final session = _guideSession;
    if (session == null || session.singleTargetId != null) {
      return;
    }
    final steps = _guideStepsFor(session.screen);
    if (session.index >= steps.length - 1) {
      _closeGuide();
      return;
    }
    setState(() {
      _guideSession = session.copyWith(index: session.index + 1);
    });
  }

  void _previousGuideTip() {
    final session = _guideSession;
    if (session == null ||
        session.singleTargetId != null ||
        session.index <= 0) {
      return;
    }
    setState(() {
      _guideSession = session.copyWith(index: session.index - 1);
    });
  }

  bool _handleGuideKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _guideSession == null) {
      return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _closeGuide();
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.arrowRight) {
      _nextGuideTip();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _previousGuideTip();
      return true;
    }
    return false;
  }

  ThemeData _themeData(Brightness brightness) {
    final colors = brightness == Brightness.dark
        ? _RqColors.dark()
        : _RqColors.light();
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.cyan,
      brightness: brightness,
      surface: colors.surfaceSolid,
      error: colors.error,
    );
    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      extensions: [colors],
    );
    return base.copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.cyan,
        selectionColor: colors.cyan.withValues(alpha: 0.28),
        selectionHandleColor: colors.cyan,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.fieldBackground,
        labelStyle: TextStyle(
          color: colors.cardText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(color: colors.mutedSoft),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.lineStrong),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.cyan, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.error),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.error, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _currentScreen() {
    return switch (_screen) {
      _Screen.start => _StartScreen(
        onPaste: _openPasteInput,
        onManual: _openSelection,
        onExample: _openExample,
        onCompare: _openSelection,
      ),
      _Screen.selection => _SelectionScreen(
        onBack: _openStart,
        onSelected: _openManualInput,
      ),
      _Screen.input => _InputScreen(
        mode: _inputMode,
        manualKind: _manualKind,
        pasteController: _pasteController,
        outcomeController: _outcomeController,
        alphaController: _alphaController,
        confidenceController: _confidenceController,
        primaryLabelController: _primaryLabelController,
        secondaryLabelController: _secondaryLabelController,
        primaryNController: _primaryNController,
        secondaryNController: _secondaryNController,
        primaryMeanController: _primaryMeanController,
        secondaryMeanController: _secondaryMeanController,
        primarySdController: _primarySdController,
        secondarySdController: _secondarySdController,
        referenceMeanController: _referenceMeanController,
        pairedMeanDifferenceController: _pairedMeanDifferenceController,
        pairedDifferenceSdController: _pairedDifferenceSdController,
        pairedCorrelationController: _pairedCorrelationController,
        reportedTController: _reportedTController,
        reportedDfController: _reportedDfController,
        reportedPController: _reportedPController,
        reportedMeanDifferenceController: _reportedMeanDifferenceController,
        reportedSeController: _reportedSeController,
        ciLowerController: _ciLowerController,
        ciUpperController: _ciUpperController,
        manualTail: _manualTail,
        pasteResult: _pasteResult,
        selectedCandidate: _selectedCandidate,
        confirmedPasteTail: _confirmedPasteTail,
        inputError: _inputError,
        selectedExample: _selectedExample,
        onBack: _openStart,
        onExampleChanged: (example) {
          setState(() => _selectedExample = example);
        },
        onLoadExample: _loadExample,
        onShowSpreadsheetBoundary: _showSpreadsheetBoundary,
        onManualKindChanged: (kind) {
          setState(() => _manualKind = kind);
        },
        onManualTailChanged: (tail) {
          setState(() => _manualTail = tail);
        },
        onReviewPaste: _reviewPaste,
        onCandidateChanged: (candidate) {
          setState(() {
            _selectedCandidate = candidate;
            _fillControllersFromCandidate(candidate);
          });
        },
        onPasteTailChanged: (tail) {
          setState(() => _confirmedPasteTail = tail);
        },
        onConfirmPaste: _confirmPaste,
        onValidateManual: _validateManual,
        pasteCanConfirm: _pasteCanConfirm,
      ),
      _Screen.validation => _ValidationScreen(
        checks: _validationChecks,
        input: _validationInput,
        result: _computedResult,
        onBack: _openExistingInput,
        onGenerate: _generateReport,
      ),
      _Screen.report => _ReportScreen(
        report: _report,
        result: _computedResult,
        options: _reportOptions,
        copyStatus: _copyStatus,
        onBack: _openValidationScreen,
        onEdit: _openExistingInput,
        onCopy: _copyReport,
      ),
    };
  }

  void _openStart() {
    setState(() => _screen = _Screen.start);
    _afterScreenChanged();
  }

  void _openSelection() {
    setState(() => _screen = _Screen.selection);
    _afterScreenChanged();
  }

  void _openExistingInput() {
    setState(() => _screen = _Screen.input);
    _afterScreenChanged();
  }

  void _openValidationScreen() {
    setState(() => _screen = _Screen.validation);
    _afterScreenChanged();
  }

  void _openPasteInput() {
    setState(() {
      _inputMode = _InputMode.paste;
      _screen = _Screen.input;
      _pasteResult = null;
      _selectedCandidate = null;
      _confirmedPasteTail = null;
      _inputError = null;
      _pasteController.clear();
    });
    _afterScreenChanged();
  }

  void _openExample() {
    _loadExample(_selectedExample);
  }

  Future<void> _loadExample(_PasteExample example) async {
    final String text;
    try {
      text = await rootBundle.loadString(example.assetPath);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _inputError = 'Example could not load.';
        _screen = _Screen.input;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    _pasteController.text = text;
    setState(() {
      _selectedExample = example;
      _inputMode = _InputMode.example;
      _screen = _Screen.input;
      _pasteResult = null;
      _selectedCandidate = null;
      _confirmedPasteTail = null;
      _inputError = null;
    });
    _reviewPaste();
    _afterScreenChanged();
  }

  void _showSpreadsheetBoundary() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }
    showDialog<void>(
      context: navigatorContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('CSV and Excel files'),
          content: const Text(_spreadsheetBoundaryMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openManualInput(TTestKind kind) {
    setState(() {
      _inputMode = _InputMode.manual;
      _manualKind = kind;
      _screen = _Screen.input;
      _pasteResult = null;
      _selectedCandidate = null;
      _confirmedPasteTail = null;
      _inputError = null;
      if (_allStructuredFieldsAreEmpty) {
        _fillManualDefaultsFor(kind);
      }
    });
    _afterScreenChanged();
  }

  bool get _allStructuredFieldsAreEmpty {
    return [
      _primaryNController,
      _primaryMeanController,
      _primarySdController,
      _secondaryNController,
      _secondaryMeanController,
      _secondarySdController,
      _reportedTController,
      _reportedDfController,
      _reportedPController,
    ].every((controller) => controller.text.trim().isEmpty);
  }

  void _fillManualDefaultsFor(TTestKind kind) {
    _outcomeController.text = 'scores';
    _alphaController.text = '.05';
    _confidenceController.text = '.95';
    _manualTail = ReportedPValueTail.twoTailed;
    switch (kind) {
      case TTestKind.independentStudent:
      case TTestKind.independentWelch:
        _primaryLabelController.text = '';
        _secondaryLabelController.text = '';
        break;
      case TTestKind.pairedSamples:
        _primaryLabelController.text = '';
        _secondaryLabelController.text = '';
        break;
      case TTestKind.oneSample:
        _primaryLabelController.text = '';
        _secondaryLabelController.clear();
        break;
    }
  }

  void _reviewPaste() {
    final result = TTestPasteParser.parse(_pasteController.text);
    final defaultCandidate = _defaultCandidateFor(result);
    setState(() {
      _pasteResult = result;
      _selectedCandidate = defaultCandidate;
      _confirmedPasteTail = defaultCandidate?.reportedPValueTail;
      _inputError = null;
      if (defaultCandidate != null) {
        _manualKind = defaultCandidate.kind;
        _manualTail =
            defaultCandidate.reportedPValueTail ?? ReportedPValueTail.twoTailed;
        _fillControllersFromCandidate(defaultCandidate);
      }
    });
  }

  PasteTTestCandidate? _defaultCandidateFor(TTestPasteParseResult result) {
    final selected = result.candidates
        .where((candidate) => candidate.selectedByText)
        .toList();
    if (selected.length == 1) {
      return selected.single;
    }
    if (result.candidates.length == 1) {
      return result.candidates.single;
    }
    return null;
  }

  bool get _pasteCanConfirm {
    final candidate = _selectedCandidate;
    final result = _pasteResult;
    if (candidate == null ||
        result == null ||
        result.status == PasteParseStatus.cannotParse ||
        _confirmedPasteTail == null) {
      return false;
    }
    return candidate.canBuildValidationInput(
      confirmedPValueTail: _confirmedPasteTail,
    );
  }

  void _confirmPaste() {
    final candidate = _selectedCandidate;
    final tail = _confirmedPasteTail;
    if (candidate == null || tail == null) {
      setState(() {
        _inputError = 'Choose the row and p-value direction first.';
      });
      return;
    }
    try {
      final input = candidate.toValidationInput(confirmedPValueTail: tail);
      _manualKind = input.kind;
      _manualTail = tail;
      _prepareValidation(
        input: input,
        context: _contextFromControllers(candidate.reportContext()),
        options: _optionsFromControllers(tail),
        evidenceSources: candidate.evidenceSources(),
      );
    } on Object catch (error) {
      setState(() => _inputError = _messageFor(error));
    }
  }

  void _validateManual() {
    try {
      final input = _manualValidationInput();
      _prepareValidation(
        input: input,
        context: _contextFromControllers(),
        options: _optionsFromControllers(_manualTail),
        evidenceSources: EvidenceSourceRegistry.fromValidationInput(input),
      );
    } on Object catch (error) {
      setState(() => _inputError = _messageFor(error));
    }
  }

  void _prepareValidation({
    required TTestValidationInput input,
    required TTestReportContext context,
    required TTestReportOptions options,
    required EvidenceSourceRegistry evidenceSources,
  }) {
    final checks = [...TTestValidator.validate(input), _alphaCheck(options)];
    TTestResult? result;
    try {
      result = TTestValidator.resultFromInput(input);
    } on Object catch (error) {
      checks.add(
        ValidationCheck(
          id: 'calculation.input',
          title: 'Values can be recalculated',
          status: ValidationStatus.fail,
          explanation: _messageFor(error),
        ),
      );
    }
    setState(() {
      _validationInput = input;
      _validationChecks = checks;
      _computedResult = result;
      _reportContext = context;
      _reportOptions = options;
      _evidenceSources = evidenceSources;
      _report = null;
      _copyStatus = '';
      _inputError = null;
      _screen = _Screen.validation;
    });
    _afterScreenChanged();
  }

  ValidationCheck _alphaCheck(TTestReportOptions options) {
    return ValidationCheck(
      id: 'alpha.domain',
      title: 'Alpha is between 0 and 1',
      status: ValidationStatus.pass,
      reported: options.alpha,
      tolerance: '(0, 1)',
      explanation: 'Alpha is a usable decision threshold.',
    );
  }

  void _generateReport() {
    final result = _computedResult;
    if (result == null || _hasFailures) {
      return;
    }
    setState(() {
      _report = TTestReportGenerator.generate(
        result: result,
        validationChecks: _validationChecks,
        context: _reportContext,
        options: _reportOptions,
        evidenceSources: _evidenceSources,
      );
      _screen = _Screen.report;
    });
    _afterScreenChanged();
  }

  bool get _hasFailures {
    return _validationChecks.any(
      (check) => check.status == ValidationStatus.fail,
    );
  }

  Future<void> _copyReport() async {
    final report = _report;
    if (report == null || report.isBlocked) {
      return;
    }
    final text = [
      report.formalResult?.plainText,
      report.descriptivesSentence,
      report.plainLanguageMeaning,
      report.effectSizeSentence,
    ].whereType<String>().join('\n\n');
    try {
      await Clipboard.setData(ClipboardData(text: text));
      setState(() => _copyStatus = 'Copied report text.');
    } on Object {
      setState(() => _copyStatus = 'Report text is ready to copy.');
    }
  }

  TTestValidationInput _manualValidationInput() {
    final confidenceLevel = _parseRequiredDouble(
      _confidenceController.text,
      'confidence level',
    );
    final first = ReportedDescriptives(
      label: _emptyToNull(_primaryLabelController.text),
      n: _parseRequiredInt(_primaryNController.text, 'Group 1 n'),
      mean: _parseRequiredDouble(_primaryMeanController.text, 'Group 1 mean'),
      standardDeviation: _parseRequiredDouble(
        _primarySdController.text,
        'Group 1 SD',
      ),
    );
    final reportedT = _parseOptionalReportedValue(_reportedTController.text);
    final reportedDf = _parseOptionalReportedValue(_reportedDfController.text);
    final reportedP = _parseOptionalReportedValue(
      _reportedPController.text,
      pValue: true,
    );
    final reportedMeanDifference = _parseOptionalReportedValue(
      _reportedMeanDifferenceController.text,
    );
    final reportedSe = _parseOptionalReportedValue(_reportedSeController.text);
    final ciLower = _parseOptionalReportedValue(_ciLowerController.text);
    final ciUpper = _parseOptionalReportedValue(_ciUpperController.text);

    switch (_manualKind) {
      case TTestKind.independentStudent:
      case TTestKind.independentWelch:
        return TTestValidationInput(
          kind: _manualKind,
          first: first,
          second: ReportedDescriptives(
            label: _emptyToNull(_secondaryLabelController.text),
            n: _parseRequiredInt(_secondaryNController.text, 'Group 2 n'),
            mean: _parseRequiredDouble(
              _secondaryMeanController.text,
              'Group 2 mean',
            ),
            standardDeviation: _parseRequiredDouble(
              _secondarySdController.text,
              'Group 2 SD',
            ),
          ),
          reportedT: reportedT,
          reportedDegreesOfFreedom: reportedDf,
          reportedP: reportedP,
          reportedPValueTail: _manualTail,
          reportedMeanDifference: reportedMeanDifference,
          reportedStandardError: reportedSe,
          reportedCiLower: ciLower,
          reportedCiUpper: ciUpper,
          confidenceLevel: confidenceLevel,
        );
      case TTestKind.pairedSamples:
        return TTestValidationInput(
          kind: _manualKind,
          paired: ReportedPairedDescriptives(
            first: first,
            second: ReportedDescriptives(
              label: _emptyToNull(_secondaryLabelController.text),
              n: _parseRequiredInt(_secondaryNController.text, 'Second n'),
              mean: _parseRequiredDouble(
                _secondaryMeanController.text,
                'Second mean',
              ),
              standardDeviation: _parseRequiredDouble(
                _secondarySdController.text,
                'Second SD',
              ),
            ),
            meanDifference: _parseRequiredDouble(
              _pairedMeanDifferenceController.text,
              'paired mean difference',
            ),
            differenceStandardDeviation: _parseRequiredDouble(
              _pairedDifferenceSdController.text,
              'paired difference SD',
            ),
            correlation: _parseOptionalDouble(
              _pairedCorrelationController.text,
            ),
          ),
          reportedT: reportedT,
          reportedDegreesOfFreedom: reportedDf,
          reportedP: reportedP,
          reportedPValueTail: _manualTail,
          reportedMeanDifference: reportedMeanDifference,
          reportedStandardError: reportedSe,
          reportedCiLower: ciLower,
          reportedCiUpper: ciUpper,
          confidenceLevel: confidenceLevel,
        );
      case TTestKind.oneSample:
        return TTestValidationInput(
          kind: _manualKind,
          first: first,
          referenceMean: _parseRequiredDouble(
            _referenceMeanController.text,
            'reference mean',
          ),
          reportedT: reportedT,
          reportedDegreesOfFreedom: reportedDf,
          reportedP: reportedP,
          reportedPValueTail: _manualTail,
          reportedMeanDifference: reportedMeanDifference,
          reportedStandardError: reportedSe,
          reportedCiLower: ciLower,
          reportedCiUpper: ciUpper,
          confidenceLevel: confidenceLevel,
        );
    }
  }

  TTestReportContext _contextFromControllers([TTestReportContext? fallback]) {
    final defaultContext = fallback ?? const TTestReportContext();
    return TTestReportContext(
      outcomeLabel:
          _emptyToNull(_outcomeController.text) ?? defaultContext.outcomeLabel,
      primaryLabel:
          _emptyToNull(_primaryLabelController.text) ??
          defaultContext.primaryLabel,
      secondaryLabel:
          _emptyToNull(_secondaryLabelController.text) ??
          defaultContext.secondaryLabel,
      referenceLabel: _emptyToNull(_referenceMeanController.text) == null
          ? defaultContext.referenceLabel
          : 'the reference value',
    );
  }

  TTestReportOptions _optionsFromControllers(ReportedPValueTail tail) {
    final alpha = _parseRequiredDouble(_alphaController.text, 'alpha');
    return TTestReportOptions(tail: _reportTailFor(tail), alpha: alpha);
  }

  ReportTail _reportTailFor(ReportedPValueTail tail) {
    return switch (tail) {
      ReportedPValueTail.twoTailed => ReportTail.twoTailed,
      ReportedPValueTail.less => ReportTail.less,
      ReportedPValueTail.greater => ReportTail.greater,
      ReportedPValueTail.oneTailedObservedDirection =>
        throw const FormatException('Choose lower-tail or upper-tail p.'),
    };
  }

  void _fillControllersFromCandidate(PasteTTestCandidate candidate) {
    void textField(PasteFieldKey key, TextEditingController controller) {
      final value = candidate.text(key);
      if (value != null && value.trim().isNotEmpty) {
        controller.text = value;
      }
    }

    void numberField(PasteFieldKey key, TextEditingController controller) {
      final value = candidate.number(key);
      if (value != null) {
        controller.text = _formatPasteNumber(value);
      }
    }

    textField(PasteFieldKey.primaryLabel, _primaryLabelController);
    textField(PasteFieldKey.secondaryLabel, _secondaryLabelController);
    numberField(PasteFieldKey.primaryN, _primaryNController);
    numberField(PasteFieldKey.secondaryN, _secondaryNController);
    numberField(PasteFieldKey.primaryMean, _primaryMeanController);
    numberField(PasteFieldKey.secondaryMean, _secondaryMeanController);
    numberField(PasteFieldKey.primaryStandardDeviation, _primarySdController);
    numberField(
      PasteFieldKey.secondaryStandardDeviation,
      _secondarySdController,
    );
    numberField(PasteFieldKey.referenceMean, _referenceMeanController);
    numberField(
      PasteFieldKey.pairedMeanDifference,
      _pairedMeanDifferenceController,
    );
    numberField(
      PasteFieldKey.pairedDifferenceStandardDeviation,
      _pairedDifferenceSdController,
    );
    numberField(PasteFieldKey.pairedCorrelation, _pairedCorrelationController);
    numberField(PasteFieldKey.reportedT, _reportedTController);
    numberField(PasteFieldKey.reportedDegreesOfFreedom, _reportedDfController);
    numberField(PasteFieldKey.reportedP, _reportedPController);
    numberField(
      PasteFieldKey.reportedMeanDifference,
      _reportedMeanDifferenceController,
    );
    numberField(PasteFieldKey.reportedStandardError, _reportedSeController);
    numberField(PasteFieldKey.ciLower, _ciLowerController);
    numberField(PasteFieldKey.ciUpper, _ciUpperController);
    numberField(PasteFieldKey.confidenceLevel, _confidenceController);
  }

  String _formatPasteNumber(PasteNumber number) {
    final decimals = number.decimalPlaces.clamp(0, 6);
    final text = number.value.toStringAsFixed(decimals);
    return switch (number.relation) {
      ReportedRelation.equalRounded => text,
      ReportedRelation.lessThan => '< $text',
      ReportedRelation.lessThanOrEqual => '<= $text',
      ReportedRelation.greaterThan => '> $text',
      ReportedRelation.greaterThanOrEqual => '>= $text',
    };
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _parseRequiredInt(String text, String label) {
    final value = _parseRequiredDouble(text, label);
    if ((value - value.round()).abs() > 1e-9) {
      throw FormatException('$label must be an integer.');
    }
    return value.round();
  }

  double _parseRequiredDouble(String text, String label) {
    final value = _parseOptionalDouble(text);
    if (value == null) {
      throw FormatException('$label is required.');
    }
    return value;
  }

  double? _parseOptionalDouble(String text) {
    final normalized = _normalizeNumberText(text);
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  ReportedValue? _parseOptionalReportedValue(
    String text, {
    bool pValue = false,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    var relation = ReportedRelation.equalRounded;
    var numberText = trimmed;
    for (final item in const [
      _RelationPrefix('<=', ReportedRelation.lessThanOrEqual),
      _RelationPrefix('>=', ReportedRelation.greaterThanOrEqual),
      _RelationPrefix('<', ReportedRelation.lessThan),
      _RelationPrefix('>', ReportedRelation.greaterThan),
      _RelationPrefix('=', ReportedRelation.equalRounded),
    ]) {
      if (numberText.startsWith(item.prefix)) {
        relation = item.relation;
        numberText = numberText.substring(item.prefix.length).trim();
        break;
      }
    }
    final decimals = _decimalPlaces(numberText);
    final value = _parseOptionalDouble(numberText);
    if (value == null) {
      throw FormatException('Cannot read "$text" as a number.');
    }
    var storedValue = value;
    var storedRelation = relation;
    if (pValue &&
        storedRelation == ReportedRelation.equalRounded &&
        storedValue == 0 &&
        decimals >= 3) {
      storedValue = math.pow(10, -decimals).toDouble();
      storedRelation = ReportedRelation.lessThan;
    }
    return ReportedValue(
      value: storedValue,
      decimalPlaces: decimals,
      relation: storedRelation,
    );
  }

  String _normalizeNumberText(String text) {
    return text
        .trim()
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'^[<>=\s]+'), '')
        .replaceAll(RegExp(r'\s+'), '');
  }

  int _decimalPlaces(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    final dot = cleaned.lastIndexOf('.');
    if (dot == -1) {
      return 0;
    }
    return math.max(0, cleaned.length - dot - 1);
  }

  String _messageFor(Object error) {
    if (error is StatsException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    if (error is PasteParseException) {
      return error.message;
    }
    return error.toString();
  }
}

class _StartScreen extends StatelessWidget {
  const _StartScreen({
    required this.onPaste,
    required this.onManual,
    required this.onExample,
    required this.onCompare,
  });

  final VoidCallback onPaste;
  final VoidCallback onManual;
  final VoidCallback onExample;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final brand = _BrandCard(
            onPaste: onPaste,
            onManual: onManual,
            onExample: onExample,
          );
          final areas = _AnalysisAreaPanel(onCompare: onCompare);
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [brand, const SizedBox(height: 18), areas],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: brand),
              const SizedBox(width: 18),
              Expanded(flex: 12, child: areas),
            ],
          );
        },
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.onPaste,
    required this.onManual,
    required this.onExample,
  });

  final VoidCallback onPaste;
  final VoidCallback onManual;
  final VoidCallback onExample;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return _GlassPanel(
      accent: colors.cyan,
      minHeight: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            key: Key('onboarding-guide-anchor'),
            width: 0,
            height: 0,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _BrandMark(),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppText.displayName,
                      style: TextStyle(
                        color: colors.title,
                        fontSize: 39,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'T-test reporting helper',
                      style: TextStyle(color: colors.muted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 52),
          Text(
            'Paste t-test output. Get APA wording.',
            key: const Key('start-headline'),
            style: TextStyle(
              color: colors.cardTitle,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'Start with your SPSS table or APA sentence.',
              style: TextStyle(
                color: colors.cardText,
                fontSize: 16.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              _currentLimitsMessage,
              key: const Key('start-current-limits'),
              style: TextStyle(
                color: colors.muted,
                fontSize: 14.5,
                height: 1.42,
              ),
            ),
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              final actions = [
                _GuideTarget(
                  id: 'paste_output',
                  child: _ActionButton(
                    label: 'Paste output',
                    tone: _ButtonTone.primary,
                    onPressed: onPaste,
                  ),
                ),
                _GuideTarget(
                  id: 'manual_entry',
                  child: _ActionButton(
                    label: 'Type values',
                    tone: _ButtonTone.secondary,
                    onPressed: onManual,
                  ),
                ),
                _GuideTarget(
                  id: 'try_example',
                  child: _ActionButton(
                    label: 'Try an example',
                    tone: _ButtonTone.tertiary,
                    onPressed: onExample,
                  ),
                ),
              ];
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i += 1) ...[
                      actions[i],
                      if (i != actions.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Wrap(spacing: 12, runSpacing: 12, children: actions);
            },
          ),
        ],
      ),
    );
  }
}

class _AnalysisAreaPanel extends StatelessWidget {
  const _AnalysisAreaPanel({required this.onCompare});

  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideTarget(
                id: 'analysis_area_heading',
                child: Text(
                  'Choose what you are reporting.',
                  key: const Key('analysis-area-title'),
                  style: TextStyle(
                    color: colors.title,
                    fontSize: 20.5,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Only t-tests work now.',
                style: TextStyle(color: colors.muted, fontSize: 14.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ResponsiveGrid(
          minTileHeight: 320,
          children: [
            _ChoiceCard(
              key: const Key('area-compare'),
              accent: colors.cardA,
              status: 'Available',
              statusTone: _StatusTone.accepted,
              title: 't tests',
              description: 'Independent, paired, and one-sample tests',
              bars: const [0.72, 0.46, 0.62],
              guideTargetId: 'compare_area_card',
              onTap: onCompare,
            ),
            _ChoiceCard(
              key: const Key('area-relationships'),
              accent: colors.cardB,
              status: 'Later',
              statusTone: _StatusTone.accepted,
              title: 'Relationships & prediction',
              description: 'Correlations and regression',
              bars: const [0.84, 0.58, 0.70],
              guideTargetId: 'relationships_coming_later',
              disabled: true,
            ),
            _ChoiceCard(
              key: const Key('area-categorical'),
              accent: colors.cardC,
              status: 'Later',
              statusTone: _StatusTone.warning,
              title: 'Categorical data',
              description: "Chi-square and Fisher's exact",
              bars: const [0.54, 0.76, 0.44],
              guideTargetId: 'categorical_coming_later',
              disabled: true,
            ),
            _ChoiceCard(
              key: const Key('area-diagnostics'),
              accent: colors.cardD,
              status: 'Later',
              statusTone: _StatusTone.error,
              title: 'Assumptions & diagnostics',
              description: 'Normality and variance checks',
              bars: const [0.60, 0.38, 0.66],
              guideTargetId: 'diagnostics_coming_later',
              disabled: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectionScreen extends StatelessWidget {
  const _SelectionScreen({required this.onBack, required this.onSelected});

  final VoidCallback onBack;
  final ValueChanged<TTestKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return _ScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(
            kicker: 'Manual entry',
            title: 'Choose your t-test.',
            body: 'Use this only when typing values by hand.',
            backLabel: 'Back to start',
            onBack: onBack,
          ),
          const SizedBox(height: 24),
          _ResponsiveGrid(
            minTileHeight: 320,
            children: [
              _ChoiceCard(
                accent: colors.cardA,
                status: 'Type values',
                statusTone: _StatusTone.accepted,
                title: 'Equal variances assumed',
                description: 'The SPSS Student row',
                bars: const [0.72, 0.46, 0.62],
                guideTargetId: 'student_test_path',
                guideScreen: _Screen.selection,
                onTap: () => onSelected(TTestKind.independentStudent),
              ),
              _ChoiceCard(
                accent: colors.cardB,
                status: 'Type values',
                statusTone: _StatusTone.warning,
                title: 'Equal variances not assumed',
                description: 'The SPSS Welch row',
                bars: const [0.84, 0.58, 0.70],
                guideTargetId: 'welch_test_path',
                guideScreen: _Screen.selection,
                onTap: () => onSelected(TTestKind.independentWelch),
              ),
              _ChoiceCard(
                accent: colors.cardC,
                status: 'Type values',
                statusTone: _StatusTone.accepted,
                title: 'Paired samples',
                description: 'Same people measured twice',
                bars: const [0.54, 0.76, 0.44],
                guideTargetId: 'paired_test_path',
                guideScreen: _Screen.selection,
                onTap: () => onSelected(TTestKind.pairedSamples),
              ),
              _ChoiceCard(
                accent: colors.cardD,
                status: 'Type values',
                statusTone: _StatusTone.accepted,
                title: 'One sample',
                description: 'One group compared with a number',
                bars: const [0.60, 0.38, 0.66],
                guideTargetId: 'one_sample_test_path',
                guideScreen: _Screen.selection,
                onTap: () => onSelected(TTestKind.oneSample),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputScreen extends StatelessWidget {
  const _InputScreen({
    required this.mode,
    required this.manualKind,
    required this.pasteController,
    required this.outcomeController,
    required this.alphaController,
    required this.confidenceController,
    required this.primaryLabelController,
    required this.secondaryLabelController,
    required this.primaryNController,
    required this.secondaryNController,
    required this.primaryMeanController,
    required this.secondaryMeanController,
    required this.primarySdController,
    required this.secondarySdController,
    required this.referenceMeanController,
    required this.pairedMeanDifferenceController,
    required this.pairedDifferenceSdController,
    required this.pairedCorrelationController,
    required this.reportedTController,
    required this.reportedDfController,
    required this.reportedPController,
    required this.reportedMeanDifferenceController,
    required this.reportedSeController,
    required this.ciLowerController,
    required this.ciUpperController,
    required this.manualTail,
    required this.pasteResult,
    required this.selectedCandidate,
    required this.confirmedPasteTail,
    required this.inputError,
    required this.selectedExample,
    required this.onBack,
    required this.onExampleChanged,
    required this.onLoadExample,
    required this.onShowSpreadsheetBoundary,
    required this.onManualKindChanged,
    required this.onManualTailChanged,
    required this.onReviewPaste,
    required this.onCandidateChanged,
    required this.onPasteTailChanged,
    required this.onConfirmPaste,
    required this.onValidateManual,
    required this.pasteCanConfirm,
  });

  final _InputMode mode;
  final TTestKind manualKind;
  final TextEditingController pasteController;
  final TextEditingController outcomeController;
  final TextEditingController alphaController;
  final TextEditingController confidenceController;
  final TextEditingController primaryLabelController;
  final TextEditingController secondaryLabelController;
  final TextEditingController primaryNController;
  final TextEditingController secondaryNController;
  final TextEditingController primaryMeanController;
  final TextEditingController secondaryMeanController;
  final TextEditingController primarySdController;
  final TextEditingController secondarySdController;
  final TextEditingController referenceMeanController;
  final TextEditingController pairedMeanDifferenceController;
  final TextEditingController pairedDifferenceSdController;
  final TextEditingController pairedCorrelationController;
  final TextEditingController reportedTController;
  final TextEditingController reportedDfController;
  final TextEditingController reportedPController;
  final TextEditingController reportedMeanDifferenceController;
  final TextEditingController reportedSeController;
  final TextEditingController ciLowerController;
  final TextEditingController ciUpperController;
  final ReportedPValueTail manualTail;
  final TTestPasteParseResult? pasteResult;
  final PasteTTestCandidate? selectedCandidate;
  final ReportedPValueTail? confirmedPasteTail;
  final String? inputError;
  final _PasteExample selectedExample;
  final VoidCallback onBack;
  final ValueChanged<_PasteExample> onExampleChanged;
  final ValueChanged<_PasteExample> onLoadExample;
  final VoidCallback onShowSpreadsheetBoundary;
  final ValueChanged<TTestKind> onManualKindChanged;
  final ValueChanged<ReportedPValueTail> onManualTailChanged;
  final VoidCallback onReviewPaste;
  final ValueChanged<PasteTTestCandidate> onCandidateChanged;
  final ValueChanged<ReportedPValueTail> onPasteTailChanged;
  final VoidCallback onConfirmPaste;
  final VoidCallback onValidateManual;
  final bool pasteCanConfirm;

  @override
  Widget build(BuildContext context) {
    final copy = _InputCopy.forMode(mode, manualKind);
    final colors = _RqColors.of(context);
    return _ScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(
            kicker: copy.kicker,
            title: copy.title,
            body: copy.body,
            backLabel: 'Back to start',
            onBack: onBack,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final pastePanel = _PastePanel(
                copy: copy,
                pasteController: pasteController,
                pasteResult: pasteResult,
                selectedCandidate: selectedCandidate,
                confirmedPasteTail: confirmedPasteTail,
                inputError: inputError,
                selectedExample: selectedExample,
                pasteCanConfirm: pasteCanConfirm,
                onExampleChanged: onExampleChanged,
                onLoadExample: onLoadExample,
                onShowSpreadsheetBoundary: onShowSpreadsheetBoundary,
                onReviewPaste: onReviewPaste,
                onCandidateChanged: onCandidateChanged,
                onPasteTailChanged: onPasteTailChanged,
                onConfirmPaste: onConfirmPaste,
              );
              final formPanel = _ManualFormPanel(
                manualKind: manualKind,
                manualTail: manualTail,
                outcomeController: outcomeController,
                alphaController: alphaController,
                confidenceController: confidenceController,
                primaryLabelController: primaryLabelController,
                secondaryLabelController: secondaryLabelController,
                primaryNController: primaryNController,
                secondaryNController: secondaryNController,
                primaryMeanController: primaryMeanController,
                secondaryMeanController: secondaryMeanController,
                primarySdController: primarySdController,
                secondarySdController: secondarySdController,
                referenceMeanController: referenceMeanController,
                pairedMeanDifferenceController: pairedMeanDifferenceController,
                pairedDifferenceSdController: pairedDifferenceSdController,
                pairedCorrelationController: pairedCorrelationController,
                reportedTController: reportedTController,
                reportedDfController: reportedDfController,
                reportedPController: reportedPController,
                reportedMeanDifferenceController:
                    reportedMeanDifferenceController,
                reportedSeController: reportedSeController,
                ciLowerController: ciLowerController,
                ciUpperController: ciUpperController,
                selectedExample: selectedExample,
                onExampleChanged: onExampleChanged,
                onLoadExample: onLoadExample,
                onShowSpreadsheetBoundary: onShowSpreadsheetBoundary,
                onManualKindChanged: onManualKindChanged,
                onManualTailChanged: onManualTailChanged,
                onValidateManual: onValidateManual,
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [pastePanel, const SizedBox(height: 18), formPanel],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 13, child: pastePanel),
                  const SizedBox(width: 18),
                  Expanded(flex: 9, child: formPanel),
                ],
              );
            },
          ),
          if (colors.isDark) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _PastePanel extends StatelessWidget {
  const _PastePanel({
    required this.copy,
    required this.pasteController,
    required this.pasteResult,
    required this.selectedCandidate,
    required this.confirmedPasteTail,
    required this.inputError,
    required this.selectedExample,
    required this.pasteCanConfirm,
    required this.onExampleChanged,
    required this.onLoadExample,
    required this.onShowSpreadsheetBoundary,
    required this.onReviewPaste,
    required this.onCandidateChanged,
    required this.onPasteTailChanged,
    required this.onConfirmPaste,
  });

  final _InputCopy copy;
  final TextEditingController pasteController;
  final TTestPasteParseResult? pasteResult;
  final PasteTTestCandidate? selectedCandidate;
  final ReportedPValueTail? confirmedPasteTail;
  final String? inputError;
  final _PasteExample selectedExample;
  final bool pasteCanConfirm;
  final ValueChanged<_PasteExample> onExampleChanged;
  final ValueChanged<_PasteExample> onLoadExample;
  final VoidCallback onShowSpreadsheetBoundary;
  final VoidCallback onReviewPaste;
  final ValueChanged<PasteTTestCandidate> onCandidateChanged;
  final ValueChanged<ReportedPValueTail> onPasteTailChanged;
  final VoidCallback onConfirmPaste;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final pasteBoxHeight = MediaQuery.sizeOf(context).width < 520
        ? 260.0
        : 416.0;
    return _GlassPanel(
      accent: colors.cyan,
      guideTargetId: 'paste_panel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTop(
            title: copy.pasteTitle,
            body: copy.pasteBody,
            guide: const _GuideButtonConfig(
              screen: _Screen.input,
              targetId: 'paste_panel',
            ),
          ),
          _ExampleControls(
            keyPrefix: 'paste',
            selectedExample: selectedExample,
            onExampleChanged: onExampleChanged,
            onLoadExample: onLoadExample,
            onShowSpreadsheetBoundary: onShowSpreadsheetBoundary,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: pasteBoxHeight,
            child: TextField(
              key: const Key('paste-output-box'),
              controller: pasteController,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              style: TextStyle(
                color: colors.fieldText,
                fontFamily: 'Consolas',
                fontSize: 13.5,
                height: 1.48,
              ),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'T-test output',
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                key: const Key('review-detected-fields'),
                label: 'Review output',
                tone: _ButtonTone.primary,
                onPressed: onReviewPaste,
              ),
            ],
          ),
          if (inputError != null) ...[
            const SizedBox(height: 14),
            _NoticeBox(tone: _StatusTone.error, text: inputError!),
          ],
          if (pasteResult != null) ...[
            const SizedBox(height: 18),
            _PasteReview(
              result: pasteResult!,
              selectedCandidate: selectedCandidate,
              confirmedPasteTail: confirmedPasteTail,
              canConfirm: pasteCanConfirm,
              onCandidateChanged: onCandidateChanged,
              onPasteTailChanged: onPasteTailChanged,
              onConfirmPaste: onConfirmPaste,
            ),
          ],
        ],
      ),
    );
  }
}

class _PasteReview extends StatelessWidget {
  const _PasteReview({
    required this.result,
    required this.selectedCandidate,
    required this.confirmedPasteTail,
    required this.canConfirm,
    required this.onCandidateChanged,
    required this.onPasteTailChanged,
    required this.onConfirmPaste,
  });

  final TTestPasteParseResult result;
  final PasteTTestCandidate? selectedCandidate;
  final ReportedPValueTail? confirmedPasteTail;
  final bool canConfirm;
  final ValueChanged<PasteTTestCandidate> onCandidateChanged;
  final ValueChanged<ReportedPValueTail> onPasteTailChanged;
  final VoidCallback onConfirmPaste;

  @override
  Widget build(BuildContext context) {
    if (result.status == PasteParseStatus.cannotParse) {
      return _ReviewBlock(
        title: 'Cannot use this paste',
        children: [
          for (final reason in result.refusalReasons)
            _NoticeBox(tone: _StatusTone.error, text: reason),
          if (result.refusalReasons.any(
            (reason) => reason.contains('raw spreadsheet rows'),
          )) ...[
            const SizedBox(height: 8),
            const _NoticeBox(
              tone: _StatusTone.warning,
              text: _spreadsheetBoundaryMessage,
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Paste t-test output, or type the values below.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    final needsTail = _needsTailResolution(result, selectedCandidate);
    final missingFields =
        selectedCandidate?.missingRequiredFields(
          confirmedPValueTail: confirmedPasteTail,
        ) ??
        result.missingRequiredFields;
    return _ReviewBlock(
      title: 'Check what was found',
      children: [
        if (result.ambiguities.isNotEmpty)
          for (final ambiguity in result.ambiguities)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NoticeBox(
                tone: _StatusTone.warning,
                text: ambiguity.message,
              ),
            ),
        if (result.candidates.length > 1) ...[
          const _Subhead('Choose the SPSS row'),
          RadioGroup<PasteTTestCandidate>(
            groupValue: selectedCandidate,
            onChanged: (value) {
              if (value != null) {
                onCandidateChanged(value);
              }
            },
            child: Column(
              children: [
                for (final candidate in result.candidates)
                  RadioListTile<PasteTTestCandidate>(
                    value: candidate,
                    title: Text(candidate.label),
                    subtitle: Text(_varianceRowSubtitle(candidate)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ],
        if (needsTail) ...[
          const _Subhead('Choose p-value direction'),
          RadioGroup<ReportedPValueTail>(
            groupValue: confirmedPasteTail,
            onChanged: (value) {
              if (value != null) {
                onPasteTailChanged(value);
              }
            },
            child: const Column(
              children: [
                RadioListTile<ReportedPValueTail>(
                  key: Key('paste-tail-two-tailed'),
                  value: ReportedPValueTail.twoTailed,
                  title: Text('Two-tailed'),
                  subtitle: Text('Use SPSS Sig. (2-tailed).'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<ReportedPValueTail>(
                  value: ReportedPValueTail.less,
                  title: Text('Lower-tail'),
                  subtitle: Text(
                    'Use only if the assignment predicts lower values.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<ReportedPValueTail>(
                  value: ReportedPValueTail.greater,
                  title: Text('Upper-tail'),
                  subtitle: Text(
                    'Use only if the assignment predicts higher values.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
        if (missingFields.isNotEmpty) ...[
          const _Subhead('Missing'),
          for (final missing in missingFields)
            _IssueRow(
              tone: _StatusTone.warning,
              field: _missingFieldLabel(missing),
              title: _missingTitle(missing),
              body: _missingBody(missing),
            ),
        ],
        const SizedBox(height: 8),
        _ActionButton(
          key: const Key('confirm-detected-values'),
          label: 'Use these values',
          tone: _ButtonTone.primary,
          onPressed: canConfirm ? onConfirmPaste : null,
        ),
        if (result.fields.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Disclosure(
            showLabel: 'Show all found values',
            hideLabel: 'Hide all found values',
            children: [
              for (final field in result.fields)
                _IssueRow(
                  tone: _StatusTone.accepted,
                  field: field.key.label,
                  title: '${field.key.path} = ${field.describeValue()}',
                  body: 'From: ${field.sourceText}',
                ),
            ],
          ),
        ],
      ],
    );
  }

  static bool _needsTailResolution(
    TTestPasteParseResult result,
    PasteTTestCandidate? candidate,
  ) {
    if (result.ambiguities.any((item) => item.id.startsWith('p.tail'))) {
      return true;
    }
    return candidate?.reportedPValueTail ==
        ReportedPValueTail.oneTailedObservedDirection;
  }

  static String _varianceRowSubtitle(PasteTTestCandidate candidate) {
    final rowName = candidate.kind == TTestKind.independentStudent
        ? 'Student row'
        : 'Welch row';
    final leveneP = candidate.number(PasteFieldKey.leveneP);
    if (leveneP == null) {
      return candidate.kind == TTestKind.independentStudent
          ? "$rowName. Use when Levene's Sig. is .05 or larger."
          : "$rowName. Use when Levene's Sig. is below .05.";
    }

    final pointsToWelch = leveneP.value < 0.05;
    final pointsToThisRow =
        pointsToWelch == (candidate.kind == TTestKind.independentWelch);
    final suggestion = pointsToThisRow
        ? 'SPSS points to this row'
        : 'use this only if assigned';
    return "$rowName. Levene's Sig. = ${_fmtPasteNumber(leveneP)}; "
        'with .05 rule, $suggestion.';
  }

  static String _fmtPasteNumber(PasteNumber number) {
    final prefix = number.relation == ReportedRelation.equalRounded
        ? ''
        : '${number.relationSymbol} ';
    return '$prefix${_fmt(number.value)}';
  }

  static String _missingFieldLabel(PasteMissingField missing) {
    return switch (missing.key) {
      PasteFieldKey.primaryLabel => 'Group 1 label',
      PasteFieldKey.primaryN => 'Group 1 n',
      PasteFieldKey.primaryMean => 'Group 1 mean',
      PasteFieldKey.primaryStandardDeviation => 'Group 1 SD',
      PasteFieldKey.secondaryLabel => 'Group 2 label',
      PasteFieldKey.secondaryN => 'Group 2 n',
      PasteFieldKey.secondaryMean => 'Group 2 mean',
      PasteFieldKey.secondaryStandardDeviation => 'Group 2 SD',
      PasteFieldKey.pairedMeanDifference => 'Paired mean difference',
      PasteFieldKey.pairedDifferenceStandardDeviation => 'Paired difference SD',
      PasteFieldKey.pairedCorrelation => 'Paired correlation',
      PasteFieldKey.referenceMean => 'Reference mean',
      PasteFieldKey.reportedT => 't',
      PasteFieldKey.reportedDegreesOfFreedom => 'df',
      PasteFieldKey.reportedP => 'p value',
      PasteFieldKey.reportedMeanDifference => 'Mean difference',
      PasteFieldKey.reportedStandardError => 'SE',
      PasteFieldKey.ciLower => 'CI lower',
      PasteFieldKey.ciUpper => 'CI upper',
      PasteFieldKey.confidenceLevel => 'CI confidence level',
      PasteFieldKey.leveneF => "Levene's F",
      PasteFieldKey.leveneP => "Levene's Sig.",
      null => 'Confirmation',
    };
  }

  static String _missingTitle(PasteMissingField missing) {
    return switch (missing.key) {
      PasteFieldKey.confidenceLevel => 'Enter the CI level, usually .95.',
      PasteFieldKey.reportedT => 'Find t in the selected test row.',
      PasteFieldKey.reportedDegreesOfFreedom =>
        'Find df in the selected test row.',
      PasteFieldKey.reportedP => 'Find p or Sig. in the selected test row.',
      PasteFieldKey.primaryN ||
      PasteFieldKey.primaryMean ||
      PasteFieldKey.primaryStandardDeviation ||
      PasteFieldKey.secondaryN ||
      PasteFieldKey.secondaryMean ||
      PasteFieldKey.secondaryStandardDeviation =>
        'Find this value in Group Statistics.',
      PasteFieldKey.referenceMean => 'Enter the test value for one sample.',
      PasteFieldKey.pairedMeanDifference ||
      PasteFieldKey.pairedDifferenceStandardDeviation =>
        'Find this value in Paired Differences.',
      _ => '${_missingFieldLabel(missing)} was not found.',
    };
  }

  static String _missingBody(PasteMissingField missing) {
    return switch (missing.key) {
      PasteFieldKey.confidenceLevel =>
        'Look for 95% before Confidence Interval; type .95.',
      PasteFieldKey.reportedT => 'Copy the number from the t column.',
      PasteFieldKey.reportedDegreesOfFreedom =>
        'Copy the df value; decimals are ok for Welch.',
      PasteFieldKey.reportedP =>
        'Use Sig. (2-tailed), or type < .001 for SPSS .000.',
      PasteFieldKey.primaryN => 'Copy Group 1 N.',
      PasteFieldKey.primaryMean => 'Copy Group 1 Mean.',
      PasteFieldKey.primaryStandardDeviation => 'Copy Group 1 Std. Deviation.',
      PasteFieldKey.secondaryN => 'Copy Group 2 N.',
      PasteFieldKey.secondaryMean => 'Copy Group 2 Mean.',
      PasteFieldKey.secondaryStandardDeviation =>
        'Copy Group 2 Std. Deviation.',
      PasteFieldKey.referenceMean =>
        'Use the comparison value named in your output or assignment.',
      PasteFieldKey.pairedMeanDifference =>
        'Copy the Mean from the Paired Differences row.',
      PasteFieldKey.pairedDifferenceStandardDeviation =>
        'Copy the Std. Deviation from Paired Differences.',
      _ => 'Choose or type the missing value before continuing.',
    };
  }
}

class _ManualFormPanel extends StatelessWidget {
  const _ManualFormPanel({
    required this.manualKind,
    required this.manualTail,
    required this.outcomeController,
    required this.alphaController,
    required this.confidenceController,
    required this.primaryLabelController,
    required this.secondaryLabelController,
    required this.primaryNController,
    required this.secondaryNController,
    required this.primaryMeanController,
    required this.secondaryMeanController,
    required this.primarySdController,
    required this.secondarySdController,
    required this.referenceMeanController,
    required this.pairedMeanDifferenceController,
    required this.pairedDifferenceSdController,
    required this.pairedCorrelationController,
    required this.reportedTController,
    required this.reportedDfController,
    required this.reportedPController,
    required this.reportedMeanDifferenceController,
    required this.reportedSeController,
    required this.ciLowerController,
    required this.ciUpperController,
    required this.selectedExample,
    required this.onExampleChanged,
    required this.onLoadExample,
    required this.onShowSpreadsheetBoundary,
    required this.onManualKindChanged,
    required this.onManualTailChanged,
    required this.onValidateManual,
  });

  final TTestKind manualKind;
  final ReportedPValueTail manualTail;
  final TextEditingController outcomeController;
  final TextEditingController alphaController;
  final TextEditingController confidenceController;
  final TextEditingController primaryLabelController;
  final TextEditingController secondaryLabelController;
  final TextEditingController primaryNController;
  final TextEditingController secondaryNController;
  final TextEditingController primaryMeanController;
  final TextEditingController secondaryMeanController;
  final TextEditingController primarySdController;
  final TextEditingController secondarySdController;
  final TextEditingController referenceMeanController;
  final TextEditingController pairedMeanDifferenceController;
  final TextEditingController pairedDifferenceSdController;
  final TextEditingController pairedCorrelationController;
  final TextEditingController reportedTController;
  final TextEditingController reportedDfController;
  final TextEditingController reportedPController;
  final TextEditingController reportedMeanDifferenceController;
  final TextEditingController reportedSeController;
  final TextEditingController ciLowerController;
  final TextEditingController ciUpperController;
  final _PasteExample selectedExample;
  final ValueChanged<_PasteExample> onExampleChanged;
  final ValueChanged<_PasteExample> onLoadExample;
  final VoidCallback onShowSpreadsheetBoundary;
  final ValueChanged<TTestKind> onManualKindChanged;
  final ValueChanged<ReportedPValueTail> onManualTailChanged;
  final VoidCallback onValidateManual;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return _GlassPanel(
      accent: colors.violet,
      guideTargetId: 'structured_fields_panel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTop(
            title: 'Type values',
            guide: _GuideButtonConfig(
              screen: _Screen.input,
              targetId: 'structured_fields_panel',
            ),
          ),
          _ExampleControls(
            keyPrefix: 'manual',
            selectedExample: selectedExample,
            onExampleChanged: onExampleChanged,
            onLoadExample: onLoadExample,
            onShowSpreadsheetBoundary: onShowSpreadsheetBoundary,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<TTestKind>(
            key: const Key('manual-kind-field'),
            initialValue: manualKind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Test type'),
            items: TTestKind.values
                .map(
                  (kind) => DropdownMenuItem(
                    value: kind,
                    child: Text(
                      _kindLabel(kind),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onManualKindChanged(value);
              }
            },
          ),
          const SizedBox(height: 14),
          _FieldRow(
            children: [
              _Field(controller: outcomeController, label: 'Outcome label'),
              _Field(
                controller: alphaController,
                label: 'Alpha (course, usually .05)',
              ),
            ],
          ),
          _FieldRow(
            children: [
              DropdownButtonFormField<ReportedPValueTail>(
                initialValue: manualTail,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'p direction'),
                items: const [
                  DropdownMenuItem(
                    value: ReportedPValueTail.twoTailed,
                    child: Text('Two-tailed'),
                  ),
                  DropdownMenuItem(
                    value: ReportedPValueTail.less,
                    child: Text('Lower-tail'),
                  ),
                  DropdownMenuItem(
                    value: ReportedPValueTail.greater,
                    child: Text('Upper-tail'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onManualTailChanged(value);
                  }
                },
              ),
              _Field(
                controller: confidenceController,
                label: 'CI level (usually .95)',
              ),
            ],
          ),
          const _Subhead('Test numbers'),
          _FieldRow(
            children: [
              _Field(controller: reportedTController, label: 't'),
              _Field(
                controller: reportedDfController,
                label: 'df (Welch can be decimal)',
              ),
            ],
          ),
          _FieldRow(
            children: [
              _Field(
                controller: reportedPController,
                label: 'p (SPSS .000: use < .001)',
              ),
              _Field(
                controller: reportedMeanDifferenceController,
                label: 'Mean difference',
              ),
            ],
          ),
          _FieldRow(
            children: [
              _Field(controller: reportedSeController, label: 'SE'),
              _Field(controller: ciLowerController, label: 'CI lower'),
            ],
          ),
          _FieldRow(
            children: [
              _Field(controller: ciUpperController, label: 'CI upper'),
            ],
          ),
          const _Subhead('Descriptives'),
          _FieldRow(
            children: [
              _Field(
                controller: primaryLabelController,
                label: manualKind == TTestKind.pairedSamples
                    ? 'First label'
                    : 'Group 1 label',
              ),
              if (manualKind != TTestKind.oneSample)
                _Field(
                  controller: secondaryLabelController,
                  label: manualKind == TTestKind.pairedSamples
                      ? 'Second label'
                      : 'Group 2 label',
                ),
            ],
          ),
          _FieldRow(
            children: [
              _Field(controller: primaryMeanController, label: 'Group 1 mean'),
              if (manualKind != TTestKind.oneSample)
                _Field(
                  controller: secondaryMeanController,
                  label: 'Group 2 mean',
                ),
            ],
          ),
          _FieldRow(
            children: [
              _Field(controller: primarySdController, label: 'Group 1 SD'),
              if (manualKind != TTestKind.oneSample)
                _Field(controller: secondarySdController, label: 'Group 2 SD'),
            ],
          ),
          _FieldRow(
            children: [
              _Field(controller: primaryNController, label: 'Group 1 n'),
              if (manualKind != TTestKind.oneSample)
                _Field(controller: secondaryNController, label: 'Group 2 n'),
            ],
          ),
          if (manualKind == TTestKind.oneSample)
            _FieldRow(
              children: [
                _Field(
                  controller: referenceMeanController,
                  label: 'Reference mean',
                ),
              ],
            ),
          if (manualKind == TTestKind.pairedSamples) ...[
            const _Subhead('Paired differences'),
            _FieldRow(
              children: [
                _Field(
                  controller: pairedMeanDifferenceController,
                  label: 'Mean difference',
                ),
                _Field(
                  controller: pairedDifferenceSdController,
                  label: 'Difference SD',
                ),
              ],
            ),
            _FieldRow(
              children: [
                _Field(
                  controller: pairedCorrelationController,
                  label: 'Correlation optional',
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _ActionButton(
            key: const Key('validate-entered-values'),
            label: 'Check values',
            tone: _ButtonTone.primary,
            onPressed: onValidateManual,
          ),
        ],
      ),
    );
  }
}

class _ValidationScreen extends StatelessWidget {
  const _ValidationScreen({
    required this.checks,
    required this.input,
    required this.result,
    required this.onBack,
    required this.onGenerate,
  });

  final List<ValidationCheck> checks;
  final TTestValidationInput? input;
  final TTestResult? result;
  final VoidCallback onBack;
  final VoidCallback onGenerate;

  bool get _hasFailures {
    return checks.any((check) => check.status == ValidationStatus.fail);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final failedChecks = checks
        .where((check) => check.status == ValidationStatus.fail)
        .toList();
    return _ScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(
            kicker: 'Check',
            title: 'Check the numbers.',
            body: 'Fix failed rows before generating the report.',
            backLabel: 'Back to input',
            onBack: onBack,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final summary = _GlassPanel(
                accent: colors.green,
                guideTargetId: 'validation_summary',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTop(
                      title: _parsedTitle(input),
                      guide: const _GuideButtonConfig(
                        screen: _Screen.validation,
                        targetId: 'validation_summary',
                      ),
                    ),
                    _ValueSummary(result: result, input: input, checks: checks),
                  ],
                ),
              );
              final decisions = _GlassPanel(
                accent: colors.violet,
                guideTargetId: 'validation_decisions',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTop(
                      title: 'Problems to fix',
                      guide: _GuideButtonConfig(
                        screen: _Screen.validation,
                        targetId: 'validation_decisions',
                      ),
                    ),
                    if (failedChecks.isEmpty)
                      const _NoticeBox(
                        tone: _StatusTone.accepted,
                        text: 'No problems found.',
                      )
                    else
                      for (final check in failedChecks)
                        _IssueRow(
                          tone: _toneForCheck(check.status),
                          field: check.title,
                          title: _statusLabel(check.status),
                          body: _checkBody(check),
                        ),
                    const SizedBox(height: 18),
                    if (_hasFailures)
                      const _NoticeBox(
                        tone: _StatusTone.error,
                        text: 'Fix failed rows before generating a report.',
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ActionButton(
                          key: const Key('generate-report'),
                          label: 'Generate report',
                          tone: _ButtonTone.primary,
                          disabledHint: _generateReportDisabledHint(
                            result,
                            failedChecks,
                          ),
                          onPressed: !_hasFailures && result != null
                              ? onGenerate
                              : null,
                        ),
                        _ActionButton(
                          label: 'Edit values',
                          tone: _ButtonTone.secondary,
                          onPressed: onBack,
                        ),
                      ],
                    ),
                    if (checks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _Disclosure(
                        showLabel: 'Show all checks',
                        hideLabel: 'Hide all checks',
                        children: [
                          for (final check in checks)
                            _IssueRow(
                              tone: _toneForCheck(check.status),
                              field: check.title,
                              title: _statusLabel(check.status),
                              body: _checkBody(check),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _hasFailures
                      ? [decisions, const SizedBox(height: 18), summary]
                      : [summary, const SizedBox(height: 18), decisions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 9, child: summary),
                  const SizedBox(width: 18),
                  Expanded(flex: 11, child: decisions),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _parsedTitle(TTestValidationInput? input) {
    if (input == null) {
      return 'Your values';
    }
    return '${_kindShortLabel(input.kind)} values';
  }

  static String _checkBody(ValidationCheck check) {
    final parts = <String>[check.explanation];
    if (check.reported != null) {
      parts.add('Given: ${_fmt(check.reported!)}.');
    }
    if (check.recomputed != null) {
      parts.add('Calculated: ${_fmt(check.recomputed!)}.');
    }
    if (check.tolerance != null) {
      final label = check.tolerance!.startsWith('value was rounded')
          ? 'Allowed difference'
          : 'Check rule';
      parts.add('$label: ${check.tolerance}.');
    }
    return parts.join(' ');
  }

  static String? _generateReportDisabledHint(
    TTestResult? result,
    List<ValidationCheck> failedChecks,
  ) {
    if (failedChecks.isNotEmpty) {
      return 'Disabled because validation failed: '
          '${failedChecks.first.title}. Fix failed rows before generating a '
          'report.';
    }
    if (result == null) {
      return 'Disabled because the values could not be recalculated.';
    }
    return null;
  }
}

class _ValueSummary extends StatelessWidget {
  const _ValueSummary({
    required this.result,
    required this.input,
    required this.checks,
  });

  final TTestResult? result;
  final TTestValidationInput? input;
  final List<ValidationCheck> checks;

  @override
  Widget build(BuildContext context) {
    final failures = checks
        .where((check) => check.status == ValidationStatus.fail)
        .length;
    final reportedT = input?.reportedT;
    final reportedDf = input?.reportedDegreesOfFreedom;
    final reportedP = input?.reportedP;
    final tFailure = _firstFailureFor({'t.descriptives'});
    final tRelatedFailure = _firstFailureFor({'p.t_df'});
    final dfFailure = _firstFailureFor({'df.plausibility'});
    final dfRelatedFailure = _firstFailureFor({
      'p.t_df',
      'ci.diff_se',
      'ci.lower',
      'ci.upper',
    });
    final pFailure = _firstFailureFor({'domain.p', 'p.t_df'});
    return _ResponsiveGrid(
      columnsWhenWide: 2,
      minTileHeight: 190,
      children: [
        _ValueCard(
          cardKey: const Key('validation-summary-t'),
          tone: tFailure != null
              ? _StatusTone.error
              : tRelatedFailure != null
              ? _StatusTone.warning
              : reportedT == null || result == null
              ? _StatusTone.warning
              : _StatusTone.accepted,
          label: 't',
          value: reportedT == null
              ? 't not supplied'
              : 't = ${_fmt(reportedT.value)}',
          body: tFailure != null
              ? 'Problem row: ${tFailure.title}.'
              : tRelatedFailure != null
              ? 'Used in failing row: ${tRelatedFailure.title}.'
              : reportedT == null
              ? 'No reported t to check.'
              : result == null
              ? 'Could not recompute t.'
              : 'Checked against the descriptive statistics.',
        ),
        _ValueCard(
          cardKey: const Key('validation-summary-df'),
          tone: dfFailure != null
              ? _StatusTone.error
              : dfRelatedFailure != null
              ? _StatusTone.warning
              : reportedDf == null || result == null
              ? _StatusTone.warning
              : _StatusTone.accepted,
          label: 'df',
          value: reportedDf == null
              ? 'df not supplied'
              : 'df = ${_fmt(reportedDf.value)}',
          body: dfFailure != null
              ? 'Problem row: ${dfFailure.title}.'
              : dfRelatedFailure != null
              ? 'Used in failing row: ${dfRelatedFailure.title}.'
              : reportedDf == null
              ? 'No reported df to check.'
              : result?.kind == TTestKind.independentWelch
              ? 'Decimal df is valid for Welch.'
              : 'Matches the selected test.',
        ),
        _ValueCard(
          cardKey: const Key('validation-summary-p'),
          tone: pFailure != null
              ? _StatusTone.error
              : reportedP == null
              ? _StatusTone.warning
              : reportedP.relation == ReportedRelation.lessThan
              ? _StatusTone.warning
              : _StatusTone.accepted,
          label: 'p',
          value: reportedP == null
              ? 'p not supplied'
              : 'p ${_relationSymbol(reportedP.relation)} ${_fmt(reportedP.value)}',
          body: pFailure != null
              ? 'Problem row: ${pFailure.title}.'
              : reportedP == null
              ? 'No reported p to check.'
              : reportedP.relation == ReportedRelation.lessThan
              ? '.000 is shown as p < .001.'
              : 'Checked against t and df.',
        ),
        _ValueCard(
          cardKey: const Key('validation-summary-fails'),
          tone: failures > 0 ? _StatusTone.error : _StatusTone.accepted,
          label: 'Fails',
          value: failures > 0 ? '$failures fail' : '0 fail',
          body: failures > 0 ? 'Fix failed rows first.' : 'Ready for report.',
        ),
      ],
    );
  }

  ValidationCheck? _firstFailureFor(Set<String> ids) {
    for (final check in checks) {
      if (check.status == ValidationStatus.fail && ids.contains(check.id)) {
        return check;
      }
    }
    return null;
  }
}

class _ExampleControls extends StatelessWidget {
  const _ExampleControls({
    required this.keyPrefix,
    required this.selectedExample,
    required this.onExampleChanged,
    required this.onLoadExample,
    required this.onShowSpreadsheetBoundary,
  });

  final String keyPrefix;
  final _PasteExample selectedExample;
  final ValueChanged<_PasteExample> onExampleChanged;
  final ValueChanged<_PasteExample> onLoadExample;
  final VoidCallback onShowSpreadsheetBoundary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 4;
        final gaps = 10 * (columns - 1);
        final buttonWidth = (constraints.maxWidth - gaps) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final example in _pasteExamples)
              SizedBox(
                width: buttonWidth,
                child: _ActionButton(
                  key: Key('$keyPrefix-example-${example.id}'),
                  label: example.controlLabel,
                  tone: example == selectedExample
                      ? _ButtonTone.primary
                      : _ButtonTone.secondary,
                  onPressed: () {
                    onExampleChanged(example);
                    onLoadExample(example);
                  },
                ),
              ),
            _ActionButton(
              key: Key('$keyPrefix-spreadsheet-help'),
              label: 'CSV or Excel?',
              tone: _ButtonTone.tertiary,
              onPressed: onShowSpreadsheetBoundary,
            ),
          ],
        );
      },
    );
  }
}

class _ReportScreen extends StatelessWidget {
  const _ReportScreen({
    required this.report,
    required this.result,
    required this.options,
    required this.copyStatus,
    required this.onBack,
    required this.onEdit,
    required this.onCopy,
  });

  final TTestReportOutput? report;
  final TTestResult? result;
  final TTestReportOptions options;
  final String copyStatus;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final output = report;
    return _ScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(
            kicker: 'Report',
            title: 'Copy your report.',
            body: 'Use this wording in your assignment.',
            backLabel: 'Back to validation',
            onBack: onBack,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final prose = _GlassPanel(
                accent: colors.cyan,
                guideTargetId: 'report_prose',
                child: _ReportProse(
                  report: output,
                  copyStatus: copyStatus,
                  onCopy: onCopy,
                  onEdit: onEdit,
                ),
              );
              final charts = Column(
                children: [
                  _GlassPanel(
                    accent: colors.violet,
                    guideTargetId: 'ci_chart_panel',
                    padding: const EdgeInsets.all(18),
                    child: _ConfidenceIntervalChart(result: result),
                  ),
                  const SizedBox(height: 16),
                  _GlassPanel(
                    accent: colors.green,
                    guideTargetId: 'distribution_panel',
                    padding: const EdgeInsets.all(18),
                    child: _DistributionChart(result: result, options: options),
                  ),
                ],
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [prose, const SizedBox(height: 18), charts],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 10, child: prose),
                  const SizedBox(width: 18),
                  Expanded(flex: 8, child: charts),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportProse extends StatelessWidget {
  const _ReportProse({
    required this.report,
    required this.copyStatus,
    required this.onCopy,
    required this.onEdit,
  });

  final TTestReportOutput? report;
  final String copyStatus;
  final VoidCallback onCopy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final output = report;
    if (output == null) {
      return const _NoticeBox(tone: _StatusTone.error, text: 'UNKNOWN');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTop(
          title: 'APA wording',
          guide: _GuideButtonConfig(
            screen: _Screen.report,
            targetId: 'report_prose',
          ),
        ),
        if (output.isBlocked)
          _NoticeBox(
            tone: _StatusTone.error,
            text: output.refusalReason ?? 'Wording blocked.',
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                key: const Key('copy-report'),
                label: 'Copy report',
                tone: _ButtonTone.primary,
                onPressed: onCopy,
              ),
              _ActionButton(
                label: 'Edit values',
                tone: _ButtonTone.secondary,
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProseBox(title: 'APA result', reportText: output.formalResult),
          _ProseBox(title: 'Descriptives', text: output.descriptivesSentence),
          _ProseBox(title: 'Meaning', text: output.plainLanguageMeaning),
          _ProseBox(title: 'Effect size', text: output.effectSizeSentence),
          if (output.roundingCautions.isNotEmpty)
            _ListBox(
              title: 'Rounding cautions',
              items: output.roundingCautions,
            ),
          _SupportGrid(
            supported: output.supportedClaims,
            unsupported: output.unsupportedClaims,
          ),
          const SizedBox(height: 12),
          _Disclosure(
            showLabel: 'Show sources',
            hideLabel: 'Hide sources',
            children: [_EvidenceMapView(evidenceMap: output.evidenceMap)],
          ),
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(copyStatus),
            ),
          ),
        ],
      ],
    );
  }
}

class _SupportGrid extends StatelessWidget {
  const _SupportGrid({required this.supported, required this.unsupported});

  final List<String> supported;
  final List<String> unsupported;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final children = [
          _ListBox(title: 'What this supports', items: supported),
          _ListBox(title: 'What this does not show', items: unsupported),
        ];
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [children[0], const SizedBox(height: 12), children[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 12),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }
}

class _EvidenceMapView extends StatelessWidget {
  const _EvidenceMapView({required this.evidenceMap});

  final EvidenceMap evidenceMap;

  @override
  Widget build(BuildContext context) {
    return _ReviewBlock(
      title: 'Sources',
      children: [
        for (final entry in evidenceMap.entries)
          _IssueRow(
            tone: _StatusTone.accepted,
            field: entry.label,
            title: '${entry.formatted} from ${entry.source.provenance.label}',
            body: '${entry.section}: ${entry.source.field}',
          ),
      ],
    );
  }
}

class _ProseBox extends StatelessWidget {
  const _ProseBox({required this.title, this.text, this.reportText});

  final String title;
  final String? text;
  final ReportText? reportText;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.42),
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.cardTitle,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (reportText != null)
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: colors.cardText,
                  fontFamily: 'Segoe UI',
                  fontSize: 16.5,
                  height: 1.72,
                ),
                children: [
                  for (final run in reportText!.runs)
                    TextSpan(
                      text: run.text,
                      style: run.italic
                          ? const TextStyle(fontStyle: FontStyle.italic)
                          : null,
                    ),
                ],
              ),
            )
          else
            Text(
              text ?? 'UNKNOWN',
              style: TextStyle(
                color: colors.cardText,
                fontSize: 16.5,
                height: 1.72,
              ),
            ),
        ],
      ),
    );
  }
}

class _ListBox extends StatelessWidget {
  const _ListBox({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.40),
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: colors.title, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                item,
                style: TextStyle(color: colors.cardText, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfidenceIntervalChart extends StatelessWidget {
  const _ConfidenceIntervalChart({required this.result});

  final TTestResult? result;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final ci = result?.confidenceInterval;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTop(
          title: 'Confidence interval',
          guide: _GuideButtonConfig(
            screen: _Screen.report,
            targetId: 'ci_chart_panel',
          ),
        ),
        _ChartFrame(
          painter: _CiPainter(colors: colors, result: result),
          semanticsLabel: ci == null
              ? 'Confidence interval unavailable'
              : 'Confidence interval from ${_fmt(ci.lower)} to ${_fmt(ci.upper)}.',
        ),
        const SizedBox(height: 10),
        Text(
          ci == null
              ? 'UNKNOWN'
              : 'The ${ApaNumberFormat.percent(ci.level)} confidence interval '
                    '${ci.lower <= 0 && ci.upper >= 0 ? 'includes' : 'excludes'} zero.',
          style: TextStyle(
            color: colors.cardText,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        if (ci != null) ...[
          const SizedBox(height: 12),
          _ChartTable(
            values: {
              'Lower': _fmt(ci.lower),
              'Estimate': _fmt(result!.meanDifference),
              'Upper': _fmt(ci.upper),
            },
          ),
        ],
      ],
    );
  }
}

class _DistributionChart extends StatelessWidget {
  const _DistributionChart({required this.result, required this.options});

  final TTestResult? result;
  final TTestReportOptions options;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTop(
          title: 't distribution',
          guide: _GuideButtonConfig(
            screen: _Screen.report,
            targetId: 'distribution_panel',
          ),
        ),
        Text(
          result == null
              ? 'UNKNOWN'
              : 'df = ${_fmt(result!.degreesOfFreedom)}, ${_tailText(options.tail)}, '
                    'observed t = ${_fmt(result!.t)}.',
          style: TextStyle(color: colors.cardText),
        ),
        const SizedBox(height: 14),
        _ChartFrame(
          painter: _DistributionPainter(colors: colors, result: result),
          semanticsLabel: result == null
              ? 't distribution unavailable'
              : 'Observed t ${_fmt(result!.t)} with df ${_fmt(result!.degreesOfFreedom)}.',
        ),
      ],
    );
  }
}

class _ChartFrame extends StatelessWidget {
  const _ChartFrame({required this.painter, required this.semanticsLabel});

  final CustomPainter painter;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.40),
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(painter: painter, child: const SizedBox.expand()),
        ),
      ),
    );
  }
}

class _ChartTable extends StatelessWidget {
  const _ChartTable({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Row(
      children: [
        for (final item in values.entries) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.38),
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.key,
                    style: TextStyle(
                      color: colors.title,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(item.value, style: TextStyle(color: colors.cardText)),
                ],
              ),
            ),
          ),
          if (item.key != values.keys.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _CiPainter extends CustomPainter {
  const _CiPainter({required this.colors, required this.result});

  final _RqColors colors;
  final TTestResult? result;

  @override
  void paint(Canvas canvas, Size size) {
    final axisY = size.height * 0.67;
    final left = size.width * 0.14;
    final right = size.width * 0.86;
    final axisPaint = Paint()
      ..color = colors.chartAxis
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, axisY), Offset(right, axisY), axisPaint);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void label(String text, Offset offset, Color color, double size) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'Segoe UI',
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset - Offset(textPainter.width / 2, 0));
    }

    final result = this.result;
    if (result == null) {
      label(
        'UNKNOWN',
        Offset(size.width / 2, size.height * 0.34),
        colors.title,
        15,
      );
      return;
    }
    final ci = result.confidenceInterval;
    final minValue = math.min(0, ci.lower) - 1;
    final maxValue = math.max(result.meanDifference, ci.upper) + 1;
    double x(double value) {
      return left + (value - minValue) / (maxValue - minValue) * (right - left);
    }

    final lowX = x(ci.lower);
    final highX = x(ci.upper);
    final estimateX = x(result.meanDifference);
    final ciPaint = Paint()
      ..shader = LinearGradient(
        colors: [colors.cyan, colors.violet],
      ).createShader(Rect.fromLTRB(lowX, 0, highX, 0))
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(lowX, size.height * 0.38),
      Offset(highX, size.height * 0.38),
      ciPaint,
    );
    final capPaint = Paint()
      ..color = colors.violet
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(lowX, size.height * 0.32),
        Offset(lowX, size.height * 0.44),
        capPaint..color = colors.cyan,
      )
      ..drawLine(
        Offset(highX, size.height * 0.32),
        Offset(highX, size.height * 0.44),
        capPaint..color = colors.violet,
      )
      ..drawCircle(
        Offset(estimateX, size.height * 0.38),
        10,
        Paint()..color = colors.green,
      );
    label(_fmt(ci.lower), Offset(lowX, size.height * 0.25), colors.cyan, 13);
    label(
      _fmt(result.meanDifference),
      Offset(estimateX, size.height * 0.23),
      colors.green,
      14,
    );
    label(_fmt(ci.upper), Offset(highX, size.height * 0.25), colors.violet, 13);
    label('0', Offset(x(0), axisY + 20), colors.chartAxis, 13);
  }

  @override
  bool shouldRepaint(covariant _CiPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.result != result;
  }
}

class _DistributionPainter extends CustomPainter {
  const _DistributionPainter({required this.colors, required this.result});

  final _RqColors colors;
  final TTestResult? result;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * 0.72;
    final centerX = size.width / 2;
    final scaleX = size.width * 0.09;
    final scaleY = size.height * 0.38;
    final path = Path();
    for (var i = 0; i <= 160; i += 1) {
      final t = -4 + 8 * i / 160;
      final y = baseY - math.exp(-0.5 * t * t) * scaleY;
      final x = centerX + t * scaleX;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(centerX + 4 * scaleX, baseY)
      ..lineTo(centerX - 4 * scaleX, baseY)
      ..close();
    canvas.drawPath(fill, Paint()..color = colors.chartFill);
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.cyan
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, baseY),
      Offset(size.width * 0.88, baseY),
      Paint()
        ..color = colors.chartAxis
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(centerX, baseY),
      Offset(centerX, size.height * 0.18),
      Paint()
        ..color = colors.chartGrid
        ..strokeWidth = 1,
    );
    final result = this.result;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void label(String text, Offset offset, Color color, double size) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'Segoe UI',
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset - Offset(textPainter.width / 2, 0));
    }

    if (result == null) {
      label('UNKNOWN', Offset(centerX, size.height * 0.35), colors.title, 15);
      return;
    }
    final t = result.t.clamp(-4.0, 4.0);
    final observedX = centerX + t * scaleX;
    canvas.drawLine(
      Offset(observedX, size.height * 0.18),
      Offset(observedX, baseY),
      Paint()
        ..color = colors.error
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(observedX, size.height * 0.18),
      7,
      Paint()..color = colors.error,
    );
    label('0', Offset(centerX, baseY + 20), colors.chartAxis, 13);
    label(
      't = ${_fmt(result.t)}',
      Offset(observedX, size.height * 0.08),
      colors.error,
      13,
    );
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.result != result;
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      style: TextStyle(color: colors.fieldText),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520 || children.length == 1) {
            return Column(
              children: [
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: child,
                  ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i += 1) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PageHead extends StatelessWidget {
  const _PageHead({
    required this.kicker,
    required this.title,
    required this.body,
    required this.backLabel,
    required this.onBack,
  });

  final String kicker;
  final String title;
  final String body;
  final String backLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kicker,
              style: TextStyle(
                color: colors.accentPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              key: Key('page-$title'),
              style: TextStyle(
                color: colors.title,
                fontSize: compact ? 25 : 32,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                body,
                style: TextStyle(color: colors.muted, fontSize: 15.5),
              ),
            ),
          ],
        );
        final back = _ActionButton(
          label: backLabel,
          tone: _ButtonTone.secondary,
          onPressed: onBack,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: back),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: 18),
            back,
          ],
        );
      },
    );
  }
}

class _ScreenShell extends StatelessWidget {
  const _ScreenShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth < 720 ? 18.0 : 28.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 68, horizontal, 46),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1240,
                  minHeight: math.max(0, constraints.maxHeight - 114),
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTop extends StatelessWidget {
  const _SectionTop({required this.title, this.body, this.guide});

  final String title;
  final String? body;
  final _GuideButtonConfig? guide;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.cardTitle,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.18,
              ),
            ),
            if (body != null && body!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: TextStyle(color: colors.cardText, fontSize: 15),
              ),
            ],
          ],
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              if (guide != null) ...[
                const SizedBox(width: 10),
                _CardGuideButton(
                  screen: guide!.screen,
                  targetId: guide!.targetId,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.accent,
    required this.child,
    this.minHeight,
    this.padding = const EdgeInsets.all(22),
    this.guideTargetId,
  });

  final Color accent;
  final Widget child;
  final double? minHeight;
  final EdgeInsets padding;
  final String? guideTargetId;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final panel = Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.62),
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 46,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: accent.withValues(alpha: colors.washOpacity),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
    final targetId = guideTargetId;
    if (targetId == null) {
      return panel;
    }
    return _GuideTarget(id: targetId, child: panel);
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    required this.minTileHeight,
    this.columnsWhenWide = 2,
  });

  final List<Widget> children;
  final double minTileHeight;
  final int columnsWhenWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720 ? 1 : columnsWhenWide;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: columns == 1
              ? math.max(1.18, constraints.maxWidth / minTileHeight)
              : math.max(1.0, (constraints.maxWidth / columns) / minTileHeight),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

enum _StatusTone { accepted, warning, error }

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.accent,
    required this.status,
    required this.statusTone,
    required this.title,
    required this.description,
    required this.bars,
    this.guideTargetId,
    this.guideScreen,
    this.disabled = false,
    this.onTap,
  });

  final Color accent;
  final String status;
  final _StatusTone statusTone;
  final String title;
  final String description;
  final List<double> bars;
  final String? guideTargetId;
  final _Screen? guideScreen;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final borderColor = disabled
        ? colors.lineStrong
        : Color.lerp(accent, colors.line, 0.52)!;
    final content = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 50)
          : const Duration(milliseconds: 220),
      constraints: const BoxConstraints(minHeight: 210),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: disabled ? 0.44 : 0.62),
        border: Border.all(
          color: borderColor,
          style: disabled ? BorderStyle.solid : BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: disabled ? 30 : 46,
            offset: Offset(0, disabled ? 12 : 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: accent.withValues(alpha: disabled ? 0.055 : 0.18),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 10,
              color: accent.withValues(alpha: disabled ? 0.46 : 0.96),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _StatusLabel(
                          tone: statusTone,
                          text: status,
                          accent: accent,
                        ),
                      ),
                    ),
                    if (guideTargetId != null && guideScreen != null) ...[
                      const SizedBox(width: 10),
                      _CardGuideButton(
                        screen: guideScreen!,
                        targetId: guideTargetId!,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: disabled ? colors.muted : colors.cardTitle,
                    fontSize: 22,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: TextStyle(
                    color: disabled ? colors.muted : colors.cardText,
                    fontSize: 15.2,
                    height: 1.45,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 22),
                _LineStack(accent: accent, bars: bars),
              ],
            ),
          ),
        ],
      ),
    );

    if (disabled) {
      final card = Semantics(
        button: true,
        enabled: false,
        label: '$title. $description. $status.',
        child: ExcludeSemantics(child: ExcludeFocus(child: content)),
      );
      final targetId = guideTargetId;
      if (targetId == null) {
        return card;
      }
      return _GuideTarget(id: targetId, child: card);
    }

    final card = Semantics(
      button: true,
      enabled: true,
      label: '$title. $description. $status.',
      child: ExcludeSemantics(
        child: _FocusableTap(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      ),
    );
    final targetId = guideTargetId;
    if (targetId == null) {
      return card;
    }
    return _GuideTarget(id: targetId, child: card);
  }
}

class _FocusableTap extends StatefulWidget {
  const _FocusableTap({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  State<_FocusableTap> createState() => _FocusableTapState();
}

class _FocusableTapState extends State<_FocusableTap> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: _focused ? Border.all(color: colors.cyan, width: 2) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: widget.onTap != null,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: widget.borderRadius,
          focusColor: colors.cyan.withValues(alpha: 0.16),
          hoverColor: colors.cyan.withValues(alpha: 0.08),
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.tone,
    required this.text,
    required this.accent,
  });

  final _StatusTone tone;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final toneColor = _toneColor(colors, tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: toneColor,
            borderRadius: BorderRadius.circular(
              tone == _StatusTone.error ? 3 : 99,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 25),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            border: Border.all(color: accent.withValues(alpha: 0.48)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: colors.cardText,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LineStack extends StatelessWidget {
  const _LineStack({required this.accent, required this.bars});

  final Color accent;
  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        children: [
          for (final width in bars)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.56),
                  border: Border.all(color: colors.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, colors.green]),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.tone,
    required this.onPressed,
    this.disabledHint,
  });

  final String label;
  final _ButtonTone tone;
  final VoidCallback? onPressed;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final enabled = onPressed != null;
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 46)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      overlayColor: WidgetStateProperty.all(
        colors.cyan.withValues(alpha: 0.12),
      ),
      side: WidgetStateProperty.resolveWith((states) {
        if (tone == _ButtonTone.primary) {
          return BorderSide.none;
        }
        return BorderSide(color: colors.lineStrong);
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (!enabled) {
          return colors.surface.withValues(alpha: 0.32);
        }
        return switch (tone) {
          _ButtonTone.primary => colors.cyan,
          _ButtonTone.secondary => colors.surface.withValues(alpha: 0.50),
          _ButtonTone.tertiary => Colors.transparent,
        };
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (!enabled) {
          return colors.mutedSoft;
        }
        return tone == _ButtonTone.primary ? colors.buttonText : colors.title;
      }),
      textStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        hint: enabled ? null : disabledHint,
        child: FilledButton(
          onPressed: onPressed,
          style: style,
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isLight, required this.onPressed});

  final bool isLight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      label: isLight ? 'DARK VIEW' : 'BRIGHT VIEW',
      tone: _ButtonTone.secondary,
      onPressed: onPressed,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Semantics(
      label: 'Res-Quill mark',
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.cyan.withValues(alpha: 0.46)),
          gradient: LinearGradient(
            colors: [
              colors.cyan.withValues(alpha: 0.22),
              colors.violet.withValues(alpha: 0.16),
            ],
          ),
          color: colors.surface.withValues(alpha: 0.64),
        ),
        child: CustomPaint(painter: _BrandMarkPainter(colors)),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.colors);

  final _RqColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = colors.cyan
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.52),
      Offset(size.width * 0.78, size.height * 0.52),
      linePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.50),
      5,
      Paint()..color = colors.green,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer();

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return IgnorePointer(
      child: CustomPaint(
        painter: _BackgroundPainter(
          colors,
          MediaQuery.disableAnimationsOf(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter(this.colors, this.reducedMotion);

  final _RqColors colors;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colors.cyan.withValues(alpha: reducedMotion ? 0.09 : 0.16);
    for (var row = 0; row < 3; row += 1) {
      final path = Path();
      final y = size.height * (0.28 + row * 0.14);
      path.moveTo(0, y);
      for (var x = 0.0; x <= size.width + 240; x += 240) {
        path.quadraticBezierTo(x + 120, y - 70 + row * 30, x + 240, y);
      }
      canvas.drawPath(
        path,
        paint
          ..color = [
            colors.cyan,
            colors.violet,
            colors.error,
          ][row].withValues(alpha: reducedMotion ? 0.07 : 0.14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.reducedMotion != reducedMotion;
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.42),
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.cardTitle,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Disclosure extends StatefulWidget {
  const _Disclosure({
    required this.showLabel,
    required this.hideLabel,
    required this.children,
  });

  final String showLabel;
  final String hideLabel;
  final List<Widget> children;

  @override
  State<_Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<_Disclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _ActionButton(
            label: _open ? widget.hideLabel : widget.showLabel,
            tone: _ButtonTone.tertiary,
            onPressed: () => setState(() => _open = !_open),
          ),
        ),
        if (_open) ...[const SizedBox(height: 12), ...widget.children],
      ],
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.tone,
    required this.field,
    required this.title,
    required this.body,
  });

  final _StatusTone tone;
  final String field;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.42),
        border: Border.all(
          color: _toneColor(colors, tone).withValues(alpha: 0.46),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusLabel(
                tone: tone,
                text: _statusToneLabel(tone),
                accent: _toneColor(colors, tone),
              ),
              const SizedBox(height: 8),
              Text(
                field,
                style: TextStyle(
                  color: colors.title,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.title,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  color: colors.cardText,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 10), copy],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 150, child: label),
              const SizedBox(width: 12),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    this.cardKey,
    required this.tone,
    required this.label,
    required this.value,
    required this.body,
  });

  final Key? cardKey;
  final _StatusTone tone;
  final String label;
  final String value;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.46),
        border: Border.all(
          color: _toneColor(colors, tone).withValues(alpha: 0.46),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLabel(
            tone: tone,
            text: _statusToneLabel(tone),
            accent: _toneColor(colors, tone),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: colors.title,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(color: colors.cardText, fontSize: 14)),
        ],
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.tone, required this.text});

  final _StatusTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _toneColor(colors, tone).withValues(alpha: 0.13),
        border: Border.all(
          color: _toneColor(colors, tone).withValues(alpha: 0.46),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: colors.cardText, height: 1.4)),
    );
  }
}

class _Subhead extends StatelessWidget {
  const _Subhead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: colors.cardTitle,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InputCopy {
  const _InputCopy({
    required this.kicker,
    required this.title,
    required this.body,
    required this.pasteTitle,
    this.pasteBody,
  });

  final String kicker;
  final String title;
  final String body;
  final String pasteTitle;
  final String? pasteBody;

  static _InputCopy forMode(_InputMode mode, TTestKind kind) {
    return switch (mode) {
      _InputMode.paste => const _InputCopy(
        kicker: 'Input',
        title: 'Paste your t-test output.',
        body: 'Paste SPSS, R, JASP, jamovi, Excel ToolPak, or APA output.',
        pasteTitle: 'Paste output',
        pasteBody: null,
      ),
      _InputMode.example => const _InputCopy(
        kicker: 'Input',
        title: 'Example loaded.',
        body: 'Review the detected values before reporting.',
        pasteTitle: 'Example output',
        pasteBody: null,
      ),
      _InputMode.manual => _InputCopy(
        kicker: 'Input',
        title: 'Type values from your t-test.',
        body: 'Type values from one output row.',
        pasteTitle: 'Paste output',
        pasteBody: null,
      ),
    };
  }
}

class _RelationPrefix {
  const _RelationPrefix(this.prefix, this.relation);

  final String prefix;
  final ReportedRelation relation;
}

class _RqColors extends ThemeExtension<_RqColors> {
  const _RqColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceSolid,
    required this.surfaceStrong,
    required this.text,
    required this.title,
    required this.cardTitle,
    required this.cardText,
    required this.muted,
    required this.mutedSoft,
    required this.line,
    required this.lineStrong,
    required this.fieldBackground,
    required this.fieldText,
    required this.shadow,
    required this.cyan,
    required this.violet,
    required this.green,
    required this.error,
    required this.warning,
    required this.buttonText,
    required this.chartGrid,
    required this.chartAxis,
    required this.chartFill,
    required this.washOpacity,
    required this.cardA,
    required this.cardB,
    required this.cardC,
    required this.cardD,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceSolid;
  final Color surfaceStrong;
  final Color text;
  final Color title;
  final Color cardTitle;
  final Color cardText;
  final Color muted;
  final Color mutedSoft;
  final Color line;
  final Color lineStrong;
  final Color fieldBackground;
  final Color fieldText;
  final Color shadow;
  final Color cyan;
  final Color violet;
  final Color green;
  final Color error;
  final Color warning;
  final Color buttonText;
  final Color chartGrid;
  final Color chartAxis;
  final Color chartFill;
  final double washOpacity;
  final Color cardA;
  final Color cardB;
  final Color cardC;
  final Color cardD;

  Color get accentPrimary => cyan;

  static _RqColors of(BuildContext context) {
    return Theme.of(context).extension<_RqColors>()!;
  }

  factory _RqColors.dark() {
    return _RqColors(
      isDark: true,
      background: const Color(0xFF0F172A),
      surface: const Color(0xFF1E293B),
      surfaceSolid: const Color(0xFF1E293B),
      surfaceStrong: const Color(0xFF162033),
      text: const Color(0xFFE5E7EB),
      title: Colors.white,
      cardTitle: Colors.white,
      cardText: Colors.white,
      muted: const Color(0xFFD6DEE9),
      mutedSoft: const Color(0xFF9AA6B2),
      line: Colors.white.withValues(alpha: 0.12),
      lineStrong: Colors.white.withValues(alpha: 0.22),
      fieldBackground: const Color(0xFF0F172A).withValues(alpha: 0.72),
      fieldText: Colors.white,
      shadow: Colors.black.withValues(alpha: 0.36),
      cyan: const Color(0xFF22D3EE),
      violet: const Color(0xFFA78BFA),
      green: const Color(0xFF34D399),
      error: const Color(0xFFFF6B6B),
      warning: const Color(0xFFFACC15),
      buttonText: const Color(0xFF0F172A),
      chartGrid: const Color(0xFFE5E7EB).withValues(alpha: 0.18),
      chartAxis: const Color(0xFFE5E7EB).withValues(alpha: 0.72),
      chartFill: const Color(0xFF22D3EE).withValues(alpha: 0.18),
      washOpacity: 0.08,
      cardA: const Color(0xFF19E6D6),
      cardB: const Color(0xFF2563EB),
      cardC: const Color(0xFFFACC15),
      cardD: const Color(0xFFE11D48),
    );
  }

  factory _RqColors.light() {
    return _RqColors(
      isDark: false,
      background: const Color(0xFFF7F8FC),
      surface: Colors.white,
      surfaceSolid: Colors.white,
      surfaceStrong: const Color(0xFFEEF2FF),
      text: const Color(0xFF142033),
      title: const Color(0xFF0F172A),
      cardTitle: const Color(0xFF0F172A),
      cardText: const Color(0xFF1E293B),
      muted: const Color(0xFF43546A),
      mutedSoft: const Color(0xFF5D6B80),
      line: const Color(0xFF0F172A).withValues(alpha: 0.12),
      lineStrong: const Color(0xFF0F172A).withValues(alpha: 0.22),
      fieldBackground: Colors.white.withValues(alpha: 0.92),
      fieldText: const Color(0xFF0F172A),
      shadow: const Color(0xFF0F172A).withValues(alpha: 0.13),
      cyan: const Color(0xFF077A86),
      violet: const Color(0xFF4338CA),
      green: const Color(0xFF047857),
      error: const Color(0xFFB42318),
      warning: const Color(0xFF9A6700),
      buttonText: Colors.white,
      chartGrid: const Color(0xFF0F172A).withValues(alpha: 0.14),
      chartAxis: const Color(0xFF0F172A).withValues(alpha: 0.66),
      chartFill: const Color(0xFF087F8C).withValues(alpha: 0.13),
      washOpacity: 0.055,
      cardA: const Color(0xFF0E8F94),
      cardB: const Color(0xFF1E40AF),
      cardC: const Color(0xFFA16207),
      cardD: const Color(0xFFBE123C),
    );
  }

  @override
  ThemeExtension<_RqColors> copyWith() => this;

  @override
  ThemeExtension<_RqColors> lerp(
    covariant ThemeExtension<_RqColors>? other,
    double t,
  ) {
    if (other is! _RqColors) {
      return this;
    }
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return _RqColors(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceSolid: c(surfaceSolid, other.surfaceSolid),
      surfaceStrong: c(surfaceStrong, other.surfaceStrong),
      text: c(text, other.text),
      title: c(title, other.title),
      cardTitle: c(cardTitle, other.cardTitle),
      cardText: c(cardText, other.cardText),
      muted: c(muted, other.muted),
      mutedSoft: c(mutedSoft, other.mutedSoft),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      fieldBackground: c(fieldBackground, other.fieldBackground),
      fieldText: c(fieldText, other.fieldText),
      shadow: c(shadow, other.shadow),
      cyan: c(cyan, other.cyan),
      violet: c(violet, other.violet),
      green: c(green, other.green),
      error: c(error, other.error),
      warning: c(warning, other.warning),
      buttonText: c(buttonText, other.buttonText),
      chartGrid: c(chartGrid, other.chartGrid),
      chartAxis: c(chartAxis, other.chartAxis),
      chartFill: c(chartFill, other.chartFill),
      washOpacity: lerpDouble(washOpacity, other.washOpacity, t),
      cardA: c(cardA, other.cardA),
      cardB: c(cardB, other.cardB),
      cardC: c(cardC, other.cardC),
      cardD: c(cardD, other.cardD),
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

Color _toneColor(_RqColors colors, _StatusTone tone) {
  return switch (tone) {
    _StatusTone.accepted => colors.green,
    _StatusTone.warning => colors.warning,
    _StatusTone.error => colors.error,
  };
}

String _statusToneLabel(_StatusTone tone) {
  return switch (tone) {
    _StatusTone.accepted => 'OK',
    _StatusTone.warning => 'Warning',
    _StatusTone.error => 'Error',
  };
}

_StatusTone _toneForCheck(ValidationStatus status) {
  return switch (status) {
    ValidationStatus.pass => _StatusTone.accepted,
    ValidationStatus.fail => _StatusTone.error,
    ValidationStatus.notApplicable => _StatusTone.warning,
  };
}

String _statusLabel(ValidationStatus status) {
  return switch (status) {
    ValidationStatus.pass => 'OK',
    ValidationStatus.fail => 'Fail',
    ValidationStatus.notApplicable => 'Not applicable',
  };
}

String _kindLabel(TTestKind kind) {
  return switch (kind) {
    TTestKind.independentStudent => 'Equal variances assumed',
    TTestKind.independentWelch => 'Equal variances not assumed',
    TTestKind.pairedSamples => 'Paired samples',
    TTestKind.oneSample => 'One sample',
  };
}

String _kindShortLabel(TTestKind kind) {
  return switch (kind) {
    TTestKind.independentStudent => 'Student t-test',
    TTestKind.independentWelch => 'Welch t-test',
    TTestKind.pairedSamples => 'paired t-test',
    TTestKind.oneSample => 'one-sample t-test',
  };
}

String _tailText(ReportTail tail) {
  return switch (tail) {
    ReportTail.twoTailed => 'two-tailed',
    ReportTail.less => 'lower-tail',
    ReportTail.greater => 'upper-tail',
  };
}

String _relationSymbol(ReportedRelation relation) {
  return switch (relation) {
    ReportedRelation.equalRounded => '=',
    ReportedRelation.lessThan => '<',
    ReportedRelation.lessThanOrEqual => '<=',
    ReportedRelation.greaterThan => '>',
    ReportedRelation.greaterThanOrEqual => '>=',
  };
}

String _fmt(double value) {
  final abs = value.abs();
  if (abs != 0 && abs < 0.001) {
    return value.toStringAsExponential(2);
  }
  if ((value - value.round()).abs() < 1e-10) {
    return value.round().toString();
  }
  return value.toStringAsFixed(abs >= 10 ? 2 : 3);
}
