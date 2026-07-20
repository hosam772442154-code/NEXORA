import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CloudStorageService {
  final Dio _dio = Dio();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _imgBBKey = '2c6273aa7e505f949a39a1eb9f2345df';
  static const String _uploadcarePublicKey = 'a2868d6801c190421b14';

  Future<String?> uploadImage(File imageFile, {void Function(int sent, int total)? onSendProgress}) async {
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'key': _imgBBKey,
        'image': await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      Response response = await _dio.post(
        'https://api.imgbb.com/1/upload',
        data: formData,
        onSendProgress: onSendProgress,
      );

      if (response.statusCode == 200) {
        return response.data['data']['url'];
      } else {
        debugPrint('ImgBB Upload Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception during ImgBB upload: $e');
      return null;
    }
  }

  Future<String?> uploadDocument(File file, {void Function(int sent, int total)? onProgress}) async {
    try {
      String fileName = file.path.split('/').last;
      if (Platform.isWindows) {
        fileName = file.path.split('\\').last;
      }
      FormData formData = FormData.fromMap({
        'UPLOADCARE_PUB_KEY': _uploadcarePublicKey,
        'UPLOADCARE_STORE': 'auto',
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      Response response = await _dio.post(
        'https://upload.uploadcare.com/base/',
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.statusCode == 200) {
        final fileId = response.data['file'];
        if (fileId != null) {
          return 'https://ucarecdn.com/$fileId/';
        }
      } else {
        debugPrint('Uploadcare Upload Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception during Uploadcare upload: $e');
      return null;
    }
    return null;
  }

  Future<String?> uploadFile(File file, {void Function(int sent, int total)? onSendProgress}) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'UPLOADCARE_PUB_KEY': _uploadcarePublicKey,
        'UPLOADCARE_STORE': '1',
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      Response response = await _dio.post(
        'https://upload.uploadcare.com/base/',
        data: formData,
        onSendProgress: onSendProgress,
      );

      if (response.statusCode == 200) {
        String fileId = response.data['file'];
        return 'https://ucarecdn.com/$fileId/$fileName';
      } else {
        debugPrint('Uploadcare Upload Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception during Uploadcare upload: $e');
      return null;
    }
  }

  Future<void> updateDocumentUrl({
    required String collectionPath,
    required String documentId,
    required String fieldName,
    required String url,
  }) async {
    try {
      await _firestore.collection(collectionPath).doc(documentId).update({
        fieldName: url,
      });
      debugPrint('Successfully updated document $documentId with new URL.');
    } catch (e) {
      debugPrint('Error updating document URL: $e');
      throw Exception('Failed to update document: $e');
    }
  }
}
