import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexora_it/constants/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<String> _pinnedMessageIds = [];
  List<String> _archivedMessageIds = [];
  List<String> _deletedMessageIds = [];

  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadLocalPrefs();
  }

  Future<void> _loadLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pinnedMessageIds = prefs.getStringList('pinnedMessages') ?? [];
      _archivedMessageIds = prefs.getStringList('archivedMessages') ?? [];
      _deletedMessageIds = prefs.getStringList('deletedMessages') ?? [];
    });
  }

  Future<void> _saveLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedMessages', _pinnedMessageIds);
    await prefs.setStringList('archivedMessages', _archivedMessageIds);
    await prefs.setStringList('deletedMessages', _deletedMessageIds);
  }

  Future<void> _togglePin(String id) async {
    if (_pinnedMessageIds.contains(id)) {
      setState(() => _pinnedMessageIds.remove(id));
    } else {
      if (_pinnedMessageIds.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكنك تثبيت أكثر من 3 رسائل', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      setState(() => _pinnedMessageIds.add(id));
    }
    await _saveLocalPrefs();
  }

  Future<void> _toggleArchive(String id) async {
    setState(() {
      if (_archivedMessageIds.contains(id)) {
        _archivedMessageIds.remove(id);
      } else {
        _archivedMessageIds.add(id);
        _pinnedMessageIds.remove(id); // unpin if archiving
      }
    });
    await _saveLocalPrefs();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo')),
            content: const Text('هل أنت متأكد من حذف الرسائل المحددة؟', style: TextStyle(fontFamily: 'Cairo')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _deletedMessageIds.addAll(_selectedIds);
        _pinnedMessageIds.removeWhere((id) => _selectedIds.contains(id));
        _archivedMessageIds.removeWhere((id) => _selectedIds.contains(id));
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      await _saveLocalPrefs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحذف بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {}); // trigger rebuild
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'صندوق الرسائل',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
            actions: [
              if (_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                  onPressed: _deleteSelected,
                ),
              IconButton(
                icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
                onPressed: _toggleSelectionMode,
              ),
            ],
            bottom: const TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'صندوق الرسائل'),
                Tab(text: 'الأرشيف'),
              ],
            ),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('لا توجد رسائل', style: TextStyle(fontFamily: 'Cairo')),
                );
              }

              final allDocs = snapshot.data!.docs.where((doc) {
                return !_deletedMessageIds.contains(doc.id);
              }).toList();

              final inboxDocs = allDocs.where((doc) => !_archivedMessageIds.contains(doc.id)).toList();
              
              inboxDocs.sort((a, b) {
                final bool aPinned = _pinnedMessageIds.contains(a.id);
                final bool bPinned = _pinnedMessageIds.contains(b.id);
                if (aPinned && !bPinned) return -1;
                if (!aPinned && bPinned) return 1;
                return 0; // maintain descending date
              });

              final archivedDocs = allDocs.where((doc) => _archivedMessageIds.contains(doc.id)).toList();

              return TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppTheme.primaryColor,
                    child: _buildMessageList(inboxDocs, isArchiveTab: false),
                  ),
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppTheme.primaryColor,
                    child: _buildMessageList(archivedDocs, isArchiveTab: true),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {required bool isArchiveTab}) {
    if (docs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: Text('لا توجد رسائل هنا', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
        ],
      );
    }

    return Column(
      children: [
        if (_isSelectionMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Checkbox(
                  value: _selectedIds.length == docs.length && docs.isNotEmpty,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.addAll(docs.map((d) => d.id));
                      } else {
                        _selectedIds.clear();
                      }
                    });
                  },
                ),
                const Text('تحديد الكل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_selectedIds.length} محدد', style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final id = doc.id;
              final isPinned = _pinnedMessageIds.contains(id);
              final isSelected = _selectedIds.contains(id);

              final title = data['title'] ?? 'إعلان';
              final body = data['body'] ?? '';
              final publisher = data['publisher'] ?? 'نكسورا';
              final role = data['role'] ?? 'إدارة';
              final Timestamp? createdAt = data['createdAt'] as Timestamp?;
              final relativeTimeStr = createdAt != null
                  ? _formatRelativeTime(createdAt.toDate())
                  : '';

              IconData senderIcon = Icons.admin_panel_settings;
              if (role == 'دكتور') senderIcon = Icons.school_rounded;
              else if (role == 'مندوب') senderIcon = Icons.support_agent;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isPinned
                      ? const BorderSide(color: AppTheme.accentColor, width: 1.5)
                      : BorderSide.none,
                ),
                elevation: isPinned ? 4 : 1,
                child: InkWell(
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) _selectedIds.remove(id);
                            else _selectedIds.add(id);
                          });
                        }
                      : () => _showMessageDialog(title, body, publisher, role),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isSelectionMode)
                          Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selectedIds.add(id);
                                else _selectedIds.remove(id);
                              });
                            },
                          ),
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryLight,
                          child: Icon(senderIcon, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      publisher,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14),
                                    ),
                                  ),
                                  if (isPinned)
                                    const Icon(Icons.push_pin, size: 16, color: AppTheme.accentColor),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      relativeTimeStr,
                                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Cairo'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (val) {
                            if (val == 'pin') _togglePin(id);
                            if (val == 'archive') _toggleArchive(id);
                            if (val == 'delete') {
                              _selectedIds.add(id);
                              _deleteSelected();
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (!isArchiveTab)
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(isPinned ? 'إلغاء التثبيت' : 'تثبيت', style: const TextStyle(fontFamily: 'Cairo')),
                              ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text(isArchiveTab ? 'إلغاء الأرشيف' : 'أرشفة', style: const TextStyle(fontFamily: 'Cairo')),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.errorColor)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Formats a 24h DateTime into Arabic 12-hour time string (e.g. "01:35 مساءً")
  String _formatArabic12Hour(DateTime dt) {
    int hour = dt.hour;
    final int minute = dt.minute;
    final String period = hour >= 12 ? 'مساءً' : 'صباحاً';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    final String hourStr = hour < 10 ? '0$hour' : '$hour';
    final String minuteStr = minute < 10 ? '0$minute' : '$minute';

    return '$hourStr:$minuteStr $period';
  }

  /// Returns a relative Arabic date+time string based on difference from now.
  /// Rules:
  ///   Same day       → "اليوم، 01:35 مساءً"
  ///   Yesterday      → "أمس، 12:26 صباحاً"
  ///   2-6 days ago   → "قبل 3 أيام، 08:30 مساءً"
  ///   7 days ago     → "قبل أسبوع، 01:34 مساءً"
  ///   Older          → "2026/07/12، 01:34 مساءً"
  String _formatRelativeTime(DateTime messageDateTime) {
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime messageDay = DateTime(messageDateTime.year, messageDateTime.month, messageDateTime.day);
    final int daysDiff = todayStart.difference(messageDay).inDays;

    final String timeStr = _formatArabic12Hour(messageDateTime);

    if (daysDiff == 0) {
      return 'اليوم، $timeStr';
    } else if (daysDiff == 1) {
      return 'أمس، $timeStr';
    } else if (daysDiff >= 2 && daysDiff <= 6) {
      return 'قبل $daysDiff أيام، $timeStr';
    } else if (daysDiff == 7) {
      return 'قبل أسبوع، $timeStr';
    } else {
      // Full date: YYYY/MM/DD
      final String y = messageDateTime.year.toString();
      final String m = messageDateTime.month.toString().padLeft(2, '0');
      final String d = messageDateTime.day.toString().padLeft(2, '0');
      return '$y/$m/$d، $timeStr';
    }
  }

  void _showMessageDialog(String title, String body, String publisher, String role) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Text('$publisher ($role)', style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(body, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                  const SizedBox(height: 16),
                  if (body.contains('http'))
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('فتح الرابط المرفق', style: TextStyle(fontFamily: 'Cairo')),
                      onPressed: () {
                        final words = body.split(' ');
                        final link = words.firstWhere((w) => w.startsWith('http'), orElse: () => '');
                        if (link.isNotEmpty) {
                          launchUrl(Uri.parse(link));
                        }
                      },
                    )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        );
      },
    );
  }
}
