import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Phone Authentication (SMS OTP sent by Google, not Brevo).
///
/// Flow:
///   1. [sendCode] → Firebase sends the SMS; [onCodeSent] fires with the code
///      entry UI. On Android the code can be auto-retrieved → [onAutoVerified]
///      fires with a ready idToken (skip manual entry).
///   2. [confirmCode] → exchange the typed code for a Firebase idToken, which
///      the backend (`POST /auth/login/phone`) verifies to sign in / register.
class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;

  /// Start verification for an E.164 phone number (e.g. +8801XXXXXXXXX).
  Future<void> sendCode({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(String error) onError,
    void Function(String idToken)? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android instant/auto verification — sign in without manual code entry.
        if (onAutoVerified == null) return;
        try {
          final cred = await _auth.signInWithCredential(credential);
          final idToken = await cred.user?.getIdToken();
          if (idToken != null) onAutoVerified(idToken);
        } catch (_) {
          // fall back to manual entry; the code UI is already shown
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Could not send the verification code.');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Exchange the SMS code for a Firebase idToken.
  Future<String> confirmCode(String smsCode) async {
    final vid = _verificationId;
    if (vid == null) {
      throw Exception('No verification in progress. Request a new code.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: vid,
      smsCode: smsCode.trim(),
    );
    final cred = await _auth.signInWithCredential(credential);
    final idToken = await cred.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Could not obtain a session token from Firebase.');
    }
    return idToken;
  }

  void reset() {
    _verificationId = null;
    _resendToken = null;
  }
}
