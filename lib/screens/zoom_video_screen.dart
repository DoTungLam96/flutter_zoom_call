import 'package:flutter/material.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_event_listener.dart';
import 'package:vtb_video_call/config/config.dart';
import 'package:vtb_video_call/config/zoom_jwt_helper.dart';

class ZoomVideoScreen extends StatefulWidget {
  const ZoomVideoScreen({super.key});

  @override
  State<ZoomVideoScreen> createState() => _ZoomVideoScreenState();
}

class _ZoomVideoScreenState extends State<ZoomVideoScreen> {
  final ZoomVideoSdk _zoom = ZoomVideoSdk();
  final ZoomVideoSdkEventListener _listener = ZoomVideoSdkEventListener();

  final TextEditingController _sessionNameController = TextEditingController(text: defaultSessionName);
  final TextEditingController _displayNameController = TextEditingController(text: defaultDisplayName);

  bool _sdkReady = false;
  bool _joining = false;
  bool _inSession = false;
  bool _isMuted = false;
  bool _isVideoOn = true;

  String _status = 'Chưa khởi tạo SDK';
  String _generatedToken = '';
  final List<String> _remoteUsers = [];

  @override
  void initState() {
    super.initState();
    _initSdk();
    _bindEvents();
  }

  Future<void> _initSdk() async {
    try {
      await _zoom.initSdk(
        InitConfig(
          domain: 'zoom.us',
          enableLog: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _sdkReady = true;
        _status = 'SDK đã sẵn sàng';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Init SDK lỗi: $e';
      });
    }
  }

  void _bindEvents() {
    _listener.addListener(EventType.onSessionJoin, (data) async {
      print('LamDT_onSessionJoin: $data');

      final users = await _zoom.session.getRemoteUsers();

      if (!mounted) return;
      setState(() {
        _inSession = true;
        _joining = false;
        _remoteUsers
          ..clear()
          ..addAll((users ?? []).map((e) => e.userName ?? 'Unknown'));
        _status = 'Đã join session';
      });
    });

    _listener.addListener(EventType.onSessionLeave, (data) {
      print('LamDT_onSessionLeave: $data');

      if (!mounted) return;
      setState(() {
        _inSession = false;
        _joining = false;
        _isMuted = false;
        _isVideoOn = true;
        _remoteUsers.clear();
        _status = 'Đã rời session';
      });
    });

    _listener.addListener(EventType.onUserJoin, (data) async {
      print('LamDT_onUserJoin: $data');

      final users = await _zoom.session.getRemoteUsers();

      if (!mounted) return;
      setState(() {
        _remoteUsers
          ..clear()
          ..addAll((users ?? []).map((e) => e.userName ?? 'Unknown'));
        _status = 'Có người tham gia';
      });
    });

    _listener.addListener(EventType.onUserLeave, (data) async {
      print('LamDT_onUserLeave: $data');

      final users = await _zoom.session.getRemoteUsers();

      if (!mounted) return;
      setState(() {
        _remoteUsers
          ..clear()
          ..addAll((users ?? []).map((e) => e.userName ?? 'Unknown'));
        _status = 'Có người rời session';
      });
    });

    _listener.addListener(EventType.onError, (data) {
      print('LamDT_onError: $data');

      if (!mounted) return;
      setState(() {
        _joining = false;
        _status = 'Zoom error: $data';
      });
    });
  }

  Future<void> _joinSession() async {
    final sessionName = _sessionNameController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (!_sdkReady) {
      setState(() {
        _status = 'SDK chưa sẵn sàng';
      });
      return;
    }

    if (sessionName.isEmpty || displayName.isEmpty) {
      setState(() {
        _status = 'Nhập đủ sessionName và displayName';
      });
      return;
    }

    final token = ZoomJwtHelper.generateVideoSdkJwt(
      sessionName: sessionName,
      userIdentity: displayName,
      roleType: 1,
    );

    print('LamDT_sessionName=$sessionName');
    print('LamDT_displayName=$displayName');
    print('LamDT_generatedToken=$token');

    setState(() {
      _generatedToken = token;
      _joining = true;
      _status = 'Đang join session...';
    });

    try {
      await _zoom.joinSession(
        JoinSessionConfig(
          sessionName: sessionName,
          sessionPassword: '',
          token: token,
          userName: displayName,
          audioOptions: {
            'connect': true,
            'mute': false,
          },
          videoOptions: {
            'localVideoOn': true,
          },
          sessionIdleTimeoutMins: 40,
        ),
      );
    } catch (e) {
      print('LamDT_joinSession catch: $e');

      if (!mounted) return;
      setState(() {
        _joining = false;
        _inSession = false;
        _status = 'Join lỗi: $e';
      });
    }
  }

  Future<void> _leaveSession() async {
    try {
      await _zoom.leaveSession(false);

      if (!mounted) return;
      setState(() {
        _inSession = false;
        _joining = false;
        _status = 'Đã rời session';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Leave lỗi: $e';
      });
    }
  }

  Future<void> _toggleMute() async {
    try {
      final mySelf = await _zoom.session.getMySelf();
      final userId = mySelf?.userId;

      if (userId == null || userId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _status = 'Không lấy được userId';
        });
        return;
      }

      if (_isMuted) {
        await _zoom.audioHelper.unMuteAudio(userId);
      } else {
        await _zoom.audioHelper.muteAudio(userId);
      }

      if (!mounted) return;
      setState(() {
        _isMuted = !_isMuted;
        _status = _isMuted ? 'Mic đang tắt' : 'Mic đang bật';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Mute lỗi: $e';
      });
    }
  }

  Future<void> _toggleVideo() async {
    try {
      if (_isVideoOn) {
        await _zoom.videoHelper.stopVideo();
      } else {
        await _zoom.videoHelper.startVideo();
      }

      if (!mounted) return;
      setState(() {
        _isVideoOn = !_isVideoOn;
        _status = _isVideoOn ? 'Camera đang bật' : 'Camera đã tắt';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Video lỗi: $e';
      });
    }
  }

  String _shortToken(String token) {
    if (token.length <= 100) return token;
    return '${token.substring(0, 100)}...';
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canControl = _inSession && !_joining;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zoom Video Demo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTextField(
                label: 'Session name',
                controller: _sessionNameController,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Display name',
                controller: _displayNameController,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _generatedToken.isEmpty ? 'JWT Token: Chưa generate' : 'JWT Token:\n${_shortToken(_generatedToken)}',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_joining || _inSession) ? null : _joinSession,
                      child: const Text('Join'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _inSession ? _leaveSession : null,
                      child: const Text('Leave'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: canControl ? _toggleMute : null,
                    child: Text(_isMuted ? 'Unmute' : 'Mute'),
                  ),
                  ElevatedButton(
                    onPressed: canControl ? _toggleVideo : null,
                    child: Text(_isVideoOn ? 'Stop Camera' : 'Start Camera'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Status: $_status'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Remote users (${_remoteUsers.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _remoteUsers.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(_remoteUsers[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
