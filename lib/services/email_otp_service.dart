import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Service responsible for creating & verifying email-based OTPs.
/// Also integrates with EmailJS to actually send the OTP email.
class EmailOtpService {
  EmailOtpService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // TODO: Replace these placeholders with your actual EmailJS values.
  // Get them from https://dashboard.emailjs.com/admin
  static const String _emailJsServiceId = 'service_kw22ogn';
  static const String _emailJsTemplateId = 'template_b2tv22p';
  static const String _emailJsPublicKey = 'zgpPszw4eJntmuBSh';

  String _generate6Digits() {
    final rng = Random.secure();
    return (rng.nextInt(900000) + 100000).toString();
  }

  String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<void> createOtpForEmail({
    required String email,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final normalized = email.trim().toLowerCase();
    final code = _generate6Digits();
    final expiresAt = Timestamp.fromDate(DateTime.now().add(ttl));
    final expiresText = '${ttl.inMinutes} minutes';

    // Store hashed OTP for verification.
    await _firestore.collection('email_otps').doc(normalized).set({
      'email': normalized,
      'codeHash': _hash(code),
      'expiresAt': expiresAt,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // For development visibility only (optional): store plaintext temporarily.
    // Remove this in production.
    await _firestore.collection('email_otps_debug').doc(normalized).set({
      'email': normalized,
      'code': code,
      'expiresAt': expiresAt,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Send the OTP via EmailJS.
    await _sendOtpEmailViaEmailJs(toEmail: normalized, code: code, expiresText: expiresText);
  }

  Future<bool> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final normalized = email.trim().toLowerCase();
    final snap = await _firestore.collection('email_otps').doc(normalized).get();
    if (!snap.exists) return false;

    final data = snap.data()!;
    final expiresAt = data['expiresAt'];
    if (expiresAt is Timestamp) {
      if (expiresAt.toDate().isBefore(DateTime.now())) return false;
    }

    final codeHash = data['codeHash'];
    if (codeHash is! String) return false;

    return codeHash == _hash(code.trim());
  }

  Future<void> _sendOtpEmailViaEmailJs({
    required String toEmail,
    required String code,
    required String expiresText,
  }) async {
    if (_emailJsServiceId.startsWith('YOUR_') ||
        _emailJsTemplateId.startsWith('YOUR_') ||
        _emailJsPublicKey.startsWith('YOUR_')) {
      // Not configured yet; skip sending.
      return;
    }

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': _emailJsServiceId,
        'template_id': _emailJsTemplateId,
        'user_id': _emailJsPublicKey,
        'template_params': {
          // Match your EmailJS template variables:
          // To Email: {{email}}
          // Content: {{passcode}} and {{time}}
          'email': toEmail,
          'passcode': code,
          'time': expiresText,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send OTP email: ${response.statusCode} ${response.body}');
    }
  }
}


