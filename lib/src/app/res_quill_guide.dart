part of 'res_quill_app.dart';

const _themePreferenceKey = 'resquill.theme';
const _themePreferenceDark = 'dark';
const _themePreferenceLight = 'light';
const _guideSeenScreensPreferenceKey = 'resquill.guide.seenScreens';
const _guidePulseCycles = 3;
const _guidePulseDuration = Duration(milliseconds: 550);
const _guidePulseTotal = Duration(milliseconds: _guidePulseCycles * 550);
const _topControlsReservedExtent = 68.0;
const _guideBubbleDesktopDockExtent = 300.0;
const _guideBubbleMobileDockExtent = 250.0;

@visibleForTesting
const resQuillTopControlsReservedExtentForTesting = _topControlsReservedExtent;

@visibleForTesting
double resQuillGuideDockExtentForTesting(Size size) {
  return _guideBubbleDockExtentFor(size);
}

double _guideBubbleDockExtentFor(Size size) {
  return size.width <= 720
      ? _guideBubbleMobileDockExtent
      : _guideBubbleDesktopDockExtent;
}

enum _GuideSide { left, right, top, bottom }

extension _GuideScreenStorage on _Screen {
  String get guideStorageId {
    return switch (this) {
      _Screen.start => 'start',
      _Screen.selection => 'compare',
      _Screen.input => 'input',
      _Screen.validation => 'validation',
      _Screen.report => 'report',
    };
  }
}

class _GuideStep {
  const _GuideStep({
    required this.targetId,
    required this.side,
    required this.title,
    required this.body,
    this.items = const [],
  });

  final String targetId;
  final _GuideSide side;
  final String title;
  final String body;
  final List<String> items;
}

class _GuideSession {
  const _GuideSession({
    required this.screen,
    required this.index,
    this.singleTargetId,
  });

  final _Screen screen;
  final int index;
  final String? singleTargetId;

  _GuideSession copyWith({required int index}) {
    return _GuideSession(
      screen: screen,
      index: index,
      singleTargetId: singleTargetId,
    );
  }
}

class _GuideButtonConfig {
  const _GuideButtonConfig({required this.screen, required this.targetId});

  final _Screen screen;
  final String targetId;
}

const _guideStepsByScreen = <_Screen, List<_GuideStep>>{
  _Screen.start: [
    _GuideStep(
      targetId: 'paste_output',
      side: _GuideSide.right,
      title: 'Paste copied output',
      body:
          'Paste supported t-test output when copied. Then confirm detected values.',
    ),
    _GuideStep(
      targetId: 'manual_entry',
      side: _GuideSide.top,
      title: 'Enter values manually',
      body:
          'Type values yourself when paste is messy. Choose the t-test path first.',
    ),
    _GuideStep(
      targetId: 'try_example',
      side: _GuideSide.top,
      title: 'Try an example',
      body:
          'Open sample data for practice. Replace it before using your result.',
    ),
    _GuideStep(
      targetId: 'analysis_area_heading',
      side: _GuideSide.left,
      title: 'Analysis areas',
      body:
          'Pick the broad analysis area first. T-test paths live under Compare means.',
    ),
    _GuideStep(
      targetId: 'compare_area_card',
      side: _GuideSide.left,
      title: 'Active analysis area',
      body:
          'Use this card for the current t-test prototype. Other methods are inactive.',
    ),
    _GuideStep(
      targetId: 'relationships_coming_later',
      side: _GuideSide.left,
      title: 'Coming later area',
      body:
          'This card is planned only. It does not accept correlation or regression.',
    ),
    _GuideStep(
      targetId: 'guide_replay',
      side: _GuideSide.bottom,
      title: 'Replay this guide',
      body: 'Replay help for this screen. It never changes your data.',
    ),
    _GuideStep(
      targetId: 'theme_toggle',
      side: _GuideSide.bottom,
      title: 'Theme switch',
      body: 'Change colors here. Your values stay the same.',
    ),
  ],
  _Screen.selection: [
    _GuideStep(
      targetId: 'student_test_path',
      side: _GuideSide.right,
      title: 'Independent samples - Student',
      body:
          'Choose this for unrelated groups with equal variances assumed. Do not use for paired scores.',
    ),
    _GuideStep(
      targetId: 'welch_test_path',
      side: _GuideSide.left,
      title: 'Independent samples - Welch',
      body:
          'Choose this for unrelated groups with unequal variances. Decimal df is expected.',
    ),
    _GuideStep(
      targetId: 'paired_test_path',
      side: _GuideSide.right,
      title: 'Paired samples',
      body:
          'Choose this for the same people twice, or matched pairs. Do not use for unrelated groups.',
    ),
    _GuideStep(
      targetId: 'one_sample_test_path',
      side: _GuideSide.left,
      title: 'One sample',
      body:
          'Choose this for one group against a fixed value. There is no second group.',
    ),
  ],
  _Screen.input: [
    _GuideStep(
      targetId: 'paste_panel',
      side: _GuideSide.right,
      title: 'Paste output card',
      body: 'Paste copied output here, then review detected values.',
      items: [
        'Keep row and column labels.',
        'Keep line breaks.',
        'Do not rewrite SPSS p = .000.',
      ],
    ),
    _GuideStep(
      targetId: 'structured_fields_panel',
      side: _GuideSide.left,
      title: 'Structured fields card',
      body: 'Use this card when paste fails or one value needs correction.',
      items: [
        'Test type: match the output row.',
        'Tail: use the assignment.',
        'Alpha: confirm before reporting.',
      ],
    ),
  ],
  _Screen.validation: [
    _GuideStep(
      targetId: 'validation_summary',
      side: _GuideSide.right,
      title: 'Parsed result card',
      body: 'Use this card to catch blocking mistakes before reporting.',
      items: [
        'Accepted: still check against output.',
        'Warning: wording changes.',
        'Error: fix before generating.',
      ],
    ),
    _GuideStep(
      targetId: 'validation_decisions',
      side: _GuideSide.left,
      title: 'Decisions card',
      body: 'Use this card to see why fields were accepted or blocked.',
      items: [
        'Welch df can be decimal.',
        'SPSS .000 becomes p < .001.',
        'Alpha cannot be guessed.',
      ],
    ),
  ],
  _Screen.report: [
    _GuideStep(
      targetId: 'report_prose',
      side: _GuideSide.right,
      title: 'Report prose card',
      body: 'Use this card as the copy source after checking values.',
      items: [
        'Names match the output.',
        'p wording is not zero.',
        'No causality claims added.',
      ],
    ),
    _GuideStep(
      targetId: 'ci_chart_panel',
      side: _GuideSide.left,
      title: 'Confidence interval chart',
      body: 'Use this card to check direction and interval limits.',
      items: [
        'Above zero matches a positive difference.',
        'It supports wording, not new claims.',
      ],
    ),
    _GuideStep(
      targetId: 'distribution_panel',
      side: _GuideSide.left,
      title: 't distribution chart',
      body: 'Use this card as a visual check of t and df.',
      items: [
        'Observed t sits past critical t.',
        'The table keeps values readable.',
      ],
    ),
  ],
};

List<_GuideStep> _guideStepsFor(_Screen screen) {
  return _guideStepsByScreen[screen] ?? const [];
}

@visibleForTesting
Map<String, List<String>> resQuillGuideStepTargetsForTesting() {
  return {
    for (final entry in _guideStepsByScreen.entries)
      entry.key.guideStorageId: [for (final step in entry.value) step.targetId],
  };
}

enum _GuideProtectedRole { heading, interactive, primary }

class _GuideProtected extends StatelessWidget {
  const _GuideProtected({
    required this.role,
    required this.id,
    required this.child,
  });

  final _GuideProtectedRole role;
  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<String>(
        'guide-protected-${role.name}-${_guideProtectedId(id)}',
      ),
      child: child,
    );
  }
}

String _guideProtectedId(Object id) {
  final text = id is ValueKey<String> ? id.value : '$id';
  return text.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '_');
}

class _GuideTargetRegistry {
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  GlobalKey keyFor(String id) {
    return _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id));
  }

  BuildContext? contextFor(String id) {
    return _keys[id]?.currentContext;
  }
}

class _GuideScope extends InheritedWidget {
  const _GuideScope({
    required this.registry,
    required this.openCardGuide,
    required this.pulsingScreen,
    required this.pulseAnimation,
    required super.child,
  });

  final _GuideTargetRegistry registry;
  final void Function(_Screen screen, String targetId) openCardGuide;
  final _Screen? pulsingScreen;
  final Animation<double> pulseAnimation;

  static _GuideScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_GuideScope>();
    assert(scope != null, 'Guide scope is missing.');
    return scope!;
  }

  @override
  bool updateShouldNotify(_GuideScope oldWidget) {
    return registry != oldWidget.registry ||
        openCardGuide != oldWidget.openCardGuide ||
        pulsingScreen != oldWidget.pulsingScreen ||
        pulseAnimation != oldWidget.pulseAnimation;
  }
}

class _GuideTarget extends StatelessWidget {
  const _GuideTarget({required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _GuideScope.of(context).registry.keyFor(id),
      child: KeyedSubtree(key: ValueKey('guide-target-$id'), child: child),
    );
  }
}

class _CardGuideButton extends StatelessWidget {
  const _CardGuideButton({required this.screen, required this.targetId});

  final _Screen screen;
  final String targetId;

  @override
  Widget build(BuildContext context) {
    final scope = _GuideScope.of(context);
    return _GuideButtonSkin(
      key: Key('guide-button-$targetId'),
      isPulsing: scope.pulsingScreen == screen,
      reducedMotion: MediaQuery.disableAnimationsOf(context),
      animation: scope.pulseAnimation,
      onPressed: () => scope.openCardGuide(screen, targetId),
    );
  }
}

class _GuideButtonSkin extends StatelessWidget {
  const _GuideButtonSkin({
    super.key,
    required this.isPulsing,
    required this.reducedMotion,
    required this.animation,
    required this.onPressed,
  });

  final bool isPulsing;
  final bool reducedMotion;
  final Animation<double> animation;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final activePulse =
            isPulsing && (reducedMotion || animation.value >= 0.5);
        final background = activePulse
            ? (colors.isDark ? colors.cyan : colors.violet)
            : (colors.isDark ? const Color(0xFF111827) : Colors.white);
        final foreground = activePulse
            ? (colors.isDark ? colors.buttonText : Colors.white)
            : colors.title;
        final border = activePulse
            ? (colors.isDark ? Colors.white : colors.cyan)
            : colors.cyan;
        return _GuideProtected(
          role: _GuideProtectedRole.interactive,
          id: key ?? 'guide-button',
          child: TextButton(
            onPressed: onPressed,
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(const Size(52, 30)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              backgroundColor: WidgetStateProperty.all(background),
              foregroundColor: WidgetStateProperty.all(foreground),
              side: WidgetStateProperty.all(
                BorderSide(color: border, width: activePulse ? 2 : 1),
              ),
              textStyle: WidgetStateProperty.all(
                const TextStyle(
                  fontFamily: 'Segoe UI',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            child: const Text('GUIDE'),
          ),
        );
      },
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.isLight,
    required this.onReplayGuide,
    required this.onToggleTheme,
    required this.onSettings,
  });

  final bool isLight;
  final VoidCallback onReplayGuide;
  final VoidCallback onToggleTheme;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          _GuideTarget(
            id: 'guide_replay',
            child: _ActionButton(
              key: const Key('guide-replay'),
              label: 'GUIDE',
              tone: _ButtonTone.secondary,
              onPressed: onReplayGuide,
            ),
          ),
          _GuideTarget(
            id: 'theme_toggle',
            child: _ThemeToggle(isLight: isLight, onPressed: onToggleTheme),
          ),
          _ActionButton(
            key: const Key('open-settings'),
            label: 'SETTINGS',
            tone: _ButtonTone.secondary,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({
    required this.isLight,
    required this.onReplayGuide,
    required this.onResetSeen,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onReplayGuide;
  final VoidCallback onResetSeen;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return AlertDialog(
      backgroundColor: colors.surfaceSolid,
      title: Text('Settings', style: TextStyle(color: colors.title)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionButton(
              key: const Key('settings-replay-guide'),
              label: 'Replay guide',
              tone: _ButtonTone.primary,
              onPressed: onReplayGuide,
            ),
            const SizedBox(height: 12),
            _ActionButton(
              key: const Key('settings-reset-guide'),
              label: 'Reset guide seen state',
              tone: _ButtonTone.secondary,
              onPressed: onResetSeen,
            ),
            const SizedBox(height: 12),
            _ActionButton(
              key: const Key('settings-theme-toggle'),
              label: isLight ? 'DARK VIEW' : 'BRIGHT VIEW',
              tone: _ButtonTone.secondary,
              onPressed: onToggleTheme,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _GuideOverlay extends StatefulWidget {
  const _GuideOverlay({
    required this.registry,
    required this.session,
    required this.reservedBottom,
    required this.onBack,
    required this.onNext,
    required this.onClose,
  });

  final _GuideTargetRegistry registry;
  final _GuideSession? session;
  final double reservedBottom;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay> {
  final FocusScopeNode _focusScopeNode = FocusScopeNode(
    debugLabel: 'Guide overlay focus scope',
  );

  Rect? _targetRect;
  _GuideSession? _lastMeasuredSession;

  @override
  void initState() {
    super.initState();
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(covariant _GuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session == null) {
      _targetRect = null;
      _lastMeasuredSession = null;
      _focusScopeNode.unfocus();
      return;
    }
    if (!_sameSession(widget.session, oldWidget.session)) {
      _targetRect = null;
      _scheduleMeasurement();
      _requestGuideFocus();
    }
  }

  @override
  void dispose() {
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMeasurement();
  }

  void _scheduleMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _measureTarget(scrollFirst: true);
      }
    });
  }

  void _requestGuideFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.session != null) {
        _focusScopeNode.requestFocus();
      }
    });
  }

  void _measureTarget({required bool scrollFirst}) {
    final session = widget.session;
    if (session == null) {
      return;
    }
    final step = _stepForSession(session);
    final targetContext = widget.registry.contextFor(step.targetId);
    if (targetContext == null) {
      return;
    }
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final viewportSize = MediaQuery.sizeOf(context);
    final mobile = viewportSize.width <= 720;
    final overlayBox = context.findRenderObject();
    final targetBox = targetContext.findRenderObject();
    if (overlayBox is! RenderBox || targetBox is! RenderBox) {
      return;
    }
    final origin = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final rawRect = origin & targetBox.size;
    final clipToContent =
        step.targetId != 'guide_replay' && step.targetId != 'theme_toggle';
    if (scrollFirst && !_sameSession(_lastMeasuredSession, session)) {
      final visibleBounds = _guideVisibleBounds(
        overlayBox.size,
        mobile,
        widget.reservedBottom,
        clipToContent: clipToContent,
      );
      final targetIsVisible = _targetHasUsableVisibleArea(
        rawRect,
        visibleBounds,
        mobile,
      );
      if (targetIsVisible) {
        _measureTarget(scrollFirst: false);
        return;
      }
      final targetAboveViewport = rawRect.top < visibleBounds.top;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: targetAboveViewport ? 0.0 : 1.0,
          alignmentPolicy: targetAboveViewport
              ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
              : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
      unawaited(
        Future<void>.delayed(
          reducedMotion ? Duration.zero : const Duration(milliseconds: 280),
        ).then((_) {
          if (mounted && _sameSession(session, widget.session)) {
            _measureTarget(scrollFirst: false);
          }
        }),
      );
      return;
    }
    if (!_sameSession(session, widget.session)) {
      return;
    }
    final nextRect = _expandedGuideRect(
      rawRect,
      overlayBox.size,
      mobile,
      widget.reservedBottom,
      clipToContent: clipToContent,
    );
    setState(() {
      _targetRect = nextRect;
      _lastMeasuredSession = session;
    });
  }

  bool _targetHasUsableVisibleArea(
    Rect rawRect,
    Rect visibleBounds,
    bool mobile,
  ) {
    if (!rawRect.overlaps(visibleBounds)) {
      return false;
    }
    if (rawRect.top < visibleBounds.top - 0.5) {
      return false;
    }
    final visibleTop = math.max(rawRect.top, visibleBounds.top);
    final visibleBottom = math.min(rawRect.bottom, visibleBounds.bottom);
    final visibleHeight = math.max(0.0, visibleBottom - visibleTop);
    final neededHeight = math.min(rawRect.height, mobile ? 72.0 : 96.0);
    return visibleHeight >= neededHeight;
  }

  _GuideStep _stepForSession(_GuideSession session) {
    return _guideStepsFor(session.screen)[session.index];
  }

  bool _sameSession(_GuideSession? a, _GuideSession? b) {
    return a?.screen == b?.screen &&
        a?.index == b?.index &&
        a?.singleTargetId == b?.singleTargetId;
  }

  Rect _expandedGuideRect(
    Rect rawRect,
    Size overlaySize,
    bool mobile,
    double reservedBottom, {
    required bool clipToContent,
  }) {
    final pad = mobile ? 10.0 : 14.0;
    final visibleBounds = _guideVisibleBounds(
      overlaySize,
      mobile,
      reservedBottom,
      clipToContent: clipToContent,
    );
    var rect = rawRect;
    if (clipToContent && rect.overlaps(visibleBounds)) {
      rect = rect.intersect(visibleBounds);
    }
    if (rect.height > visibleBounds.height * 0.56) {
      final headerHeight = math.min(
        220.0,
        math.max(120.0, visibleBounds.height * 0.26),
      );
      rect = Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.right,
        math.min(rect.bottom, rect.top + headerHeight),
      );
    }
    final width = math.min(
      math.max(rect.width + pad * 2, 58.0),
      math.max(58.0, visibleBounds.width),
    );
    final height = math.min(
      math.max(rect.height + pad * 2, 54.0),
      math.max(54.0, visibleBounds.height),
    );
    final left = (rect.center.dx - width / 2)
        .clamp(
          visibleBounds.left,
          math.max(visibleBounds.left, visibleBounds.right - width),
        )
        .toDouble();
    final top = (rect.center.dy - height / 2)
        .clamp(
          visibleBounds.top,
          math.max(visibleBounds.top, visibleBounds.bottom - height),
        )
        .toDouble();
    return Rect.fromLTWH(left, top, width, height);
  }

  Rect _guideVisibleBounds(
    Size overlaySize,
    bool mobile,
    double reservedBottom, {
    required bool clipToContent,
  }) {
    final edge = mobile ? 8.0 : 10.0;
    final contentBottom = math.max(
      _topControlsReservedExtent + edge + 54,
      overlaySize.height - reservedBottom - edge,
    );
    return Rect.fromLTRB(
      edge,
      clipToContent ? _topControlsReservedExtent + edge : edge,
      overlaySize.width - edge,
      contentBottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session == null) {
      return const SizedBox.shrink();
    }
    final step = _stepForSession(session);
    final rect = _targetRect;
    final colors = _RqColors.of(context);
    return Positioned.fill(
      child: FocusScope(
        node: _focusScopeNode,
        autofocus: true,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              _GuideScrim(targetRect: rect, onTap: widget.onClose),
              if (rect != null) ...[
                Positioned.fromRect(
                  key: const Key('guide-highlight'),
                  rect: rect,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.cyan, width: 3),
                        borderRadius: BorderRadius.circular(14),
                        color: colors.cyan.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ],
              CustomSingleChildLayout(
                delegate: _GuideBubblePositionDelegate(
                  targetRect: rect,
                  side: step.side,
                  preferAbove: session.screen != _Screen.start,
                  reservedBottom: widget.reservedBottom,
                ),
                child: _GuideBubble(
                  step: step,
                  index: session.index,
                  total: _guideStepsFor(session.screen).length,
                  singleItemMode: session.singleTargetId != null,
                  onBack: widget.onBack,
                  onNext: widget.onNext,
                  onClose: widget.onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideScrim extends StatelessWidget {
  const _GuideScrim({required this.targetRect, required this.onTap});

  final Rect? targetRect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0x7A000000);
    final rect = targetRect;
    if (rect == null) {
      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const ColoredBox(color: color),
        ),
      );
    }
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final left = rect.left.clamp(0.0, width).toDouble();
          final top = rect.top.clamp(0.0, height).toDouble();
          final right = rect.right.clamp(0.0, width).toDouble();
          final bottom = rect.bottom.clamp(0.0, height).toDouble();
          Widget segment(double x, double y, double w, double h) {
            if (w <= 0 || h <= 0) {
              return const SizedBox.shrink();
            }
            return Positioned(
              left: x,
              top: y,
              width: w,
              height: h,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: const ColoredBox(color: color),
              ),
            );
          }

          return Stack(
            children: [
              segment(0, 0, width, top),
              segment(right, top, width - right, bottom - top),
              segment(0, bottom, width, height - bottom),
              segment(0, top, left, bottom - top),
              Positioned.fromRect(
                rect: Rect.fromLTRB(left, top, right, bottom),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: onTap,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideBubblePositionDelegate extends SingleChildLayoutDelegate {
  const _GuideBubblePositionDelegate({
    required this.targetRect,
    required this.side,
    required this.preferAbove,
    required this.reservedBottom,
  });

  final Rect? targetRect;
  final _GuideSide side;
  final bool preferAbove;
  final double reservedBottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    const margin = 14.0;
    const gap = 26.0;
    const preferredMinWidth = 300.0;
    var maxWidth = math.min(520.0, constraints.maxWidth - margin * 2);
    final docked = reservedBottom > 0;
    final maxHeight = docked
        ? math.max(120.0, reservedBottom)
        : math.max(120.0, constraints.maxHeight - margin * 2);
    if (docked && constraints.maxWidth <= 720) {
      maxWidth = math.max(220.0, constraints.maxWidth - margin * 2);
    }
    final rect = targetRect;
    if (!docked && rect != null && constraints.maxWidth > 720) {
      final leftSpace = rect.left - gap - margin;
      final rightSpace = constraints.maxWidth - rect.right - gap - margin;
      final requestedSpace = switch (side) {
        _GuideSide.left => leftSpace,
        _GuideSide.right => rightSpace,
        _GuideSide.top || _GuideSide.bottom => maxWidth,
      };
      if (requestedSpace >= preferredMinWidth) {
        maxWidth = math.min(maxWidth, requestedSpace);
      } else {
        final availableSideSpace = math.max(leftSpace, rightSpace);
        if (availableSideSpace >= preferredMinWidth) {
          maxWidth = math.min(maxWidth, availableSideSpace);
        }
      }
    }
    maxWidth = math.max(220.0, maxWidth);
    return BoxConstraints(
      minWidth: math.min(preferredMinWidth, maxWidth),
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const gap = 26.0;
    const margin = 14.0;
    final rect = targetRect;
    if (rect == null) {
      return Offset(
        (size.width - childSize.width) / 2,
        (size.height - childSize.height) / 2,
      );
    }

    if (reservedBottom > 0) {
      final dockTop = size.height - reservedBottom;
      final left = ((size.width - childSize.width) / 2)
          .clamp(
            margin,
            math.max(margin, size.width - childSize.width - margin),
          )
          .toDouble();
      final top = (dockTop + (reservedBottom - childSize.height) / 2)
          .clamp(dockTop, math.max(dockTop, size.height - childSize.height))
          .toDouble();
      return Offset(left, top);
    }

    Offset placed(_GuideSide requestedSide) {
      return switch (requestedSide) {
        _GuideSide.left => Offset(
          rect.left - childSize.width - gap,
          rect.center.dy - childSize.height / 2,
        ),
        _GuideSide.right => Offset(
          rect.right + gap,
          rect.center.dy - childSize.height / 2,
        ),
        _GuideSide.top => Offset(
          rect.center.dx - childSize.width / 2,
          rect.top - childSize.height - gap,
        ),
        _GuideSide.bottom => Offset(
          rect.center.dx - childSize.width / 2,
          rect.bottom + gap,
        ),
      };
    }

    if (size.width <= 720) {
      final above = Offset(margin, rect.top - childSize.height - gap);
      final below = Offset(margin, rect.bottom + gap);
      var top = preferAbove && above.dy >= margin ? above.dy : below.dy;
      if (top + childSize.height > size.height - margin && above.dy >= margin) {
        top = above.dy;
      }
      if (top + childSize.height > size.height - margin) {
        top = size.height - childSize.height - margin;
      }
      if (top < margin) {
        top = margin;
      }
      return Offset(margin, top);
    }

    var offset = placed(side);
    if (offset.dx < margin ||
        offset.dx + childSize.width > size.width - margin) {
      offset = rect.left > size.width / 2
          ? placed(_GuideSide.left)
          : placed(_GuideSide.right);
    }
    if (offset.dx < margin ||
        offset.dx + childSize.width > size.width - margin) {
      offset = placed(_GuideSide.bottom);
    }

    final left = offset.dx
        .clamp(margin, size.width - childSize.width - margin)
        .toDouble();
    final top = offset.dy
        .clamp(margin, size.height - childSize.height - margin)
        .toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _GuideBubblePositionDelegate oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        side != oldDelegate.side ||
        preferAbove != oldDelegate.preferAbove ||
        reservedBottom != oldDelegate.reservedBottom;
  }
}

class _GuideBubble extends StatelessWidget {
  const _GuideBubble({
    required this.step,
    required this.index,
    required this.total,
    required this.singleItemMode,
    required this.onBack,
    required this.onNext,
    required this.onClose,
  });

  final _GuideStep step;
  final int index;
  final int total;
  final bool singleItemMode;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    return Container(
      key: const Key('guide-bubble'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF111827) : Colors.white,
        border: Border.all(color: colors.cyan, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              step.title,
                              key: const Key('guide-title'),
                              style: TextStyle(
                                color: colors.title,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            singleItemMode
                                ? 'Card guide'
                                : '${index + 1} of $total',
                            key: const Key('guide-count'),
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        step.body,
                        key: const Key('guide-body'),
                        style: TextStyle(
                          color: colors.cardText,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      if (step.items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final item in step.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '- $item',
                              style: TextStyle(
                                color: colors.cardText,
                                fontSize: 14.2,
                                height: 1.32,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  _GuideControlButton(
                    key: const Key('guide-skip'),
                    label: 'SKIP',
                    onPressed: onClose,
                  ),
                  if (!singleItemMode)
                    _GuideControlButton(
                      key: const Key('guide-back'),
                      label: 'BACK',
                      onPressed: index == 0 ? null : onBack,
                    ),
                  if (!singleItemMode)
                    _GuideControlButton(
                      key: const Key('guide-next'),
                      label: 'NEXT TIP',
                      primary: true,
                      onPressed: onNext,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideControlButton extends StatelessWidget {
  const _GuideControlButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = _RqColors.of(context);
    final enabled = onPressed != null;
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(0, 38)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        backgroundColor: WidgetStateProperty.all(
          primary && enabled ? colors.cyan : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.all(
          !enabled
              ? colors.mutedSoft
              : primary
              ? colors.buttonText
              : colors.title,
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: enabled ? colors.lineStrong : colors.line),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Text(label),
    );
  }
}
