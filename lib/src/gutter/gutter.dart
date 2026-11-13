
 // TODO(alexeyinkin): Remove when dropping support for Flutter < 3.10,
// https://github.com/akvelon/flutter-code-editor/issues/245
// ignore_for_file: unnecessary_non_null_assertion

import 'package:flutter/material.dart';

import '../code_field/code_controller.dart';
import '../line_numbers/gutter_style.dart';
import 'error.dart';
import 'fold_toggle.dart';

const double _issueColumnWidth = 16.0;
const double _foldingColumnWidth = 16.0;

const int _lineNumberColumn = 0;
const int _issueColumn = 1;
const int _foldingColumn = 2;

class GutterWidget extends StatelessWidget {
  const GutterWidget({
    required this.codeController,
    required this.style,
    required this.scrollController,
    this.padding = EdgeInsets.zero,
  });

  final CodeController codeController;
  final GutterStyle style;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      child: AnimatedBuilder(
        animation: codeController,
        builder: (context, child) {
          return Container(
            width: style.showLineNumbers ? style.width : null,
            color: style.background,
            padding: EdgeInsets.zero,
            child: _buildOnChange(context, child),
          );
        },
      ),
    );
  }

  Widget _buildOnChange(BuildContext context, Widget? child) {
    final code = codeController.code;

    final issueColumnWidth =
        style.showErrors ? _issueColumnWidth : 0.0;

    final foldingColumnWidth =
        style.showFoldingHandles ? _foldingColumnWidth : 0.0;

    final lineNumberColumnWidth = style.showLineNumbers
        ? (style.width - issueColumnWidth - foldingColumnWidth)
            .clamp(0.0, style.width)
        : 0.0;

    final tableRows = List.generate(
      code.hiddenLineRanges.visibleLineNumbers.length,
      (i) => TableRow(
        children: const [
          SizedBox(),
          SizedBox(),
          SizedBox(),
        ],
      ),
    );

    _fillLineNumbers(tableRows);

    if (style.showErrors) {
      _fillIssues(tableRows);
    }

    if (style.showFoldingHandles) {
      _fillFoldToggles(tableRows);
    }

    return Container(
      width: style.showLineNumbers ? style.width : null,
      color: style.background,
      padding: EdgeInsets.zero,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: {
          _lineNumberColumn:
              FixedColumnWidth(lineNumberColumnWidth),
          _issueColumn:
              FixedColumnWidth(issueColumnWidth),
          _foldingColumn:
              FixedColumnWidth(foldingColumnWidth),
        },
        children: tableRows,
      ),
    );
  }

  void _fillLineNumbers(List<TableRow> tableRows) {
    final visibleLines =
        codeController.code.hiddenLineRanges.visibleLineNumbers;

    for (final line in visibleLines) {
      final rowIndex = _lineIndexToTableRowIndex(line);

      if (rowIndex == null || rowIndex >= tableRows.length) {
        continue;
      }

      tableRows[rowIndex].children![_lineNumberColumn] =
          Padding(
        padding: EdgeInsets.zero,
        child: Text(
          style.showLineNumbers ? '${line + 1}' : '',
          style: style.textStyle,
          textAlign: style.textAlign,
          maxLines: 1,
          softWrap: false,
        ),
      );
    }
  }

  void _fillIssues(List<TableRow> tableRows) {
    for (final issue in codeController.analysisResult.issues) {
      if (issue.line >= codeController.code.lines.length) {
        continue;
      }

      final rowIndex = _lineIndexToTableRowIndex(issue.line);

      if (rowIndex == null || rowIndex >= tableRows.length) {
        continue;
      }

      tableRows[rowIndex].children![_issueColumn] =
          GutterErrorWidget(
        issue,
        style.errorPopupTextStyle ??
            (throw Exception(
              'Error popup style should never be null',
            )),
      );
    }
  }

  void _fillFoldToggles(List<TableRow> tableRows) {
    final code = codeController.code;

    for (final block in code.foldableBlocks) {
      final rowIndex =
          _lineIndexToTableRowIndex(block.firstLine);

      if (rowIndex == null || rowIndex >= tableRows.length) {
        continue;
      }

      final isFolded = code.foldedBlocks.contains(block);

      tableRows[rowIndex].children![_foldingColumn] =
          FoldToggle(
        color: style.textStyle?.color,
        isFolded: isFolded,
        onTap: isFolded
            ? () => codeController.unfoldAt(block.firstLine)
            : () => codeController.foldAt(block.firstLine),
      );
    }

    for (final block in code.foldedBlocks) {
      final rowIndex =
          _lineIndexToTableRowIndex(block.firstLine);

      if (rowIndex == null || rowIndex >= tableRows.length) {
        continue;
      }

      tableRows[rowIndex].children![_foldingColumn] =
          FoldToggle(
        color: style.textStyle?.color,
        isFolded: true,
        onTap: () => codeController.unfoldAt(block.firstLine),
      );
    }
  }

  int? _lineIndexToTableRowIndex(int line) {
    return codeController.code.hiddenLineRanges
        .cutLineIndexIfVisible(line);
  }
}
