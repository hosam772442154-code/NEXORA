import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nexora_it/constants/app_theme.dart';
import 'package:nexora_it/services/cloud_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

String formatArabic12HourFromTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final d = timestamp.toDate();
  int hour = d.hour;
  int minute = d.minute;
  final period = hour >= 12 ? 'مساءً' : 'صباحًا';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  final hourStr = hour.toString().padLeft(2, '0');
  final minuteStr = minute.toString().padLeft(2, '0');
  return '$hourStr:$minuteStr $period';
}

class AcademicStoreScreen extends StatefulWidget {
  const AcademicStoreScreen({super.key});

  @override
  State<AcademicStoreScreen> createState() => _AcademicStoreScreenState();
}

class _AcademicStoreScreenState extends State<AcademicStoreScreen> {
  String _userRole = 'طالب';
  bool _isLoadingRole = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  // State for Level catalogs
  String _selectedFilter = 'Books'; // Books, Summaries, Lectures

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _userRole = doc.data()?['role'] ?? 'طالب';
            _isLoadingRole = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _handleUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'zip', 'docx', 'doc'],
    );

    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      final file = File(result.files.single.path!);
      
      // Request Metadata from User
      final titleCtrl = TextEditingController();
      final descCtrl = TextEditingController();
      String selectedCategory = 'Lectures';
      String selectedLevel = 'المستوى الأول';

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('رفع مرجع جديد', style: TextStyle(fontFamily: 'Cairo')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descCtrl,
                          decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          items: ['Books', 'Summaries', 'Lectures']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Cairo'))))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedCategory = v!),
                          decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedLevel,
                          items: ['المستوى الأول', 'المستوى الثاني', 'المستوى الثالث', 'المستوى الرابع']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Cairo'))))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedLevel = v!),
                          decoration: const InputDecoration(labelText: 'المستوى', border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('رفع', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              }
            ),
          );
        }
      );

      if (confirm == true) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        final cloudStorage = CloudStorageService();
        final url = await cloudStorage.uploadDocument(file, onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        });

        if (url != null) {
          final user = FirebaseAuth.instance.currentUser;
          final userDoc = user != null ? await FirebaseFirestore.instance.collection('users').doc(user.uid).get() : null;
          final publisherName = userDoc?.data()?['name'] ?? 'مجهول';

          await FirebaseFirestore.instance.collection('academic_store').add({
            'title': titleCtrl.text.isNotEmpty ? titleCtrl.text : 'بدون عنوان',
            'description': descCtrl.text,
            'category': selectedCategory,
            'level': selectedLevel,
            'downloadUrl': url,
            'isExternalLink': false,
            'size': '${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
            'publisher': publisherName,
            'role': _userRole,
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الرفع بنجاح!', style: TextStyle(fontFamily: 'Cairo'))));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الرفع. الرجاء المحاولة مرة أخرى.', style: TextStyle(fontFamily: 'Cairo'))));
          }
        }

        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _handleDownload(Map<String, dynamic> data) async {
    final String url = data['downloadUrl'] ?? '';
    final bool isExternal = data['isExternalLink'] ?? false;

    if (url.isEmpty) return;

    if (isExternal) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canUpload = ['دكتور', 'مندوب', 'مدير'].contains(_userRole);

    return DefaultTabController(
      length: 5,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.95),
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('الم المتجر الأكاديمي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            bottom: const TabBar(
              isScrollable: true,
              labelColor: AppTheme.accentColor,
              unselectedLabelColor: Colors.white70,
              indicatorColor: AppTheme.accentColor,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'أحدث الإضافات'),
                Tab(text: 'المستوى الأول'),
                Tab(text: 'المستوى الثاني'),
                Tab(text: 'المستوى الثالث'),
                Tab(text: 'المستوى الرابع'),
              ],
            ),
          ),
          body: Stack(
            children: [
              TabBarView(
                children: [
                  _buildFeed(),
                  _buildLevelCatalog('المستوى الأول'),
                  _buildLevelCatalog('المستوى الثاني'),
                  _buildLevelCatalog('المستوى الثالث'),
                  _buildLevelCatalog('المستوى الرابع'),
                ],
              ),
              if (_isUploading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.glowShadow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            color: AppTheme.accentColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'جاري الرفع... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: (!canUpload || _isLoadingRole)
              ? null
              : FloatingActionButton(
                  onPressed: _handleUpload,
                  backgroundColor: AppTheme.accentColor,
                  child: const Icon(Icons.cloud_upload_rounded, color: AppTheme.primaryColor),
                ),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('academic_store').orderBy('createdAt', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد إضافات حديثة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final data = items[index].data() as Map<String, dynamic>;
            final title = data['title'] ?? 'بدون عنوان';
            final desc = data['description'] ?? '';
            final publisher = data['publisher'] ?? 'مجهول';
            final role = data['role'] ?? 'دكتور';
            final Timestamp? createdAt = data['createdAt'] as Timestamp?;
            final timeString = formatArabic12HourFromTimestamp(createdAt);

            IconData avatarIcon = Icons.person;
            if (role == 'دكتور') avatarIcon = Icons.school_rounded;
            else if (role == 'مندوب') avatarIcon = Icons.co_present_rounded;
            else if (role == 'مدير') avatarIcon = Icons.admin_panel_settings;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Elegant Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryLight,
                          child: Icon(avatarIcon, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(publisher, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(4)),
                                    child: Text(role, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(timeString, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_rounded, color: AppTheme.accentColor),
                          onPressed: () => _handleDownload(data),
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
                        const SizedBox(height: 8),
                        if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppTheme.secondaryTextColor)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(8)),
                              child: Text(data['category'] ?? 'Lectures', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(8)),
                              child: Text(data['size'] ?? 'Unknown Size', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLevelCatalog(String level) {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Books', 'Summaries', 'Lectures'].map((filter) {
                final isSelected = _selectedFilter == filter;
                String label = '';
                if (filter == 'Books') label = 'الكتب والمراجع';
                if (filter == 'Summaries') label = 'الملخصات';
                if (filter == 'Lectures') label = 'المحاضرات';

                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(label, style: TextStyle(fontFamily: 'Cairo', color: isSelected ? Colors.white : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: AppTheme.accentColor,
                    backgroundColor: AppTheme.primaryLight,
                    onSelected: (v) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('academic_store')
                .where('level', isEqualTo: level)
                .where('category', isEqualTo: _selectedFilter)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('لا توجد ملفات هنا حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
              }

              final items = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final data = items[index].data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'عنصر أكاديمي';
                  final size = data['size'] ?? '';
                  final isExternal = data['isExternalLink'] ?? false;

                  IconData assetIcon = Icons.insert_drive_file_rounded;
                  if (_selectedFilter == 'Books') assetIcon = Icons.menu_book_rounded;
                  else if (_selectedFilter == 'Summaries') assetIcon = Icons.article_rounded;
                  else if (_selectedFilter == 'Lectures') assetIcon = Icons.smart_display_rounded;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(assetIcon, color: AppTheme.primaryColor),
                      ),
                      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                      subtitle: Text(
                        isExternal ? "رابط خارجي ${size.isNotEmpty ? ' • $size' : ''}" : "ملف مباشر ${size.isNotEmpty ? ' • $size' : ''}",
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _handleDownload(data),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('تنزيل', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
