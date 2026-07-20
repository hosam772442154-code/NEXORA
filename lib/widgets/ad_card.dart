import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nexora_it/constants/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Advanced3DAdSlider extends StatefulWidget {
  final List<Map<String, dynamic>> adsList;

  const Advanced3DAdSlider({super.key, required this.adsList});

  @override
  State<Advanced3DAdSlider> createState() => _Advanced3DAdSliderState();
}

class _Advanced3DAdSliderState extends State<Advanced3DAdSlider> {
  late PageController _pageController;
  double _pageValue = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _pageValue = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.adsList.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 310,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.adsList.length,
        itemBuilder: (context, index) {
          double value = 1.0;
          if (_pageController.position.haveDimensions) {
            value = (_pageValue - index).abs();
            value = (1 - (value * 0.15)).clamp(0.0, 1.0);
          }
          return Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..scaleByDouble(value, value, value, 1.0)
                ..rotateY((_pageValue - index) * 0.1),
              child: AdCard(
                adData: widget.adsList[index],
                onTap: () {},
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdCard extends StatelessWidget {
  final Map<String, dynamic> adData;
  final VoidCallback onTap;

  const AdCard({
    super.key,
    required this.adData,
    required this.onTap,
  });

  String _formatAdenTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        dateTime = timestamp.toDate();
      }
      
      int hour = dateTime.hour;
      int minute = dateTime.minute;
      String period = hour >= 12 ? 'PM' : 'AM';
      
      hour = hour % 12;
      if (hour == 0) hour = 12;
      
      String minuteStr = minute < 10 ? '0$minute' : '$minute';
      String hourStr = hour < 10 ? '0$hour' : '$hour';
      
      return "$hourStr:$minuteStr $period";
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNew = adData['isNew'] ?? false;
    final String type = adData['type'] ?? 'text';
    final String title = adData['title'] ?? 'بدون عنوان';
    final String? description = adData['description'];
    final String publisherName = adData['publisherName'] ?? 'إدارة النظام';
    final String publisherRole = adData['publisherRole'] ?? 'مدير';
    final String? publisherImg = adData['publisherImage'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (isNew)
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: publisherImg != null ? CachedNetworkImageProvider(publisherImg) : null,
                              child: publisherImg == null ? Icon(Icons.person, size: 16, color: Colors.grey[600]) : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    publisherName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textColor, fontFamily: 'Cairo'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "$publisherRole • ${_formatAdenTime(adData['createdAt'])}",
                                    style: const TextStyle(fontSize: 10, color: AppTheme.secondaryTextColor, fontFamily: 'Cairo'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "📢 إعلان أكاديمي",
                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textColor, height: 1.3, fontFamily: 'Cairo'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppTheme.secondaryTextColor, height: 1.4, fontFamily: 'Cairo'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildAdaptiveAttachment(type, adData),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveAttachment(String type, Map<String, dynamic> data) {
    if (data['coverImage'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: data['coverImage'],
          fit: BoxFit.cover,
          width: double.infinity,
          height: 130,
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    
    switch (type) {
      case 'apk':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.android_rounded, color: Colors.green, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['appName'] ?? "تطبيق أكاديمي", style: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                    Text("${data['appSize'] ?? 'غير معروف'} • v${data['appVersion'] ?? '1.0'}", style: const TextStyle(color: AppTheme.secondaryTextColor, fontSize: 11, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text("Download", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
              ),
            ],
          ),
        );
      case 'pdf':
      case 'file':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['fileName'] ?? "عرض ملف PDF",
                  style: const TextStyle(color: AppTheme.textColor, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.download_rounded, color: AppTheme.primaryColor, size: 24),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}