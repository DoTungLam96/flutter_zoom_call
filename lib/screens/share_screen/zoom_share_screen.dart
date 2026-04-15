import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_event_listener.dart';

class ZoomShareScreen extends StatefulWidget {
  final ZoomVideoSdk zoom;
  final ZoomVideoSdkEventListener listener;

  const ZoomShareScreen({
    super.key,
    required this.zoom,
    required this.listener,
  });

  @override
  State<ZoomShareScreen> createState() => _ZoomShareScreenState();
}

class _ZoomShareScreenState extends State<ZoomShareScreen> {
  bool _isSharing = false;
  bool _isStarting = false;
  final List<String> _logs = [];
  StreamSubscription? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _bindEvents();
  }

  void _log(String message) {
    debugPrint('LamDT: $message');
    if (!mounted) return;
    setState(() {
      _logs.insert(0, message);
    });
  }

  void _bindEvents() {
    _shareSubscription = widget.listener.addListener(
      EventType.onUserShareStatusChanged,
      (data) async {
        _log('[share_event] raw = $data');

        if (!mounted) return;
        setState(() {
          _isStarting = false;
          _isSharing = true;
        });
      },
    );

    widget.listener.addListener(EventType.onError, (data) {
      _log('[zoom_error] $data');
    });

    widget.listener.addListener(EventType.onSessionLeave, (data) {
      _log('[session_leave] $data');
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  Future<void> _startShare() async {
    try {
      _log('[start] tapped');

      final shareHelper = widget.zoom.shareHelper;

      final isOtherSharing = await shareHelper.isOtherSharing();
      final isShareLocked = await shareHelper.isShareLocked();

      _log('[start] isOtherSharing = $isOtherSharing');
      _log('[start] isShareLocked = $isShareLocked');

      if (isOtherSharing) {
        _log('[start] blocked: another user is sharing');
        return;
      }

      if (isShareLocked) {
        _log('[start] blocked: share is locked');
        return;
      }

      if (!mounted) return;
      setState(() {
        _isStarting = true;
      });

      _log('[start] calling shareScreen()');

      unawaited(
        shareHelper.shareScreen().then((_) {
          _log('[start] shareScreen() returned');
        }).catchError((e, s) {
          _log('[start] shareScreen() error = $e');
          if (!mounted) return;
          setState(() {
            _isStarting = false;
            _isSharing = false;
          });
        }),
      );

      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        if (!_isSharing) {
          _log('[start] timeout: no share event after 5s');
          setState(() {
            _isStarting = false;
          });
        }
      });
    } catch (e) {
      _log('[start] exception = $e');
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _isSharing = false;
      });
    }
  }

  Future<void> _stopShare() async {
    try {
      _log('[stop] tapped');
      await widget.zoom.shareHelper.stopShare();
      _log('[stop] stopShare() returned');

      if (!mounted) return;
      setState(() {
        _isSharing = false;
        _isStarting = false;
      });
    } catch (e) {
      _log('[stop] exception = $e');
    }
  }

  Future<void> _toggleShare() async {
    if (_isStarting) return;
    if (_isSharing) {
      await _stopShare();
    } else {
      await _startShare();
    }
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = _isSharing
        ? 'Stop Share'
        : _isStarting
            ? 'Starting...'
            : 'Start Share';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zoom Share Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _isSharing
                        ? 'Screen sharing is active'
                        : _isStarting
                            ? 'Starting screen share...'
                            : 'Screen sharing is idle',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _toggleShare,
                      child: Text(buttonText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Logs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: _logs.isEmpty
                    ? const Text('No logs yet')
                    : ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, index) {
                          return Text(
                            _logs[index],
                            style: const TextStyle(fontSize: 13),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
