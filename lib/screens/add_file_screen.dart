import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/nexora_theme.dart';

class AddFileScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const AddFileScreen({super.key, required this.userName, required this.userRole});

  @override
  State<AddFileScreen> createState() => _AddFileScreenState();
}

class _AddFileScreenState extends State<AddFileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _urlController = TextEditingController();

  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (image != null) {
        final Uint8List bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      }
    } catch (_) {
      _showSnackBar('فشل الوصول إلى المعرض.', isError: true);
    }
  }

  void _skipImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red : NexoraTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String appImageUrl = '';

      if (_selectedImageBytes != null) {
        final String fileName = 'app_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference ref = FirebaseStorage.instance.ref().child('shared_files_images/$fileName');
        await ref.putData(_selectedImageBytes!);
        appImageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('shared_files').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'downloadUrl': _urlController.text.trim(),
        'appImageUrl': appImageUrl,
        'uploadedBy': widget.userName,
        'uploaderRole': widget.userRole,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('تم رفع الملف والتطبيق بنجاح!');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ أثناء الرفع: $e', isError: true);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: NexoraTheme.accentColor),
        filled: true,
        fillColor: NexoraTheme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NexoraTheme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NexoraTheme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NexoraTheme.accentColor, width: 2),
        ),
      ),
      validator: validator,
    );
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
            'رفع تطبيق/ملف جديد',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: NexoraTheme.accentColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _titleController,
                        label: 'عنوان التطبيق أو الملف',
                        icon: Icons.title_rounded,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descController,
                        label: 'وصف الملف (اختياري)',
                        icon: Icons.description_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _urlController,
                        label: 'رابط التحميل الخارجي (MediaFire, Google Drive...)',
                        icon: Icons.link_rounded,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'مطلوب';
                          if (!v.startsWith('http')) return 'يجب أن يبدأ بـ http أو https';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: NexoraTheme.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: NexoraTheme.accentColor.withOpacity(0.5),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: _selectedImageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded, size: 40, color: NexoraTheme.accentColor.withOpacity(0.8)),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'اختر صورة',
                                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _skipImage,
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white54),
                          label: const Text(
                            'تخطي إضافة صورة',
                            style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NexoraTheme.accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'رفع الملف الآن',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
