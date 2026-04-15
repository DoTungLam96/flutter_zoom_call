import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_event_listener.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_share_action.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_user.dart';
import 'package:vtb_video_call/screens/share_screen/zoom_share_screen.dart';
import 'package:vtb_video_call/screens/widgets/zoom_video_view.dart';

class ZoomCallScreen extends StatefulWidget {
  final ZoomVideoSdk zoom;
  final ZoomVideoSdkEventListener listener;
  final String sessionName;
  final String displayName;

  const ZoomCallScreen({
    super.key,
    required this.zoom,
    required this.listener,
    required this.sessionName,
    required this.displayName,
  });

  @override
  State<ZoomCallScreen> createState() => _ZoomCallScreenState();
}

class _ZoomCallScreenState extends State<ZoomCallScreen> {
  ZoomVideoSdkUser? _mySelf;
  List<ZoomVideoSdkUser> _users = [];
  ZoomVideoSdkUser? _fullScreenUser;
  ZoomVideoSdkUser? _sharingUser;

  bool _isShareStarting = false;

  bool _isMuted = false;
  bool _isVideoOn = true;
  bool _isSpeakerOn = true;
  bool _controlsVisible = true;
  bool _isSharing = false;

  Timer? _callTimer;
  int _callSeconds = 0;

  @override
  void initState() {
    super.initState();

    _loadInitialState();
    _startTimer();
    _bindEvents();
  }

  Future<void> _loadInitialState() async {
    try {
      final mySelf = await widget.zoom.session.getMySelf();
      final remoteUsers = await widget.zoom.session.getRemoteUsers();
      final speakerOn = await widget.zoom.audioHelper.getSpeakerStatus();

      bool muted = false;
      bool videoOn = true;

      if (mySelf?.audioStatus != null) {
        muted = await mySelf!.audioStatus!.isMuted() ?? false;
      }

      if (mySelf?.videoStatus != null) {
        videoOn = await mySelf!.videoStatus!.isOn() ?? true;
      }

      final allUsers = <ZoomVideoSdkUser>[
        if (remoteUsers != null) ...remoteUsers,
      ];

      ZoomVideoSdkUser? fullUser;
      if (allUsers.isNotEmpty) {
        fullUser = allUsers.first;
      } else {
        fullUser = mySelf;
      }

      if (!mounted) return;
      setState(() {
        _mySelf = mySelf;
        _users = allUsers;
        _fullScreenUser = fullUser;
        _isMuted = muted;
        _isVideoOn = videoOn;
        _isSpeakerOn = speakerOn;
      });
    } catch (e) {
      print('LamDT: loadInitialState error: $e');
    }
  }

  void _bindEvents() {
    widget.listener.addListener(EventType.onUserJoin, (data) async {
      await _refreshUsers();
    });

    widget.listener.addListener(EventType.onUserShareStatusChanged, (data) async {
      print('LamDT: [share_event] raw=$data');
      await _handleShareStatusChanged(data);
    });

    widget.listener.addListener(EventType.onUserLeave, (data) async {
      await _refreshUsers();
    });

    widget.listener.addListener(EventType.onSessionLeave, (data) {
      if (!mounted) return;
      Navigator.of(context).pop();
    });

    widget.listener.addListener(EventType.onError, (data) {
      print('LamDT: Zoom error: $data');
    });
  }

  Future<void> _handleShareStatusChanged(dynamic data) async {
    try {
      print('LamDT: [share_event] raw=$data');

      data = data as Map;
      final mySelf = await widget.zoom.session.getMySelf();
      if (mySelf == null || !mounted) return;

      final shareUser = ZoomVideoSdkUser.fromJson(
        jsonDecode(data['user'].toString()),
      );

      final shareAction = ZoomVideoSdkShareAction.fromJson(
        jsonDecode(data['shareAction'].toString()),
      );

      final started = shareAction.shareStatus == ShareStatus.Start || shareAction.shareStatus == ShareStatus.Resume;

      if (started) {
        setState(() {
          _sharingUser = shareUser;
          _fullScreenUser = shareUser;
          _isSharing = shareUser.userId == mySelf.userId;
          _isShareStarting = false;
        });
      } else {
        setState(() {
          _sharingUser = null;
          _isSharing = false;
          _isShareStarting = false;
          _fullScreenUser = _users.isNotEmpty ? _users.first : _mySelf;
        });
      }
    } catch (e) {
      print('LamDT: handleShareStatusChanged error: $e');
    }
  }

  Future<void> _refreshUsers() async {
    try {
      final remoteUsers = await widget.zoom.session.getRemoteUsers();
      final list = <ZoomVideoSdkUser>[
        if (remoteUsers != null) ...remoteUsers,
      ];

      ZoomVideoSdkUser? nextFullScreen = _fullScreenUser;

      if (nextFullScreen == null || !_containsUser(list, nextFullScreen.userId)) {
        nextFullScreen = list.isNotEmpty ? list.first : _mySelf;
      }

      if (!mounted) return;
      setState(() {
        _users = list;
        _fullScreenUser = nextFullScreen;
      });
    } catch (e) {
      print('LamDT: refreshUsers error: $e');
    }
  }

  bool _containsUser(List<ZoomVideoSdkUser> users, String? userId) {
    if (userId == null) return false;
    return users.any((u) => u.userId == userId);
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _callSeconds++;
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggleMute() async {
    try {
      final mySelf = await widget.zoom.session.getMySelf();
      final userId = mySelf?.userId;

      if (userId == null || userId.isEmpty) return;

      if (_isMuted) {
        await widget.zoom.audioHelper.unMuteAudio(userId);
      } else {
        await widget.zoom.audioHelper.muteAudio(userId);
      }

      if (!mounted) return;
      setState(() {
        _isMuted = !_isMuted;
      });
    } catch (e) {
      print('LamDT: toggleMute error: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    try {
      final nextValue = !_isSpeakerOn;
      await widget.zoom.audioHelper.setSpeaker(nextValue);

      if (!mounted) return;
      setState(() {
        _isSpeakerOn = nextValue;
      });
    } catch (e) {
      print('LamDT: toggleSpeaker error: $e');
    }
  }

  Future<void> _toggleVideo() async {
    try {
      if (_isVideoOn) {
        await widget.zoom.videoHelper.stopVideo();
      } else {
        await widget.zoom.videoHelper.startVideo();
      }

      if (!mounted) return;
      setState(() {
        _isVideoOn = !_isVideoOn;
      });
    } catch (e) {
      print('LamDT: toggleVideo error: $e');
    }
  }

  Future<void> _toggleShareScreen() async {
    try {
      final shareHelper = widget.zoom.shareHelper;

      if (_isShareStarting) return;

      if (_isSharing) {
        await shareHelper.stopShare();
        if (!mounted) return;
        setState(() {
          _isSharing = false;
          _isShareStarting = false;
          _sharingUser = null;
          _fullScreenUser = _users.isNotEmpty ? _users.first : _mySelf;
        });
        return;
      }

      final isOtherSharing = await shareHelper.isOtherSharing();
      final isShareLocked = await shareHelper.isShareLocked();

      if (isOtherSharing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang có người khác share màn hình')),
        );
        return;
      }

      if (isShareLocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host đang khóa share màn hình')),
        );
        return;
      }

      setState(() {
        _isShareStarting = true;
      });

      unawaited(
        shareHelper.shareScreen().catchError((e, s) {
          print('LamDT: shareScreen async error: $e');
          print('LamDT: $s');

          if (!mounted) return;
          setState(() {
            _isShareStarting = false;
            _isSharing = false;
          });
        }),
      );
    } catch (e) {
      print('LamDT: toggleShareScreen error: $e');
      if (!mounted) return;
      setState(() {
        _isShareStarting = false;
        _isSharing = false;
      });
    }
  }

  Future<void> _leaveSession() async {
    try {
      if (_isSharing) {
        try {
          await widget.zoom.shareHelper.stopShare();
        } catch (_) {}
      }

      await widget.zoom.leaveSession(false);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      print('LamDT: leaveSession error: $e');
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildRemoteFullScreen() {
    final userToShow = _sharingUser ?? _fullScreenUser;

    if (userToShow == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          'Đang chờ người tham gia...',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ZoomVideoView(
      user: userToShow,
      fullScreen: true,
      sharing: _sharingUser?.userId == userToShow.userId,
      videoAspect: VideoAspect.FullFilled,
    );
  }

  Widget _buildLocalPreview() {
    if (_mySelf == null) return const SizedBox.shrink();

    return Positioned(
      top: 60,
      right: 16,
      child: SizedBox(
        width: 110,
        height: 160,
        child: ZoomVideoView(
          user: _mySelf,
          fullScreen: false,
          sharing: false,
          videoAspect: VideoAspect.FullFilled,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildTopTimer() {
    return Positioned(
      top: 70,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              Text(
                _formatDuration(_callSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.displayName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (_isSharing) ...[
                const SizedBox(height: 6),
                const Text(
                  'Đang share màn hình',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible,
          child: SafeArea(
            top: false,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 18,
              children: [
                _buildBottomButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: 'Mic',
                  bgColor: _isMuted ? Colors.grey : Colors.white24,
                  onTap: _toggleMute,
                ),
                _buildBottomButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.hearing_disabled,
                  label: 'Speaker',
                  bgColor: _isSpeakerOn ? Colors.white24 : Colors.grey,
                  onTap: _toggleSpeaker,
                ),
                _buildBottomButton(
                  icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                  label: 'Camera',
                  bgColor: _isVideoOn ? Colors.white24 : Colors.grey,
                  onTap: _toggleVideo,
                ),
                _buildBottomButton(
                  icon: (_isSharing || _isShareStarting) ? Icons.stop_screen_share : Icons.screen_share,
                  label: _isSharing
                      ? 'Stop Share'
                      : _isShareStarting
                          ? 'Starting...'
                          : 'Share',
                  bgColor: (_isSharing || _isShareStarting) ? Colors.orange : Colors.white24,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ZoomShareScreen(
                          zoom: widget.zoom,
                          listener: widget.listener,
                        ),
                      ),
                    );
                  },
                ),
                _buildBottomButton(
                  icon: Icons.call_end,
                  label: 'Hang up',
                  bgColor: Colors.red,
                  onTap: _leaveSession,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          children: [
            Positioned.fill(child: _buildRemoteFullScreen()),
            _buildLocalPreview(),
            _buildTopTimer(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }
}
