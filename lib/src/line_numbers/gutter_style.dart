
import 'package:flutter/material.dart';

class GutterStyle {
  /// Width of the line number column.
  final double width;

  /// Alignment of the numbers in the column.
  final TextAlign textAlign;

  /// Style of the numbers.
  final TextStyle? textStyle;

  /// Style of the error popup.
  final TextStyle? errorPopupTextStyle;

  /// Background of the line number column.
  final Color? background;

  /// Horizontal margin between the gutter and code.
  final double margin;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Whether to show errors.
  final bool showErrors;

  /// Whether to show folding handles.
  final bool showFoldingHandles;

  bool get showGutter =>
      showLineNumbers || showErrors || showFoldingHandles;

  const GutterStyle({
    this.margin = 0.0,
    this.textAlign = TextAlign.right,
    this.showErrors = true,
    this.showFoldingHandles = true,
    this.showLineNumbers = true,
    this.width = 80.0,
    this.background,
    this.errorPopupTextStyle,
    this.textStyle,
  });

  static const GutterStyle none = GutterStyle(
    showErrors: false,
    showFoldingHandles: false,
    showLineNumbers: false,
  );

  GutterStyle copyWith({
    TextStyle? errorPopupTextStyle,
    TextStyle? textStyle,
    Color? background,
    double? margin,
    double? width,
    TextAlign? textAlign,
  }) =>
      GutterStyle(
        width: width ?? this.width,
        textAlign: textAlign ?? this.textAlign,
        textStyle: textStyle ?? this.textStyle,
        errorPopupTextStyle:
            errorPopupTextStyle ?? this.errorPopupTextStyle,
        background: background ?? this.background,
        margin: margin ?? this.margin,
        showErrors: showErrors,
        showFoldingHandles: showFoldingHandles,
        showLineNumbers: showLineNumbers,
      );
}

@Deprecated('Renamed to GutterStyle')
typedef LineNumberStyle = GutterStyle;
