import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:vtb_video_call/config/zoom_jwt_helper.dart';

class ZoomService {
  ZoomService._();
  static final ZoomService instance = ZoomService._();

  final ZoomVideoSdk _zoom = ZoomVideoSdk();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final initConfig = InitConfig(
      domain: 'zoom.us',
      enableLog: true,
    );

    await _zoom.initSdk(initConfig);
    _initialized = true;
  }

  Future<void> joinSession({
    required String sessionName,
    required String displayName,
  }) async {
    final cleanSession = sessionName.trim();
    final cleanName = displayName.trim();

    final token = ZoomJwtHelper.generateVideoSdkJwt(
      sessionName: cleanSession,
      userIdentity: cleanName,
      roleType: 0,
    );

    print('JOIN session=$cleanSession');
    print('JOIN user=$cleanName');
    print('TOKEN=$token');

    final joinConfig = JoinSessionConfig(
      sessionName: cleanSession,
      sessionPassword: '',
      token: token,
      userName: cleanName,
      audioOptions: {
        'connect': true,
        'mute': false,
      },
      videoOptions: {
        'localVideoOn': true,
      },
      sessionIdleTimeoutMins: 40,
    );

    await _zoom.joinSession(joinConfig);
  }

  Future<String> _myUserId() async {
    final me = await _zoom.session.getMySelf();
    if (me == null || me.userId.isEmpty) {
      throw Exception('Không lấy được user hiện tại');
    }
    return me.userId;
  }

  Future<bool> toggleMic({required bool currentValue}) async {
    final audioHelper = _zoom.audioHelper;
    final myUserId = await _myUserId();

    final newValue = !currentValue;

    if (newValue) {
      await audioHelper.unMuteAudio(myUserId);
    } else {
      await audioHelper.muteAudio(myUserId);
    }

    return newValue;
  }

  Future<bool> toggleCamera({required bool currentValue}) async {
    final videoHelper = _zoom.videoHelper;
    final newValue = !currentValue;

    if (newValue) {
      await videoHelper.startVideo();
    } else {
      await videoHelper.stopVideo();
    }

    return newValue;
  }

  Future<void> leaveSession() async {
    await _zoom.leaveSession(false);
  }
}
