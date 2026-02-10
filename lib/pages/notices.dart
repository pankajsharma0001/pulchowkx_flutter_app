import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pulchowkx_app/models/notice.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulchowkx_app/widgets/full_screen_image_viewer.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

/// Notices page for displaying IOE exam results and routines
class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late TabController _tabController;
  NoticeStats? _stats;
  bool _isManager = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<Notice> _notices = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _checkRole();
    _loadNotices();
    _loadStats();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreNotices();
    }
  }

  Future<void> _checkRole() async {
    final role = await _apiService.getUserRole();
    if (mounted) {
      setState(() {
        _isManager = role == 'notice_manager';
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadNotices();
    }
  }

  String? get _activeCategory {
    switch (_tabController.index) {
      case 0:
        return 'results';
      case 1:
        return 'application_forms';
      case 2:
        return 'exam_centers';
      case 3:
        return 'general';
      default:
        return null;
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadNotices();
    });
  }

  Future<void> _loadNotices({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _offset = 0;
      _hasMore = true;
    });

    try {
      final filters = NoticeFilters(
        category: _activeCategory,
        search: _searchController.text.trim(),
        limit: _limit,
        offset: _offset,
      );

      final notices = await _apiService.getNotices(
        filters: filters,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
          _hasMore = notices.length >= _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreNotices() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextOffset = _offset + _limit;
      final filters = NoticeFilters(
        category: _activeCategory,
        search: _searchController.text.trim(),
        limit: _limit,
        offset: nextOffset,
      );

      final newNotices = await _apiService.getNotices(filters: filters);

      if (mounted) {
        setState(() {
          _notices.addAll(newNotices);
          _offset = nextOffset;
          _isLoadingMore = false;
          _hasMore = newNotices.length >= _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    final stats = await _apiService.getNoticeStats(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.notices),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.heroGradientDark
              : AppColors.heroGradient,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              haptics.mediumImpact();
              _loadNotices(forceRefresh: true);
              await _loadStats(forceRefresh: true);
            },
            color: AppColors.primary,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Header & Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'IOE Notices',
                          style: AppTextStyles.h3.copyWith(
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Exam results & routines from IOE',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            boxShadow: AppShadows.sm,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.border,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search results, routines...',
                              filled: false,
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMuted,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        _loadNotices(forceRefresh: true);
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Section Tabs
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Container(
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
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: const EdgeInsets.all(4),
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        labelStyle: AppTextStyles.labelSmall,
                        unselectedLabelStyle: AppTextStyles.labelSmall,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.assignment_rounded, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'Results',
                                  style: TextStyle(fontSize: 12),
                                ),
                                if (_stats != null && _stats!.results > 0) ...[
                                  const SizedBox(width: 4),
                                  _buildTabBadge(_stats!.results),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.description_rounded, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'Forms',
                                  style: TextStyle(fontSize: 12),
                                ),
                                if (_stats != null &&
                                    _stats!.applicationForms > 0) ...[
                                  const SizedBox(width: 4),
                                  _buildTabBadge(_stats!.applicationForms),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'Centers',
                                  style: TextStyle(fontSize: 12),
                                ),
                                if (_stats != null &&
                                    _stats!.examCenters > 0) ...[
                                  const SizedBox(width: 4),
                                  _buildTabBadge(_stats!.examCenters),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.info_rounded, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'General',
                                  style: TextStyle(fontSize: 12),
                                ),
                                if (_stats != null && _stats!.general > 0) ...[
                                  const SizedBox(width: 4),
                                  _buildTabBadge(_stats!.general),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),

                // Notices List
                if (_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const _NoticeCardShimmer(),
                        childCount: 5,
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildErrorState(_errorMessage!),
                  )
                else if (_notices.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= _notices.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return _NoticeCard(
                            notice: _notices[index],
                            isManager: _isManager,
                            onEdit: () => _showNoticeDialog(_notices[index]),
                            onDelete: () => _deleteNotice(_notices[index]),
                          );
                        },
                        childCount: _notices.length + (_isLoadingMore ? 1 : 0),
                      ),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isManager
          ? FloatingActionButton.extended(
              onPressed: () => _showNoticeDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Notice'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Future<void> _showNoticeDialog([Notice? notice]) async {
    final isEdit = notice != null;
    final titleController = TextEditingController(text: notice?.title);
    final contentController = TextEditingController(text: notice?.content);
    String? selectedCategory = notice?.category ?? _activeCategory;
    String? attachmentUrl = notice?.attachmentUrl;
    String? attachmentName = notice?.attachmentName;
    bool isUploading = false;
    bool isPublishing = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.easeInOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.lg,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: StatefulBuilder(
                    builder: (context, setDialogState) => SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? AppColors.borderDark
                                      : AppColors.border,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  child: Icon(
                                    isEdit
                                        ? Icons.edit_rounded
                                        : Icons.add_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    isEdit ? 'Edit Notice' : 'New Notice',
                                    style: AppTextStyles.h4.copyWith(
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => Navigator.pop(context),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Form Fields
                                Text(
                                  'General Details',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: titleController,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Notice Title',
                                    hintText:
                                        'e.g., Computer Engineering Routine',
                                    prefixIcon: const Icon(
                                      Icons.title_rounded,
                                      size: 20,
                                    ),
                                    fillColor: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : AppColors.backgroundSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: contentController,
                                  maxLines: 4,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    hintText:
                                        'Provide details about the notice...',
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 60,
                                      ),
                                      child: const Icon(
                                        Icons.notes_rounded,
                                        size: 20,
                                      ),
                                    ),
                                    fillColor: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : AppColors.backgroundSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                Text(
                                  'Categorization',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: selectedCategory,
                                        isExpanded: true,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimary,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Category',
                                          prefixIcon: Icon(
                                            Icons.category_rounded,
                                            size: 20,
                                          ),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'results',
                                            child: Text('Results'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'application_forms',
                                            child: Text('Forms'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'exam_centers',
                                            child: Text('Centers'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'general',
                                            child: Text('General'),
                                          ),
                                        ],
                                        onChanged: (v) => setDialogState(
                                          () => selectedCategory = v,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                Text(
                                  'Attachment',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (attachmentUrl != null)
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : AppColors.primary.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.surfaceDark
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.md,
                                            ),
                                            boxShadow: AppShadows.sm,
                                            border: Border.all(
                                              color: isDark
                                                  ? AppColors.borderDark
                                                  : AppColors.border,
                                            ),
                                          ),
                                          child: Icon(
                                            attachmentName
                                                        ?.toLowerCase()
                                                        .endsWith('.pdf') ??
                                                    false
                                                ? Icons.picture_as_pdf_rounded
                                                : Icons.image_rounded,
                                            color: AppColors.primary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                attachmentName ??
                                                    'Attached File',
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                      color: isDark
                                                          ? AppColors
                                                                .textPrimaryDark
                                                          : AppColors
                                                                .textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Ready for publish',
                                                style: AppTextStyles.labelSmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppColors.error,
                                            size: 22,
                                          ),
                                          onPressed: () => setDialogState(() {
                                            attachmentUrl = null;
                                            attachmentName = null;
                                          }),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: isUploading
                                        ? null
                                        : () async {
                                            final result = await FilePicker
                                                .platform
                                                .pickFiles(
                                                  type: FileType.custom,
                                                  allowedExtensions: [
                                                    'pdf',
                                                    'jpg',
                                                    'jpeg',
                                                    'png',
                                                  ],
                                                );

                                            if (result != null &&
                                                result.files.single.path !=
                                                    null) {
                                              setDialogState(
                                                () => isUploading = true,
                                              );
                                              final uploadResult =
                                                  await _apiService
                                                      .uploadNoticeAttachment(
                                                        File(
                                                          result
                                                              .files
                                                              .single
                                                              .path!,
                                                        ),
                                                      );
                                              setDialogState(() {
                                                isUploading = false;
                                                if (uploadResult['success']) {
                                                  attachmentUrl =
                                                      uploadResult['data']['url'];
                                                  attachmentName =
                                                      uploadResult['data']['name'];
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        uploadResult['message'],
                                                      ),
                                                    ),
                                                  );
                                                }
                                              });
                                            }
                                          },
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.xl,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.03,
                                              )
                                            : AppColors.backgroundSecondary,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.lg,
                                        ),
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.borderDark
                                              : AppColors.border,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          if (isUploading)
                                            const CircularProgressIndicator()
                                          else ...[
                                            Icon(
                                              Icons.cloud_upload_rounded,
                                              size: 32,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.sm,
                                            ),
                                            Text(
                                              'Tap to upload Image or PDF',
                                              style: AppTextStyles.labelMedium
                                                  .copyWith(
                                                    color: isDark
                                                        ? AppColors
                                                              .textPrimaryDark
                                                        : AppColors.textPrimary,
                                                  ),
                                            ),
                                            Text(
                                              'Maximum file size: 10MB',
                                              style: AppTextStyles.labelSmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Action Buttons
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: (isUploading || isPublishing)
                                        ? null
                                        : () async {
                                            if (titleController.text.isEmpty ||
                                                contentController
                                                    .text
                                                    .isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please fill all required fields',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            setDialogState(
                                              () => isPublishing = true,
                                            );

                                            final data = {
                                              'title': titleController.text
                                                  .trim(),
                                              'content': contentController.text
                                                  .trim(),
                                              'category': selectedCategory,
                                              'section':
                                                  selectedCategory != null
                                                  ? (selectedCategory ==
                                                                'results' ||
                                                            selectedCategory ==
                                                                'application_forms'
                                                        ? 'results'
                                                        : 'routines')
                                                  : 'results',
                                              'attachmentUrl': attachmentUrl,
                                              'attachmentName': attachmentName,
                                            };

                                            try {
                                              final result = isEdit
                                                  ? await _apiService
                                                        .updateNotice(
                                                          notice.id,
                                                          data,
                                                        )
                                                  : await _apiService
                                                        .createNotice(data);

                                              if (context.mounted) {
                                                if (result['success']) {
                                                  Navigator.of(context).pop();
                                                  _loadNotices(
                                                    forceRefresh: true,
                                                  );
                                                  _loadStats(
                                                    forceRefresh: true,
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        result['message'] ??
                                                            'Success',
                                                      ),
                                                      backgroundColor:
                                                          AppColors.success,
                                                    ),
                                                  );
                                                } else {
                                                  setDialogState(
                                                    () => isPublishing = false,
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        result['message'] ??
                                                            'Error',
                                                      ),
                                                      backgroundColor:
                                                          AppColors.error,
                                                    ),
                                                  );
                                                }
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                setDialogState(
                                                  () => isPublishing = false,
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Error: $e'),
                                                    backgroundColor:
                                                        AppColors.error,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    child: isPublishing
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(isEdit ? 'Update' : 'Publish'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
    );
  }

  Future<void> _deleteNotice(Notice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: Text('Are you sure you want to delete "${notice.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      haptics.mediumImpact();
      final result = await _apiService.deleteNotice(notice.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Notice deleted'),
            backgroundColor: result['success']
                ? AppColors.success
                : AppColors.error,
          ),
        );
        if (result['success']) {
          _loadNotices(forceRefresh: true);
          _loadStats(forceRefresh: true);
        }
      }
    }
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.sm,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 48,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Notices Found',
              style: AppTextStyles.h3.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'There are no notices in this category yet.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load notices',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Please check your connection and try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _loadNotices,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Notice card widget
class _NoticeCard extends StatelessWidget {
  final Notice notice;
  final bool isManager;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _NoticeCard({
    required this.notice,
    this.isManager = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.sm,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: notice.attachmentUrl != null
              ? () => _openAttachment(context)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getSectionColor().withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: _getSectionColor().withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        _getAttachmentIcon(),
                        size: 24,
                        color: _getSectionColor(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (notice.isNew) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                'RECENTLY POSTED',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            notice.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notice.content,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isManager)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMuted,
                        ),
                        onSelected: (value) {
                          haptics.lightImpact();
                          if (value == 'edit') {
                            onEdit?.call();
                          } else if (value == 'delete') {
                            onDelete?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 20),
                                SizedBox(width: 12),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(notice.createdAt),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (notice.attachmentUrl != null) ...[
                        Text(
                          notice.attachmentType == NoticeAttachmentType.pdf
                              ? 'PDF DOCUMENT'
                              : 'IMAGE ATTACHMENT',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSectionColor() {
    return notice.section == NoticeSection.results
        ? AppColors.success
        : AppColors.info;
  }

  IconData _getAttachmentIcon() {
    if (notice.attachmentType == NoticeAttachmentType.pdf) {
      return Icons.picture_as_pdf_rounded;
    } else if (notice.attachmentType == NoticeAttachmentType.image) {
      return Icons.image_rounded;
    }
    return notice.section == NoticeSection.results
        ? Icons.assignment_rounded
        : Icons.calendar_today_rounded;
  }

  Future<void> _openAttachment(BuildContext context) async {
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
          builder: (context) => _FullscreenPdfViewer(
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
class _FullscreenPdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const _FullscreenPdfViewer({required this.pdfUrl, required this.title});

  @override
  State<_FullscreenPdfViewer> createState() => _FullscreenPdfViewerState();
}

class _FullscreenPdfViewerState extends State<_FullscreenPdfViewer> {
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
                _pdfController = PdfController(
                  document: PdfDocument.openFile(file.path),
                );
                _isLoading = false;
                _progress = 1.0;
              });
            }
          }
        },
        onError: (e) {
          debugPrint('Error downloading PDF stream: $e');
          if (mounted) {
            setState(() {
              _error = 'Failed to download PDF. Please check your connection.';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error initiating PDF download: $e');
      if (mounted) {
        setState(() {
          _error = 'Unable to start download. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.open_in_browser_rounded,
              color: Colors.white,
            ),
            tooltip: 'Open in browser',
            onPressed: () async {
              final uri = Uri.tryParse(widget.pdfUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ), // Closing parenthesis for AppBar and comma
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  color: Colors.white,
                  strokeWidth: 2,
                ),
                if (_progress > 0)
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _progress > 0 ? 'Downloading...' : 'Initializing...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _downloadPdf();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(
        child: Text(
          'Could not load PDF document',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return RepaintBoundary(
      child: PdfView(
        controller: _pdfController!,
        scrollDirection: Axis.vertical,
        renderer: (PdfPage page) => page.render(
          width: page.width * 1.5,
          height: page.height * 1.5,
          format: PdfPageImageFormat.jpeg,
          quality: 80,
        ),
        builders: PdfViewBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          errorBuilder: (_, error) => Center(
            child: Text(
              'Error: ${error.toString()}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer for notice card
class _NoticeCardShimmer extends StatelessWidget {
  const _NoticeCardShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.sm,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: ShimmerLoader(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: 220, color: Colors.white),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 180, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(
                    height: 32,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
