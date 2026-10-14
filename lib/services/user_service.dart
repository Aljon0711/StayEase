import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Simple SHA-256 password hash. In production you'd also want salt + stronger KDF.
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password.trim())).toString();
  }

  Future<void> upsertUser({
    String? role, // "guest" | "employee"
    String? fullName,
    required String passwordHash,
    String? email,
    String? phone,
    String? employeeId,
    String? department,
  }) async {
    final now = FieldValue.serverTimestamp();

    // Use email/phone as stable doc id when available; fallback to auto-id.
    final docId = (email?.trim().isNotEmpty ?? false)
        ? email!.trim().toLowerCase()
        : (phone?.trim().isNotEmpty ?? false)
            ? phone!.trim()
            : null;

    final ref = docId == null
        ? _firestore.collection('users').doc()
        : _firestore.collection('users').doc(docId);

    final Map<String, dynamic> data = {
      'passwordHash': passwordHash,
      'updatedAt': now,
    };

    if (role != null) data['role'] = role;
    if (fullName != null) data['fullName'] = fullName.trim();
    if (email != null) data['email'] = email.trim();
    if (phone != null) data['phone'] = phone.trim();
    if (employeeId != null) data['employeeId'] = employeeId.trim();
    if (department != null) data['department'] = department.trim();

    // Only set createdAt if the document is new
    if (docId == null || !(await ref.get()).exists) {
      data['createdAt'] = now;
    }

    await ref.set(data, SetOptions(merge: true));
  }
}
