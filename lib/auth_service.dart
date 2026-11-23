import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Web client ID dari Firebase Console (Authentication, Sign-in method, Google,
/// Web SDK configuration). Client ID bukan rahasia, memang ikut di dalam APK.
const String? kGoogleServerClientId =
    '510567635694-ie2ami6o7ft6bq7cunrfm5fc08js4p8b.apps.googleusercontent.com';

class AuthService {
  AuthService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = kGoogleServerClientId == null
        ? GoogleSignIn(scopes: <String>['email'])
        : GoogleSignIn(
            scopes: <String>['email'],
            serverClientId: kGoogleServerClientId,
          );

    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      throw const AuthCancelledException();
    }

    final GoogleSignInAuthentication googleAuth = await account.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // abaikan, lanjut sign out Firebase
    }
    await _auth.signOut();
  }
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();

  @override
  String toString() => 'Login dibatalkan';
}
