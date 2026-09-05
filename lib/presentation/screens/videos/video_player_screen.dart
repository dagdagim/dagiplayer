import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/subtitle_track.dart';
import '../../../domain/entities/video.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/media_provider.dart';
import '../../../services/video/pip_service.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;
  final Video? initialVideo;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    this.initialVideo,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  Video? _currentVideo;
  bool _areControlsVisible = true;
  bool _isLocked = false;
  bool _isLandscape = false;
  bool _isInPipMode = false;
  StreamSubscription<bool>? _pipSub;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _hideTimer;
  double _volume = 0.8;
  double _brightness = 0.7;
  String _activeGestureText = '';
  Timer? _gestureIndicatorTimer;

  // Subtitles
  SubtitleTrack? _selectedSubtitle;
  final List<SubtitleItem> _currentSubtitleItems = [];
  String _activeSubtitleText = '';

  @override
  void initState() {
    super.initState();
    // Stop any ongoing music playback when opening video player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(audioPlaybackNotifierProvider.notifier).pause();
      }
    });

    _pipSub = PipService.instance.pipStateStream.listen((inPip) {
      if (mounted) {
        setState(() {
          _isInPipMode = inPip;
          if (inPip) {
            _areControlsVisible = false;
          }
        });
      }
    });

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    Video? video = widget.initialVideo;

    if (video == null) {
      try {
        final allVideos = await ref.read(allVideosProvider.future);
        video = allVideos.where((v) => v.id == widget.videoId).firstOrNull;
      } catch (_) {}

      if (video == null) {
        try {
          final repoVideos = await ref.read(mediaRepositoryProvider).getAllVideos();
          video = repoVideos.where((v) => v.id == widget.videoId).firstOrNull;
        } catch (_) {}
      }
    }

    if (!mounted) return;

    if (video == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video file not found or removed from device storage.';
      });
      return;
    }

    setState(() {
      _currentVideo = video;
    });

    // Pause background audio to prevent audio decoder/sink resource conflict on low-end devices
    try {
      if (AudioPlayerService.instance.state.isPlaying) {
        await AudioPlayerService.instance.pause();
      }
    } catch (_) {}

    try {
      if (video.uri.startsWith('http://') || video.uri.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(video.uri),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await _controller!.initialize();
      } else if (video.uri.startsWith('asset://') || video.uri.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(
          video.uri.replaceFirst('asset://', ''),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await _controller!.initialize();
      } else {
        // Multi-tier initialization for local videos across all Android versions (API 24-36)
        final cleanPath = video.uri.replaceFirst('file://', '');
        final fileExists = cleanPath.isNotEmpty && !cleanPath.startsWith('content://') && File(cleanPath).existsSync();

        String? contentUri;
        if (video.uri.startsWith('content://')) {
          contentUri = video.uri;
        } else if (!kIsWeb && Platform.isAndroid && video.id.startsWith('media-vid-')) {
          final mediaId = video.id.replaceFirst('media-vid-', '');
          contentUri = 'content://media/external/video/media/$mediaId';
        }

        // Candidates:
        // On older Android (API < 30) or when direct file exists on disk, file() is much more reliable
        // On Scoped Storage Android (API 30+), contentUri is primary fallback
        final controllersToTry = <VideoPlayerController Function()>[];

        if (fileExists) {
          controllersToTry.add(() => VideoPlayerController.file(
                File(cleanPath),
                videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
              ));
        }

        if (contentUri != null) {
          controllersToTry.add(() => VideoPlayerController.contentUri(
                Uri.parse(contentUri!),
                videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
              ));
        }

        if (!fileExists && cleanPath.isNotEmpty && !cleanPath.startsWith('content://')) {
          controllersToTry.add(() => VideoPlayerController.file(
                File(cleanPath),
                videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
              ));
        }

        Object? lastError;
        bool initialized = false;

        for (final createCtrl in controllersToTry) {
          try {
            final ctrl = createCtrl();
            await ctrl.initialize();
            _controller = ctrl;
            initialized = true;
            break;
          } catch (err) {
            lastError = err;
            debugPrint('Video controller initialization attempt failed: $err');
          }
        }

        if (!initialized) {
          throw lastError ?? Exception('Could not initialize video playback for ${video.title}');
        }
      }

      if (!mounted) return;

      if (video.hasResumePosition && video.lastPosition > Duration.zero) {
        await _controller!.seekTo(video.lastPosition);
      }
      try {
        await _controller!.play();
        WakelockPlus.enable();

        final aspect = _controller!.value.aspectRatio;
        final num = (aspect * 100).toInt();
        PipService.instance.setAutoPip(
          enabled: true,
          aspectRatioX: num > 0 ? num : 16,
          aspectRatioY: 100,
        );
      } catch (_) {}

      if (!mounted) return;

      _controller!.addListener(_onPlayerUpdate);
      _startHideTimer();
      setState(() {});
    } catch (e) {
      debugPrint('Video player native initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unable to play video: $e';
        });
      }
    }
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    if (_controller == null) return;
    if (_controller!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _controller!.value.errorDescription ?? 'Playback error encountered';
      });
      WakelockPlus.disable();
      return;
    }

    if (!_controller!.value.isInitialized) return;

    if (_controller!.value.isPlaying) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    final pos = _controller!.value.position;

    // Update active subtitle
    if (_selectedSubtitle != null && _currentSubtitleItems.isNotEmpty) {
      final match = _currentSubtitleItems.where(
        (sub) => pos >= sub.startTime && pos <= sub.endTime,
      );
      final newText = match.isNotEmpty ? match.first.text : '';
      if (newText != _activeSubtitleText && mounted) {
        setState(() {
          _activeSubtitleText = newText;
        });
      }
    }

    // Save position periodically
    if (mounted) {
      ref.read(mediaActionControllerProvider).updateVideoPosition(widget.videoId, pos);
      setState(() {});
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (!_isLocked) {
        final isPlaying = _controller?.value.isPlaying ?? false;
        if (isPlaying && mounted) {
          setState(() {
            _areControlsVisible = false;
          });
        }
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    if (_isLocked) {
      setState(() {
        _areControlsVisible = !_areControlsVisible;
      });
      _startHideTimer();
      return;
    }

    setState(() {
      _areControlsVisible = !_areControlsVisible;
    });
    if (_areControlsVisible) {
      _startHideTimer();
    }
  }

  void _showGestureFeedback(String text) {
    if (!mounted) return;
    _gestureIndicatorTimer?.cancel();
    setState(() {
      _activeGestureText = text;
    });
    _gestureIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _activeGestureText = '';
        });
      }
    });
  }

  void _togglePlayPause() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      WakelockPlus.disable();
      PipService.instance.setAutoPip(enabled: false);
    } else {
      _controller!.play();
      WakelockPlus.enable();
      final aspect = _controller!.value.aspectRatio;
      final num = (aspect * 100).toInt();
      PipService.instance.setAutoPip(
        enabled: true,
        aspectRatioX: num > 0 ? num : 16,
        aspectRatioY: 100,
      );
    }
    _startHideTimer();
    setState(() {});
  }

  void _enterPipMode() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final aspect = _controller!.value.aspectRatio;
    final num = (aspect * 100).toInt();
    PipService.instance.enterPip(
      aspectRatioX: num > 0 ? num : 16,
      aspectRatioY: 100,
    );
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _showGestureFeedback('Landscape Mode');
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _showGestureFeedback('Portrait Mode');
    }
  }

  void _seekTo(Duration position) {
    if (!mounted || _controller == null) return;
    _controller?.seekTo(position);
    _startHideTimer();
  }

  @override
  void dispose() {
    _pipSub?.cancel();
    PipService.instance.setAutoPip(enabled: false);
    _hideTimer?.cancel();
    _gestureIndicatorTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    try {
      _controller?.removeListener(_onPlayerUpdate);
      _controller?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNativeInitialized = _controller != null && _controller!.value.isInitialized && !_controller!.value.hasError;

    // Minimal PiP mode view without any UI chrome/bars
    if (_isInPipMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: isNativeInitialized
              ? AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(
            _currentVideo?.title ?? 'Video Player',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.primary,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to Play Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage.isNotEmpty ? _errorMessage : 'The file could not be decoded or loaded.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isPlaying = isNativeInitialized && _controller!.value.isPlaying;
    final position = isNativeInitialized ? _controller!.value.position : Duration.zero;
    final duration = isNativeInitialized ? _controller!.value.duration : (_currentVideo?.duration ?? Duration.zero);
    final videoTitle = _currentVideo?.title ?? 'Video Player';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTapDown: (details) {
          if (_isLocked) return;
          final x = details.localPosition.dx;
          if (x < size.width / 2) {
            // Seek -10s
            final newPos = position - const Duration(seconds: 10);
            _seekTo(newPos > Duration.zero ? newPos : Duration.zero);
            _showGestureFeedback('-10s');
          } else {
            // Seek +10s
            final newPos = position + const Duration(seconds: 10);
            _seekTo(newPos < duration ? newPos : duration);
            _showGestureFeedback('+10s');
          }
        },
        onLongPressStart: (_) {
          if (_isLocked) return;
          if (isNativeInitialized) _controller?.setPlaybackSpeed(2.0);
          _showGestureFeedback('2x Speed');
        },
        onLongPressEnd: (_) {
          if (_isLocked) return;
          if (isNativeInitialized) _controller?.setPlaybackSpeed(1.0);
        },
        onVerticalDragUpdate: (details) {
          if (_isLocked) return;
          final delta = details.primaryDelta ?? 0;
          final x = details.localPosition.dx;

          if (x < size.width / 2) {
            // Brightness (Left side)
            if (mounted) {
              setState(() {
                _brightness = (_brightness - delta / 250).clamp(0.0, 1.0);
              });
            }
            _showGestureFeedback('Brightness: ${(_brightness * 100).toInt()}%');
          } else {
            // Volume (Right side)
            if (mounted) {
              setState(() {
                _volume = (_volume - delta / 250).clamp(0.0, 1.0);
                _controller?.setVolume(_volume);
              });
            }
            _showGestureFeedback('Volume: ${(_volume * 100).toInt()}%');
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Display Layer
            Center(
              child: isNativeInitialized
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
            ),

            // Subtitles Overlay
            if (_activeSubtitleText.isNotEmpty)
              Positioned(
                bottom: _areControlsVisible ? 100 : 36,
                left: 24,
                right: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(200),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Text(
                      _activeSubtitleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

            // Gesture Feedback Toast Overlay
            if (_activeGestureText.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(210),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                  child: Text(
                    _activeGestureText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // Controls Overlay
            if (_areControlsVisible)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _areControlsVisible ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withAlpha(120),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Bar
                        _buildTopBar(context, videoTitle),

                        // Center Play / 10s Seek Controls
                        if (!_isLocked)
                          _buildCenterControls(isPlaying, position, duration)
                        else
                          const SizedBox.shrink(),

                        // Bottom Controls Bar
                        if (!_isLocked)
                          _buildBottomBar(position, duration, isPlaying)
                        else
                          _buildLockedBottomBar(),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String videoTitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              videoTitle,
              style: AppTypography.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Orientation toggle button (Top Bar)
          IconButton(
            icon: Icon(
              _isLandscape ? Icons.screen_lock_portrait_rounded : Icons.screen_lock_landscape_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleOrientation,
            tooltip: _isLandscape ? 'Switch to Portrait' : 'Switch to Landscape',
          ),
          // Picture-in-Picture Button (Top Bar)
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
            onPressed: _enterPipMode,
            tooltip: 'Picture-in-Picture (Floating Window)',
          ),
          IconButton(
            icon: const Icon(Icons.cast_rounded, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scanning for Cast devices...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: _showVideoSettingsSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(bool isPlaying, Duration position, Duration duration) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -10s Seek
        IconButton(
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
          onPressed: () {
            final newPos = position - const Duration(seconds: 10);
            _seekTo(newPos > Duration.zero ? newPos : Duration.zero);
          },
        ),
        const SizedBox(width: 36),

        // Main Center Play / Pause Button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.primary,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(width: 36),

        // +10s Seek
        IconButton(
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
          onPressed: () {
            final newPos = position + const Duration(seconds: 10);
            _seekTo(newPos < duration ? newPos : duration);
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(Duration position, Duration duration, bool isPlaying) {
    final posMs = position.inMilliseconds.toDouble();
    final durMs = duration.inMilliseconds.toDouble();
    final sliderVal = posMs.clamp(0.0, durMs > 0 ? durMs : 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress Slider & Timestamps
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
          child: Row(
            children: [
              Text(
                Formatters.formatDuration(position),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: AppColors.primary,
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(
                    value: sliderVal,
                    min: 0.0,
                    max: durMs > 0 ? durMs : 1.0,
                    onChanged: (val) {
                      _seekTo(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
              ),
              Text(
                Formatters.formatDuration(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        // Controls: Lock, Audio, Orange Play/Pause, Subtitles, Rotate/Fullscreen, More
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.sm, left: 16, right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 22),
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _isLocked = true;
                    });
                  }
                  _showGestureFeedback('Controls Locked');
                },
                tooltip: 'Lock',
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 22),
                onPressed: _showAudioTracksSheet,
                tooltip: 'Audio',
              ),
              // Play/Pause Action Circle
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.subtitles_rounded, color: Colors.white70, size: 22),
                onPressed: _showSubtitlesSheet,
                tooltip: 'Subtitles',
              ),
              // Landscape / Fullscreen toggle button
              IconButton(
                icon: Icon(
                  _isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: _toggleOrientation,
                tooltip: _isLandscape ? 'Exit Fullscreen' : 'Landscape Fullscreen',
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 22),
                onPressed: _showVideoSettingsSheet,
                tooltip: 'More',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockedBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () {
            if (mounted) {
              setState(() {
                _isLocked = false;
              });
            }
            _startHideTimer();
            _showGestureFeedback('Controls Unlocked');
          },
          icon: const Icon(Icons.lock_open_rounded, color: AppColors.primary),
          label: const Text('Unlock Controls', style: TextStyle(color: Colors.white)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
            backgroundColor: Colors.black54,
          ),
        ),
      ),
    );
  }

  void _showSubtitlesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final languages = ['Off', 'English', 'Amharic', 'Arabic', 'French', 'Spanish'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Subtitles',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              ...languages.map((lang) {
                final isSelected = (_selectedSubtitle?.label == lang) ||
                    (lang == 'Off' && _selectedSubtitle == null);
                return ListTile(
                  title: Text(lang, style: const TextStyle(color: Colors.white)),
                  trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        if (lang == 'Off') {
                          _selectedSubtitle = null;
                          _activeSubtitleText = '';
                        } else {
                          _selectedSubtitle = SubtitleTrack(
                            id: lang.toLowerCase(),
                            label: lang,
                            languageCode: lang.toLowerCase().substring(0, 2),
                            items: _currentSubtitleItems,
                          );
                        }
                      });
                    }
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showAudioTracksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Audio Tracks',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const ListTile(
              title: Text('English (Original 5.1 Surround)', style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.check_rounded, color: AppColors.primary),
            ),
            const ListTile(
              title: Text('Amharic (Stereo)', style: TextStyle(color: Colors.white70)),
            ),
            const ListTile(
              title: Text('French (Stereo)', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Playback Settings',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: Icon(
                _isLandscape ? Icons.screen_lock_portrait_rounded : Icons.screen_lock_landscape_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                _isLandscape ? 'Switch to Portrait' : 'Switch to Landscape (Fullscreen)',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleOrientation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded, color: AppColors.primary),
              title: const Text('Playback Speed', style: TextStyle(color: Colors.white)),
              trailing: Text(
                '${_controller?.value.playbackSpeed ?? 1.0}x',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showSpeedSelector();
              },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_rounded, color: AppColors.primary),
              title: const Text('Aspect Ratio (Fit / Zoom / Stretch)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showGestureFeedback('Aspect Ratio: 16:9 Fit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_in_picture_alt_rounded, color: AppColors.primary),
              title: const Text('Picture-in-Picture (Floating Window)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _enterPipMode();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedSelector() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Playback Speed'),
        children: speeds.map((spd) {
          final isCurrent = _controller?.value.playbackSpeed == spd;
          return SimpleDialogOption(
            onPressed: () {
              _controller?.setPlaybackSpeed(spd);
              Navigator.pop(ctx);
              _showGestureFeedback('Speed: ${spd}x');
            },
            child: Text(
              '${spd}x ${spd == 1.0 ? '(Normal)' : ''}',
              style: TextStyle(
                color: isCurrent ? AppColors.primary : null,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
