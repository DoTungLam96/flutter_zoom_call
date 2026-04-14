import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'config.dart';

class ZoomJwtHelper {
  static String generateVideoSdkJwt({
    required String sessionName,
    required String userIdentity,
    int roleType = 1,
    int expireInSeconds = 60 * 60,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = now + expireInSeconds;

    final jwt = JWT(
      {
        'app_key': zoomSdkKey,
        'version': 1,
        'role_type': roleType,
        'tpc': sessionName,
        'user_identity': userIdentity,
        'iat': now,
        'exp': exp,
      },
    );

    return jwt.sign(
      SecretKey(zoomSdkSecret),
      algorithm: JWTAlgorithm.HS256,
    );
  }
}