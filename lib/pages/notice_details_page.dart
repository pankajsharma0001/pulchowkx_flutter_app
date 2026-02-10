import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/models/notice.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/full_screen_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:async';

class NoticeDetailsPage extends StatefulWidget {
  final int noticeId;
  final Notice? initialNotice;

  const NoticeDetailsPage({
    super.key,
    required this.noticeId,
    this.initialNotice,
  });

  @override
  State<NoticeDetailsPage> createState() => _NoticeDetailsPageState();
}

class _NoticeDetailsPageState extends State<NoticeDetailsPage> {
  late Future<Notice?> _noticeFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.initialNotice != null) {
      _noticeFuture = Future.value(widget.initialNotice);
    } else {
      _noticeFuture = _apiService.getNotice(widget.noticeId);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _noticeFuture = _fetchNotice(forceRefresh: true);
    });
  }

  Future<Notice?> _fetchNotice({bool forceRefresh = false}) async {
    // We can add forceRefresh to getNotice if needed, but for now just call it
    // If we want force refresh, we might need to modify ApiService or just rely on background update
    // For now, standard getNotice is fine.
    return _apiService.getNotice(widget.noticeId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Details'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Notice?>(
        future: _noticeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text('Error loading notice', style: AppTextStyles.h4),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final notice = snapshot.data;
          if (notice == null) {
            return const Center(child: Text('Notice not found'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getSectionColor(notice).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: _getSectionColor(notice).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      (notice.category ?? 'General').toUpperCase().replaceAll(
                        '_',
                        ' ',
                      ),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _getSectionColor(notice),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  Text(
                    notice.title,
                    style: AppTextStyles.h3.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat(
                          'MMMM d, yyyy • h:mm a',
                        ).format(notice.createdAt),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Content
                  if (notice.content.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        notice.content,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Attachment
                  if (notice.attachmentUrl != null) ...[
                    Text(
                      'Attachment',
                      style: AppTextStyles.h4.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildAttachmentCard(context, notice, isDark),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getSectionColor(Notice notice) {
    return notice.section == NoticeSection.results
        ? AppColors.success
        : AppColors.info;
  }

  Widget _buildAttachmentCard(
    BuildContext context,
    Notice notice,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _openAttachment(context, notice),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                notice.attachmentType == NoticeAttachmentType.pdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.attachmentName ??
                        (notice.attachmentType == NoticeAttachmentType.pdf
                            ? 'Document.pdf'
                            : 'Image'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context, Notice notice) async {
    if (notice.attachmentUrl == null) return;

    haptics.lightImpact();

    // For images, show in-app fullscreen viewer
    if (notice.attachmentType == NoticeAttachmentType.image) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => FullScreenImageViewer(
            imageUrl: notice.attachmentUrl!,
            title: notice.title,
          ),
        ),
      );
      return;
    }

    // For PDFs, show in-app PDF viewer
    if (notice.attachmentType == NoticeAttachmentType.pdf) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => FullscreenPdfViewer(
            pdfUrl: notice.attachmentUrl!,
            title: notice.title,
          ),
        ),
      );
      return;
    }

    // For other files, open externally
    final uri = Uri.tryParse(notice.attachmentUrl!);
    if (uri == null) return;

    final messenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open attachment')),
      );
    }
  }
}

/// Fullscreen PDF viewer with support for remote URLs
/// Valid to duplicate here since the one in notices.dart is private
class FullscreenPdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const FullscreenPdfViewer({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<FullscreenPdfViewer> createState() => _FullscreenPdfViewerState();
}

class _FullscreenPdfViewerState extends State<FullscreenPdfViewer> {
  PdfController? _pdfController;
  bool _isLoading = true;
  double _progress = 0;
  String? _error;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf() async {
    try {
      _subscription?.cancel();
      String effectiveUrl = widget.pdfUrl;

      // Transform Google Drive links to direct download links
      if (effectiveUrl.contains('drive.google.com') &&
          effectiveUrl.contains('/file/d/')) {
        final regex = RegExp(r'/file/d/([^/]+)');
        final match = regex.firstMatch(effectiveUrl);
        if (match != null && match.groupCount >= 1) {
          final fileId = match.group(1);
          effectiveUrl =
              'https://drive.google.com/uc?export=download&id=$fileId';
          debugPrint('📍 Transformed Drive URL to direct link: $effectiveUrl');
        }
      }

      final stream = DefaultCacheManager().getFileStream(
        effectiveUrl,
        withProgress: true,
      );

      _subscription = stream.listen(
        (response) async {
          if (response is DownloadProgress) {
            if (mounted) {
              setState(() {
                _progress = response.progress ?? 0;
              });
            }
          } else if (response is FileInfo) {
            final file = response.file;

            // Verify if it's actually a PDF by checking the file header
            final bytes = await file.readAsBytes();
            if (bytes.length >= 4) {
              final header = String.fromCharCodes(bytes.take(4));
              if (header != '%PDF') {
                debugPrint('Downloaded file is not a PDF. Header: $header');
                if (mounted) {
                  setState(() {
                    _error =
                        'This attachment could not be loaded as a PDF. It might be a restricted Drive file or an image.';
                    _isLoading = false;
                  });
                }
                return;
              }
            }

            if (mounted) {
              setState(() {
                _isLoading = false;
                _pdfController = PdfController(
                  document: PdfDocument.openFile(file.path),
                );
              });
            }
          }
        },
        onError: (err) {
          debugPrint('Error downloading PDF: $err');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _error =
                  'Failed to download PDF. Please check your internet connection.';
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error initializing PDF viewer: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'An unexpected error occurred.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Downloading PDF... ${(_progress * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                          _progress = 0;
                        });
                        _downloadPdf();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : PdfView(
              controller: _pdfController!,
              scrollDirection: Axis.vertical,
              onDocumentLoaded: (document) {
                debugPrint('PDF document loaded');
              },
              onPageChanged: (page) {
                debugPrint('PDF page changed: $page');
              },
            ),
    );
  }
}
