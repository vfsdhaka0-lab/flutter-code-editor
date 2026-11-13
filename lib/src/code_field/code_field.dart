
// Copyright (c) 2023.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../gutter/gutter.dart';
import '../line_numbers/gutter_style.dart';
import '../search/widget/search_widget.dart';
import '../sizes.dart';
import '../wip/autocomplete/popup.dart';
import 'actions/comment_uncomment.dart';
import 'actions/enter_key.dart';
import 'actions/indent.dart';
import 'actions/outdent.dart';
import 'actions/search.dart';
import 'actions/tab.dart';
import 'code_controller.dart';
import 'default_styles.dart';
import 'js_workarounds/js_workarounds.dart';

const double _codeRightPadding = 12.0;

final _shortcuts = <ShortcutActivator, Intent>{
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyC,
  ): CopySelectionTextIntent.copy,
  const SingleActivator(
    LogicalKeyboardKey.keyC,
    meta: true,
  ): CopySelectionTextIntent.copy,
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.insert,
  ): CopySelectionTextIntent.copy,

  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyX,
  ): const CopySelectionTextIntent.cut(
    SelectionChangedCause.keyboard,
  ),
  const SingleActivator(
    LogicalKeyboardKey.keyX,
    meta: true,
  ): const CopySelectionTextIntent.cut(
    SelectionChangedCause.keyboard,
  ),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.delete,
  ): const CopySelectionTextIntent.cut(
    SelectionChangedCause.keyboard,
  ),

  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const UndoTextIntent(
    SelectionChangedCause.keyboard,
  ),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    meta: true,
  ): const UndoTextIntent(
    SelectionChangedCause.keyboard,
  ),

  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(
    SelectionChangedCause.keyboard,
  ),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(
    SelectionChangedCause.keyboard,
  ),

  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const IndentIntent(),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.tab,
  ): const OutdentIntent(),

  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.slash,
  ): const CommentUncommentIntent(),
  const SingleActivator(
    LogicalKeyboardKey.slash,
    meta: true,
  ): const CommentUncommentIntent(),

  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyF,
  ): const SearchIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: true,
  ): const SearchIntent(),

  LogicalKeySet(
    LogicalKeyboardKey.escape,
  ): const DismissIntent(),

  LogicalKeySet(
    LogicalKeyboardKey.enter,
  ): const EnterKeyIntent(),

  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const TabKeyIntent(),
};

class CodeField extends StatefulWidget {
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final bool wrap;
  final CodeController controller;
  final UndoHistoryController? undoController;

  @Deprecated('Use gutterStyle instead')
  final GutterStyle lineNumberStyle;

  final Color? cursorColor;
  final TextStyle? textStyle;
  final SmartDashesType smartDashesType;
  final SmartQuotesType smartQuotesType;
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;
  final bool? enabled;
  final void Function(String)? onChanged;
  final bool readOnly;
  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;

  @Deprecated('Use gutterStyle instead')
  final bool? lineNumbers;

  final GutterStyle gutterStyle;

  const CodeField({
    super.key,
    required this.controller,
    this.undoController,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.smartDashesType = SmartDashesType.disabled,
    this.smartQuotesType = SmartQuotesType.disabled,
    this.padding = const EdgeInsets.only(
      right: _codeRightPadding,
    ),
    GutterStyle? gutterStyle,
    this.enabled,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    @Deprecated('Use gutterStyle instead') this.lineNumbers,
    @Deprecated('Use gutterStyle instead')
    this.lineNumberStyle = const GutterStyle(),
  })  : assert(
          gutterStyle == null || lineNumbers == null,
          'Can not provide gutterStyle and lineNumbers at the same time. '
              'Please use gutterStyle and provide necessary columns to show/hide',
        ),
        gutterStyle = gutterStyle ??
            ((lineNumbers == false)
                ? GutterStyle.none
                : lineNumberStyle);

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  ScrollController? _horizontalCodeScroll;

  final _codeFieldKey = GlobalKey();

  OverlayEntry? _suggestionsPopup;
  OverlayEntry? _searchPopup;

  Offset _normalPopupOffset = Offset.zero;
  Offset _flippedPopupOffset = Offset.zero;

  double painterWidth = 0;
  double painterHeight = 0;

  FocusNode? _focusNode;

  String? lines;
  String longestLine = '';

  Size? windowSize;

  late TextStyle textStyle;
  Color? _backgroundCol;

  final _editorKey = GlobalKey();
  Offset? _editorOffset;

  @override
  void initState() {
    super.initState();

    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    widget.controller.popupController.addListener(
      _onPopupStateChanged,
    );
    widget.controller.searchController.addListener(
      _onSearchControllerChange,
    );

    _horizontalCodeScroll = ScrollController();

    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.attach(context, onKeyEvent: _onKeyEvent);

    widget.controller.searchController.codeFieldFocusNode =
        _focusNode;

    disableSpellCheckIfWeb();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final fieldContext = _codeFieldKey.currentContext;
      if (fieldContext == null || fieldContext.size == null) {
        return;
      }

      windowSize = Size(
        fieldContext.size!.width,
        fieldContext.size!.height,
      );
    });

    _onTextChanged();
  }

  KeyEventResult _onKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.searchController.codeFieldFocusNode =
        null;

    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_updatePopupOffset);

    widget.controller.popupController.removeListener(
      _onPopupStateChanged,
    );

    widget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );

    _suggestionsPopup?.remove();
    _suggestionsPopup = null;

    _searchPopup?.remove();
    _searchPopup = null;

    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _horizontalCodeScroll?.dispose();

    if (widget.focusNode == null) {
      _focusNode?.dispose();
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeField oldWidget) {
    super.didUpdateWidget(oldWidget);

    oldWidget.controller.removeListener(_onTextChanged);
    oldWidget.controller.removeListener(_updatePopupOffset);

    oldWidget.controller.popupController.removeListener(
      _onPopupStateChanged,
    );

    oldWidget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );

    widget.controller.searchController.codeFieldFocusNode =
        _focusNode;

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);

    widget.controller.popupController.addListener(
      _onPopupStateChanged,
    );

    widget.controller.searchController.addListener(
      _onSearchControllerChange,
    );
  }

  void rebuild() {
    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final fieldContext = _codeFieldKey.currentContext;
        if (fieldContext == null || fieldContext.size == null) {
          return;
        }

        windowSize = Size(
          fieldContext.size!.width,
          fieldContext.size!.height,
        );
      });
    });
  }

  void _onTextChanged() {
    final str = widget.controller.text.split('\n');
    final buf = <String>[];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }

    longestLine = '';

    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) {
        longestLine = line;
      }
    });

    if (_codeScroll != null &&
        _editorKey.currentContext != null) {
      final box = _editorKey.currentContext!
          .findRenderObject() as RenderBox?;

      _editorOffset = box?.localToGlobal(Offset.zero);

      if (_editorOffset != null) {
        var fixedOffset = _editorOffset!;
        fixedOffset += Offset(0, _codeScroll!.offset);
        _editorOffset = fixedOffset;
      }
    }

    rebuild();
  }

  // Horizontal scrolling keeps only the configured right padding.
  // No left, top, or bottom padding is added.
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: minWidth,
            ),
            child: Text(
              longestLine,
              style: textStyle,
            ),
          ),
          widget.expands
              ? Expanded(child: codeField)
              : codeField,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        right: widget.padding.right,
      ),
      scrollDirection: Axis.horizontal,
      controller: _horizontalCodeScroll,
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const rootKey = 'root';

    final themeData = Theme.of(context);
    final styles = CodeTheme.of(context)?.styles;

    _backgroundCol = widget.background ??
        styles?[rootKey]?.backgroundColor ??
        DefaultStyles.backgroundColor;

    if (widget.decoration != null) {
      _backgroundCol = null;
    }

    final defaultTextStyle = TextStyle(
      color: styles?[rootKey]?.color ??
          DefaultStyles.textColor,
      fontSize: themeData.textTheme.titleMedium?.fontSize,
      height: themeData.textTheme.titleMedium?.height,
    );

    textStyle = defaultTextStyle.merge(widget.textStyle);

    final codeField = TextField(
      focusNode: _focusNode,

      // Prevent Flutter from adding automatic scroll padding.
      scrollPadding: EdgeInsets.zero,

      // Keep the code aligned at the top of the editing area.
      textAlignVertical: TextAlignVertical.top,

      style: textStyle,
      smartDashesType: widget.smartDashesType,
      smartQuotesType: widget.smartQuotesType,
      controller: widget.controller,
      undoController: widget.undoController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,

      decoration: const InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),

      cursorColor: widget.cursorColor ??
          defaultTextStyle.color,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
    );

    final editingField = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme,
      ),
      child: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          return _wrapInScrollView(
            codeField,
            textStyle,
            constraints.maxWidth,
          );
        },
      ),
    );

    return FocusableActionDetector(
      actions: widget.controller.actions,
      shortcuts: _shortcuts,
      child: Container(
        decoration: widget.decoration,
        color: _backgroundCol,
        key: _codeFieldKey,

        // No outer padding or margin.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.gutterStyle.showGutter)
              _buildGutter(),

            Expanded(
              key: _editorKey,
              child: editingField,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGutter() {
    final lineNumberSize = textStyle.fontSize;

    final lineNumberColor =
        widget.gutterStyle.textStyle?.color ??
            textStyle.color?.withOpacity(.5);

    // Match the gutter's line height to the code's line height.
    final lineNumberTextStyle =
        (widget.gutterStyle.textStyle ?? textStyle)
            .copyWith(
      color: lineNumberColor,
      fontFamily: textStyle.fontFamily,
      fontSize: lineNumberSize,
      height: textStyle.height,
    );

    final gutterStyle = widget.gutterStyle.copyWith(
      textStyle: lineNumberTextStyle,
      errorPopupTextStyle:
          widget.gutterStyle.errorPopupTextStyle ??
              CodeTheme.of(context)?.styles['root'] ??
              textStyle.copyWith(
                fontSize: DefaultStyles.errorPopupTextSize,
                backgroundColor: DefaultStyles.backgroundColor,
                fontStyle: DefaultStyles.fontStyle,
              ),
    );

    return GutterWidget(
      codeController: widget.controller,
      style: gutterStyle,
      scrollController: _numberScroll,

      // No padding around the gutter.
      padding: EdgeInsets.zero,
    );
  }

  void _updatePopupOffset() {
    final textPainter = _getTextPainter(
      widget.controller.text,
    );

    final caretHeight = _getCaretHeight(textPainter);

    final leftOffset = _getPopupLeftOffset(textPainter);

    final normalTopOffset = _getPopupTopOffset(
      textPainter,
      caretHeight,
    );

    final flippedTopOffset = normalTopOffset -
        (Sizes.autocompletePopupMaxHeight +
            caretHeight +
            Sizes.caretPadding);

    if (!mounted) return;

    setState(() {
      _normalPopupOffset = Offset(
        leftOffset,
        normalTopOffset,
      );

      _flippedPopupOffset = Offset(
        leftOffset,
        flippedTopOffset,
      );
    });
  }

  TextPainter _getTextPainter(String text) {
    return TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: textStyle,
      ),
    )..layout();
  }

  Offset _getCaretOffset(TextPainter textPainter) {
    return textPainter.getOffsetForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
  }

  double _getCaretHeight(TextPainter textPainter) {
    final double? caretFullHeight =
        textPainter.getFullHeightForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );

    return caretFullHeight ?? 0;
  }

  double _getPopupLeftOffset(TextPainter textPainter) {
    return max(
      _getCaretOffset(textPainter).dx -
          _horizontalCodeScroll!.offset +
          (_editorOffset?.dx ?? 0),
      0,
    );
  }

  double _getPopupTopOffset(
    TextPainter textPainter,
    double caretHeight,
  ) {
    return max(
      _getCaretOffset(textPainter).dy +
          caretHeight -
          _codeScroll!.offset +
          (_editorOffset?.dy ?? 0),
      0,
    );
  }

  void _onPopupStateChanged() {
    final shouldShow =
        widget.controller.popupController.shouldShow &&
            windowSize != null;

    if (!shouldShow) {
      _suggestionsPopup?.remove();
      _suggestionsPopup = null;
      return;
    }

    if (_suggestionsPopup == null) {
      _suggestionsPopup = _buildSuggestionOverlay();
      Overlay.of(context).insert(_suggestionsPopup!);
    }

    _suggestionsPopup!.markNeedsBuild();
  }

  void _onSearchControllerChange() {
    final shouldShow =
        widget.controller.searchController.shouldShow;

    if (!shouldShow) {
      _searchPopup?.remove();
      _searchPopup = null;
      return;
    }

    if (_searchPopup == null) {
      _searchPopup = _buildSearchOverlay();
      Overlay.of(context).insert(_searchPopup!);
    }
  }

  OverlayEntry _buildSearchOverlay() {
    final colorScheme = Theme.of(context).colorScheme;

    final borderColor =
        _getTextColorFromTheme() ??
            colorScheme.onBackground;

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(5),
              ),
            ),
            child: Material(
              child: SearchWidget(
                searchController:
                    widget.controller.searchController,
              ),
            ),
          ),
        );
      },
    );
  }

  Color? _getTextColorFromTheme() {
    final textTheme = Theme.of(context).textTheme;

    return textTheme.bodyLarge?.color ??
        textTheme.bodyMedium?.color ??
        textTheme.bodySmall?.color ??
        textTheme.displayLarge?.color ??
        textTheme.displayMedium?.color ??
        textTheme.displaySmall?.color ??
        textTheme.headlineLarge?.color ??
        textTheme.headlineMedium?.color ??
        textTheme.headlineSmall?.color ??
        textTheme.labelLarge?.color ??
        textTheme.labelMedium?.color ??
        textTheme.labelSmall?.color ??
        textTheme.titleLarge?.color ??
        textTheme.titleMedium?.color ??
        textTheme.titleSmall?.color;
  }

  OverlayEntry _buildSuggestionOverlay() {
    return OverlayEntry(
      builder: (context) {
        return Popup(
          normalOffset: _normalPopupOffset,
          flippedOffset: _flippedPopupOffset,
          controller: widget.controller.popupController,
          editingWindowSize: windowSize!,
          style: textStyle,
          backgroundColor: _backgroundCol,
          parentFocusNode: _focusNode!,
          editorOffset: _editorOffset,
        );
      },
    );
  }
}
