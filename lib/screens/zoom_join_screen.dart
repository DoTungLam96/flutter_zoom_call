import 'package:flutter/material.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_event_listener.dart';
import 'package:vtb_video_call/config/config.dart';
import 'package:vtb_video_call/config/zoom_jwt_helper.dart';
import 'package:vtb_video_call/screens/zoom_call_screen.dart';

class ZoomJoinScreen extends StatefulWidget {
  const ZoomJoinScreen({super.key});

  @override
  State<ZoomJoinScreen> createState() => _ZoomJoinScreenState();
}

class _ZoomJoinScreenState extends State<ZoomJoinScreen> {
  final ZoomVideoSdk _zoom = ZoomVideoSdk();
  final ZoomVideoSdkEventListener _listener = ZoomVideoSdkEventListener();

  final TextEditingController _sessionNameController = TextEditingController(text: defaultSessionName);
  final TextEditingController _displayNameController = TextEditingController(text: defaultDisplayName);

  bool _sdkReady = false;
  bool _joining = false;
  bool _navigatedToCall = false;
  String _status = 'Chưa khởi tạo SDK';

  @override
  void initState() {
    super.initState();
    _bindEvents();
    _initSdk();
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
      debugPrint('onSessionJoin: $data');

      if (!mounted) return;

      setState(() {
        _joining = false;
        _status = 'Đã join session';
      });

      if (_navigatedToCall) return;
      _navigatedToCall = true;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ZoomCallScreen(
            zoom: _zoom,
            listener: _listener,
            sessionName: _sessionNameController.text.trim(),
            displayName: _displayNameController.text.trim(),
          ),
        ),
      );

      if (!mounted) return;
      _navigatedToCall = false;
    });

    _listener.addListener(EventType.onSessionLeave, (data) {
      debugPrint('onSessionLeave: $data');

      if (!mounted) return;
      setState(() {
        _joining = false;
        _status = 'Đã rời session';
      });
    });

    _listener.addListener(EventType.onError, (data) {
      debugPrint('onError: $data');

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
        _status = 'Vui lòng nhập session name và display name';
      });
      return;
    }

    final token = ZoomJwtHelper.generateVideoSdkJwt(
      sessionName: sessionName,
      userIdentity: displayName,
      roleType: 1,
    );

    debugPrint('sessionName=$sessionName');
    debugPrint('displayName=$displayName');
    debugPrint('generatedToken=$token');

    setState(() {
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
      debugPrint('joinSession catch: $e');

      if (!mounted) return;
      setState(() {
        _joining = false;
        _status = 'Join lỗi: $e';
      });
    }
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
  }) {
    return TextField(
      controller: controller,
      enabled: !_joining,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập cuộc gọi'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nhập thông tin tham gia',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        label: 'Session name',
                        controller: _sessionNameController,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Display name',
                        controller: _displayNameController,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _joining ? null : _joinSession,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _joining
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Text('Join'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Status: $_status',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _sdkReady ? 'SDK ready' : 'SDK chưa sẵn sàng',
                          style: TextStyle(
                            color: _sdkReady ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
