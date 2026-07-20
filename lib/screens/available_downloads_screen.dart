import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/nexora_theme.dart';

class AvailableDownloadsScreen extends StatelessWidget {
  const AvailableDownloadsScreen({super.key});

  Future<void> _launchUrl(String url, BuildContext context) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الرابط الخارجي.', textDirection: TextDirection.rtl),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NexoraTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: NexoraTheme.backgroundColor,
          elevation: 0,
          title: const Text(
            'تطبيقات وملفات هامة',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('shared_files')
              .orderBy('uploadedAt', descending: true)
              .snapshots(includeMetadataChanges: true),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: NexoraTheme.accentColor));
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد ملفات متوفرة حالياً.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final String title = data['title'] ?? 'بدون عنوان';
                final String description = data['description'] ?? '';
                final String downloadUrl = data['downloadUrl'] ?? '';
                final String appImageUrl = data['appImageUrl'] ?? '';
                final String uploaderRole = data['uploaderRole'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: NexoraTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NexoraTheme.dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: NexoraTheme.accentColor.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (appImageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: CachedNetworkImage(
                            imageUrl: appImageUrl,
                            height: 160,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 160,
                              color: NexoraTheme.backgroundColor,
                              child: const Center(child: CircularProgressIndicator(color: NexoraTheme.accentColor)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 160,
                              color: NexoraTheme.backgroundColor,
                              child: const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 50),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 140,
                          decoration: const BoxDecoration(
                            color: Color(0xFF162032),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.data_usage_rounded,
                              size: 60,
                              color: NexoraTheme.accentColor.withOpacity(0.5),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (uploaderRole.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: NexoraTheme.accentColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: NexoraTheme.accentColor),
                                    ),
                                    child: Text(
                                      uploaderRole,
                                      style: const TextStyle(
                                        color: NexoraTheme.accentColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _launchUrl(downloadUrl, context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NexoraTheme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.download_rounded, size: 20),
                              label: const Text(
                                'تحميل الآن',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
