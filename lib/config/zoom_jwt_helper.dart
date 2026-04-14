import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'config.dart';

class ZoomJwtHelper {
  static String generateVideoSdkJwt({
    required String sessionName,
    required String userIdentity,
    int roleType = 1,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final iat = now;
    final exp = iat + 60 * 60;

    final jwt = JWT({
      'app_key': zoomSdkKey,
      'role_type': roleType,
      'tpc': sessionName.trim(),
      'version': 1,
      'iat': iat,
      'exp': exp,
      'user_key': userIdentity.trim(),
    });

    return jwt.sign(
      SecretKey(zoomSdkSecret),
      algorithm: JWTAlgorithm.HS256,
    );
  }
}
