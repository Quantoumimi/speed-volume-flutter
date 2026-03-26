import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const SpeedVolumeApp());
}

class SpeedVolumeApp extends StatelessWidget {
  const SpeedVolumeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speed Volume',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SpeedVolumeHome(),
    );
  }
}

class SpeedVolumeHome extends StatefulWidget {
  const SpeedVolumeHome({super.key});

  @override
  State<SpeedVolumeHome> createState() => _SpeedVolumeHomeState();
}

class _SpeedVolumeHomeState extends State<SpeedVolumeHome> {
  // 状态变量
  double _currentSpeed = 0.0;       // 当前速度 km/h
  double _currentVolume = 0.0;      // 当前音量 0.0~1.0
  bool _isTracking = false;         // 是否正在追踪
  bool _isPlaying = false;          // 是否正在播放
  String _statusText = '点击开始追踪';
  String _locationStatus = '未定位';

  // 速度历史（用于显示趋势）
  final List<double> _speedHistory = [];

  // GPS流订阅
  StreamSubscription<Position>? _positionStream;

  // 音频播放器
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 音量控制
  final VolumeController _volumeController = VolumeController();

  // 速度范围
  static const double _maxSpeed = 200.0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// 请求权限
  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.bluetoothConnect,
    ].request();
  }

  /// 速度转音量（核心算法）
  /// 速度 0 → 音量 0
  /// 速度 50 km/h → 音量 90% (0.9)
  /// 速度 200 km/h → 音量 100% (1.0)
  double _speedToVolume(double speed) {
    if (speed <= 0) return 0.0;
    double volume = (speed / _maxSpeed).clamp(0.0, 1.0);
    return volume;
  }

  /// 开始GPS追踪
  Future<void> _startTracking() async {
    // 检查权限
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('需要位置权限才能获取速度');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('请在设置中开启位置权限');
      return;
    }

    // 检查GPS是否开启
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('请开启GPS定位服务');
      return;
    }

    setState(() {
      _isTracking = true;
      _statusText = '正在追踪...';
      _locationStatus = '定位中...';
    });

    // 开始播放音乐
    await _startMusic();

    // 订阅GPS位置流
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        _showSnackBar('GPS错误: $error');
      },
    );
  }

  /// 停止GPS追踪
  Future<void> _stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;

    await _stopMusic();

    // 音量归零
    await _volumeController.setVolume(0);

    setState(() {
      _isTracking = false;
      _currentSpeed = 0.0;
      _currentVolume = 0.0;
      _statusText = '已停止';
      _locationStatus = '未定位';
    });
  }

  /// GPS位置更新回调
  void _onPositionUpdate(Position position) {
    // 获取速度（m/s → km/h）
    double speedKmh = (position.speed * 3.6).clamp(0.0, _maxSpeed);

    // 计算对应音量
    double volume = _speedToVolume(speedKmh);

    // 更新系统音量
    _volumeController.setVolume(volume);

    // 如果速度为0，暂停播放；否则继续播放
    if (speedKmh < 0.5 && _isPlaying) {
      _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else if (speedKmh >= 0.5 && !_isPlaying) {
      _audioPlayer.resume();
      setState(() => _isPlaying = true);
    }

    // 更新历史
    _speedHistory.add(speedKmh);
    if (_speedHistory.length > 60) _speedHistory.removeAt(0);

    setState(() {
      _currentSpeed = speedKmh;
      _currentVolume = volume;
      _locationStatus = '已定位 (精度: ${position.accuracy.toStringAsFixed(0)}m)';
    });
  }

  /// 开始播放音乐
  Future<void> _startMusic() async {
    try {
      // 播放内置音频（可替换为用户选择的音乐）
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('music/background.mp3'));
      setState(() => _isPlaying = true);
    } catch (e) {
      // 如果没有音频文件，使用系统音频
      debugPrint('音频播放错误: $e');
    }
  }

  /// 停止播放音乐
  Future<void> _stopMusic() async {
    await _audioPlayer.stop();
    setState(() => _isPlaying = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 顶部标题
              _buildHeader(),
              const SizedBox(height: 30),

              // 速度大表盘
              _buildSpeedometer(),
              const SizedBox(height: 30),

              // 音量显示
              _buildVolumeBar(),
              const SizedBox(height: 20),

              // 状态信息
              _buildStatusInfo(),
              const Spacer(),

              // 控制按钮
              _buildControlButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Speed Volume',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _locationStatus,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        // 播放状态图标
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isPlaying
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isPlaying ? Icons.music_note : Icons.music_off,
            color: _isPlaying ? Colors.green : Colors.grey,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedometer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1565C0).withOpacity(0.3),
            const Color(0xFF0D47A1).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF1565C0).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '当前速度',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currentSpeed.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  ' km/h',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 速度进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentSpeed / _maxSpeed).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getSpeedColor(_currentSpeed),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              Text('50', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              Text('100', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              Text('150', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              Text('200', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeBar() {
    int volumePercent = (_currentVolume * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getVolumeIcon(volumePercent),
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '音量',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '$volumePercent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _currentVolume,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getVolumeColor(volumePercent),
              ),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: Icons.speed,
            label: '最高速度',
            value: _speedHistory.isEmpty
                ? '0'
                : '${_speedHistory.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)} km/h',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.bluetooth_audio,
            label: '蓝牙状态',
            value: '已连接',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.gps_fixed,
            label: 'GPS状态',
            value: _isTracking ? '追踪中' : '未启动',
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton() {
    return GestureDetector(
      onTap: _isTracking ? _stopTracking : _startTracking,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isTracking
                ? [const Color(0xFFE53935), const Color(0xFFB71C1C)]
                : [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_isTracking ? Colors.red : const Color(0xFF1565C0))
                  .withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              _isTracking ? '停止追踪' : '开始追踪',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSpeedColor(double speed) {
    if (speed < 30) return Colors.green;
    if (speed < 80) return Colors.yellow;
    if (speed < 120) return Colors.orange;
    return Colors.red;
  }

  Color _getVolumeColor(int percent) {
    if (percent < 30) return Colors.blue;
    if (percent < 60) return Colors.cyan;
    if (percent < 80) return Colors.green;
    return Colors.orange;
  }

  IconData _getVolumeIcon(int percent) {
    if (percent == 0) return Icons.volume_off;
    if (percent < 30) return Icons.volume_mute;
    if (percent < 70) return Icons.volume_down;
    return Icons.volume_up;
  }
}
