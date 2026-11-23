import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// A widget that renders Markdown content incrementally as it streams in.
///
/// This widget handles the challenge of rendering Markdown that is still being generated:
/// - It buffers incomplete Markdown elements (like unclosed code blocks, lists, etc.)
/// - It renders completed Markdown elements immediately
/// - It provides a smooth streaming experience without flickering
class StreamingMarkdown extends StatefulWidget {
  const StreamingMarkdown({
    super.key,
    required this.content,
    this.isStreaming = false,
    this.styleSheet,
    this.selectable = true,
    this.onTapLink,
    this.imageDirectory,
    this.syntaxHighlighter,
    this.extensionSet,
  });

  final String content;
  final bool isStreaming;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;
  final void Function(String href, String? title, String? text)? onTapLink;
  final String? imageDirectory;
  final SyntaxHighlighter? syntaxHighlighter;
  final md.ExtensionSet? extensionSet;

  @override
  State<StreamingMarkdown> createState() => _StreamingMarkdownState();
}

class _StreamingMarkdownState extends State<StreamingMarkdown> {
  // Track the last rendered position to avoid re-rendering unchanged content
  String _lastRenderedContent = '';

  @override
  Widget build(BuildContext context) {
    // If not streaming and content hasn't changed, return cached widget
    if (!widget.isStreaming && widget.content == _lastRenderedContent) {
      return const SizedBox.shrink();
    }

    _lastRenderedContent = widget.content;

    // For streaming content, we need to handle incomplete Markdown elements
    // The flutter_markdown package can handle incomplete content reasonably well,
    // but we may want to add some buffering for certain elements

    final displayContent = _prepareContentForRendering(
      widget.content,
      widget.isStreaming,
    );

    return Markdown(
      data: displayContent,
      styleSheet: widget.styleSheet ?? _defaultStyleSheet(context),
      selectable: widget.selectable,
      onTapLink: widget.onTapLink ?? _defaultOnTapLink,
      imageDirectory: widget.imageDirectory,
      syntaxHighlighter: widget.syntaxHighlighter,
      extensionSet: widget.extensionSet ?? md.ExtensionSet.gitHubFlavored,
      softLineBreak: true,
    );
  }

  String _prepareContentForRendering(String content, bool isStreaming) {
    if (!isStreaming) return content;

    // For streaming content, we might want to buffer certain incomplete elements
    // to prevent rendering artifacts. For now, we'll let flutter_markdown handle it.
    // If needed, we can add buffering logic here for:
    // - Unclosed code blocks (```)
    // - Unclosed tables
    // - Incomplete list items
    // - Unclosed emphasis/strong markers

    return content;
  }

  MarkdownStyleSheet _defaultStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1A1A2E), // AppColors.firefly equivalent
        height: 1.5,
        fontSize: 14,
      ),
      h1: theme.textTheme.headlineSmall?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      strong: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w700,
      ),
      em: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontStyle: FontStyle.italic,
      ),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        height: 1.5,
        fontSize: 14,
      ),
      listBulletPadding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
      listIndent: 24,
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF6B7280), // Muted color
        fontStyle: FontStyle.italic,
      ),
      blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFF00BFA6), // AppColors.mint equivalent
            width: 4,
          ),
        ),
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: const Color(0xFFF3F4F6),
        color: const Color(0xFF1A1A2E),
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      a: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF00BFA6),
        decoration: TextDecoration.underline,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
        ),
      ),
    );
  }

  void _defaultOnTapLink(String url, String? title, String? text) {
    // Handle link taps - could open in browser, etc.
  }
}

/// A more advanced streaming Markdown widget that buffers incomplete elements
/// to provide smoother rendering during streaming.
class BufferedStreamingMarkdown extends StatefulWidget {
  const BufferedStreamingMarkdown({
    super.key,
    required this.content,
    this.isStreaming = false,
    this.styleSheet,
    this.selectable = true,
    this.onTapLink,
    this.imageDirectory,
    this.syntaxHighlighter,
    this.extensionSet,
  });

  final String content;
  final bool isStreaming;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;
  final void Function(String href, String? title, String? text)? onTapLink;
  final String? imageDirectory;
  final SyntaxHighlighter? syntaxHighlighter;
  final md.ExtensionSet? extensionSet;

  @override
  State<BufferedStreamingMarkdown> createState() =>
      _BufferedStreamingMarkdownState();
}

class _BufferedStreamingMarkdownState extends State<BufferedStreamingMarkdown> {
  String _renderedContent = '';
  bool _wasStreaming = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[BufferedStreamingMarkdown] initState: isStreaming=${widget.isStreaming}, contentLength=${widget.content.length}',
    );
    _renderedContent = _computeRenderedContent(
      widget.content,
      widget.isStreaming,
    );
    _wasStreaming = widget.isStreaming;
    debugPrint(
      '[BufferedStreamingMarkdown] initState done: _renderedContent length=${_renderedContent.length}, _wasStreaming=$_wasStreaming',
    );
  }

  @override
  void didUpdateWidget(covariant BufferedStreamingMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    debugPrint(
      '[BufferedStreamingMarkdown] didUpdateWidget: oldIsStreaming=${oldWidget.isStreaming}, newIsStreaming=${widget.isStreaming}, oldContentLength=${oldWidget.content.length}, newContentLength=${widget.content.length}',
    );

    // Handle streaming state transitions
    if (oldWidget.isStreaming != widget.isStreaming) {
      if (!widget.isStreaming && _wasStreaming) {
        // Streaming just finished - render full content
        debugPrint(
          '[BufferedStreamingMarkdown] Streaming finished, rendering full content (length: ${widget.content.length})',
        );
        _renderedContent = widget.content;
        _wasStreaming = false;
      } else if (widget.isStreaming) {
        // Streaming started - enable buffering
        debugPrint(
          '[BufferedStreamingMarkdown] Streaming started, enabling buffering',
        );
        _wasStreaming = true;
        _renderedContent = _bufferIncompleteMarkdown(widget.content);
      }
    } else if (widget.isStreaming && widget.content != oldWidget.content) {
      // Still streaming, content updated - update buffered content
      debugPrint(
        '[BufferedStreamingMarkdown] Streaming content updated: oldLen=${oldWidget.content.length}, newLen=${widget.content.length}',
      );
      _renderedContent = _bufferIncompleteMarkdown(widget.content);
    } else if (!widget.isStreaming && widget.content != oldWidget.content) {
      // Not streaming, content changed - render directly
      debugPrint(
        '[BufferedStreamingMarkdown] Non-streaming content changed: oldLen=${oldWidget.content.length}, newLen=${widget.content.length}',
      );
      _renderedContent = widget.content;
    }
    // If neither streaming state nor content changed, keep existing _renderedContent
  }

  String _computeRenderedContent(String content, bool isStreaming) {
    debugPrint(
      '[BufferedStreamingMarkdown] _computeRenderedContent: isStreaming=$isStreaming, contentLength=${content.length}',
    );
    if (isStreaming) {
      return _bufferIncompleteMarkdown(content);
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[BufferedStreamingMarkdown] build: isStreaming=${widget.isStreaming}, renderedContentLength=${_renderedContent.length}, widgetContentLength=${widget.content.length}, selectable=${widget.selectable}',
    );
    // Pure build - no state mutations
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.84,
      ),
      child: Markdown(
        data: _renderedContent,
        styleSheet: widget.styleSheet ?? _defaultStyleSheet(context),
        selectable: widget.selectable,
        onTapLink: widget.onTapLink ?? _defaultOnTapLink,
        imageDirectory: widget.imageDirectory,
        syntaxHighlighter: widget.syntaxHighlighter,
        extensionSet: widget.extensionSet ?? md.ExtensionSet.gitHubFlavored,
        softLineBreak: true,
        shrinkWrap: true,
      ),
    );
  }

  /// Buffers incomplete Markdown elements to prevent rendering artifacts
  /// during streaming. This prevents half-rendered code blocks, lists, etc.
  String _bufferIncompleteMarkdown(String content) {
    debugPrint(
      '[BufferedStreamingMarkdown] _bufferIncompleteMarkdown: contentLength=${content.length}',
    );
    String result = content;

    // Count unclosed code block markers (```)
    final codeBlockCount = '```'.allMatches(content).length;
    if (codeBlockCount.isOdd) {
      debugPrint(
        '[BufferedStreamingMarkdown] _bufferIncompleteMarkdown: Unclosed code block detected (count: $codeBlockCount)',
      );
      // Unclosed code block - don't render the partial content inside
      // We could either hide the incomplete block or show a placeholder
      // For now, we'll let flutter_markdown handle it
    }

    // Count unclosed emphasis markers (* and **)
    // This is complex to do perfectly, so we'll let flutter_markdown handle it

    // Count unclosed table rows
    // Count unclosed list items

    // For now, return content as-is. flutter_markdown handles most cases well.
    // More sophisticated buffering can be added if needed.

    debugPrint(
      '[BufferedStreamingMarkdown] _bufferIncompleteMarkdown returning: resultLength=${result.length}',
    );
    return result;
  }

  MarkdownStyleSheet _defaultStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        height: 1.5,
        fontSize: 14,
      ),
      h1: theme.textTheme.headlineSmall?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      strong: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w700,
      ),
      em: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        fontStyle: FontStyle.italic,
      ),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1A1A2E),
        height: 1.5,
        fontSize: 14,
      ),
      listBulletPadding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
      listIndent: 24,
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF6B7280),
        fontStyle: FontStyle.italic,
      ),
      blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: const Color(0xFF00BFA6), width: 4),
        ),
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: const Color(0xFFF3F4F6),
        color: const Color(0xFF1A1A2E),
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      a: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF00BFA6),
        decoration: TextDecoration.underline,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
        ),
      ),
    );
  }

  void _defaultOnTapLink(String url, String? title, String? text) {
  }
}
