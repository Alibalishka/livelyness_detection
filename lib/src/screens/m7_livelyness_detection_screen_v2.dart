import 'dart:async';

import 'package:m7_livelyness_detection/index.dart';

class M7LivelynessDetectionPageV2 extends StatefulWidget {
  final M7DetectionConfig config;
  final Widget text;
  final Color primaryColor;
  final TextStyle? styleTextHeader;

  const M7LivelynessDetectionPageV2({
    required this.config,
    required this.text,
    this.primaryColor = Colors.blue,
    this.styleTextHeader,
    super.key,
  });

  @override
  State<M7LivelynessDetectionPageV2> createState() =>
      _M7LivelynessDetectionPageV2State();
}

class _M7LivelynessDetectionPageV2State
    extends State<M7LivelynessDetectionPageV2> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F2F3),
      appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'Видео-идентификация',
            style: TextStyle(color: Colors.black),
          ),
          leading: GestureDetector(
            onTap: () => Navigator.of(context).pop(null),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Icon(Icons.close),
            ),
          )),
      body: SafeArea(
        child: M7LivelynessDetectionScreenV2(
          config: widget.config,
          text: widget.text,
          primaryColor: widget.primaryColor,
          styleTextHeader: widget.styleTextHeader,
        ),
      ),
    );
  }
}

class M7LivelynessDetectionScreenV2 extends StatefulWidget {
  final M7DetectionConfig config;
  final Widget text;
  final Color primaryColor;
  final TextStyle? styleTextHeader;

  const M7LivelynessDetectionScreenV2({
    required this.config,
    required this.text,
    required this.primaryColor,
    this.styleTextHeader,
    super.key,
  });

  @override
  State<M7LivelynessDetectionScreenV2> createState() =>
      _M7LivelynessDetectionScreenAndroidState();
}

class _M7LivelynessDetectionScreenAndroidState
    extends State<M7LivelynessDetectionScreenV2> {
  //* MARK: - Private Variables
  //? =========================================================
  final _faceDetectionController = BehaviorSubject<FaceDetectionModel>();

  final options = FaceDetectorOptions(
    enableContours: true,
    enableClassification: true,
    enableTracking: true,
    enableLandmarks: true,
    performanceMode: FaceDetectorMode.accurate,
    minFaceSize: 0.05,
  );
  late final faceDetector = FaceDetector(options: options);
  bool _didCloseEyes = false;
  bool _isProcessingStep = false;

  late final List<M7LivelynessStepItem> _steps;
  final GlobalKey<M7LivelynessDetectionStepOverlayState> _stepsKey =
      GlobalKey<M7LivelynessDetectionStepOverlayState>();

  CameraState? _cameraState;
  bool _isProcessing = false;
  late bool _isInfoStepCompleted;
  Timer? _timerToDetectFace;
  bool _isCaptureButtonVisible = false;
  bool _isCompleted = false;

  //* MARK: - Life Cycle Methods
  //? =========================================================
  @override
  void initState() {
    _preInitCallBack();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _postFrameCallBack(),
    );
  }

  @override
  void deactivate() {
    faceDetector.close();
    super.deactivate();
  }

  @override
  void dispose() {
    _faceDetectionController.close();
    _timerToDetectFace?.cancel();
    _timerToDetectFace = null;
    super.dispose();
  }

  //* MARK: - Private Methods for Business Logic
  //? =========================================================
  void _preInitCallBack() {
    _steps = widget.config.steps;
    _isInfoStepCompleted = !widget.config.startWithInfoScreen;
  }

  void _postFrameCallBack() {
    if (_isInfoStepCompleted) {
      _startTimer();
    }
  }

  Future<void> _processCameraImage(AnalysisImage img) async {
    if (_isProcessing) {
      return;
    }
    if (mounted) {
      setState(
        () => _isProcessing = true,
      );
    }
    final inputImage = img.toInputImage();

    try {
      final List<Face> detectedFaces =
          await faceDetector.processImage(inputImage);
      _faceDetectionController.add(
        FaceDetectionModel(
          faces: detectedFaces,
          absoluteImageSize: inputImage.metadata!.size,
          rotation: 0,
          imageRotation: img.inputImageRotation,
          croppedSize: img.croppedSize,
        ),
      );
      await _processImage(inputImage, detectedFaces);
      if (mounted) {
        setState(
          () => _isProcessing = false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _isProcessing = false,
        );
      }
      debugPrint("...sending image resulted error $error");
    }
  }

  Future<void> _processImage(InputImage img, List<Face> faces) async {
    try {
      if (faces.isEmpty) {
        _resetSteps();
        return;
      }
      final Face firstFace = faces.first;
      if (_isProcessingStep &&
          _steps[_stepsKey.currentState?.currentIndex ?? 0].step ==
              M7LivelynessStep.blink) {
        if (_didCloseEyes) {
          if ((faces.first.leftEyeOpenProbability ?? 1.0) < 0.75 &&
              (faces.first.rightEyeOpenProbability ?? 1.0) < 0.75) {
            await _completeStep(
              step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
            );
          }
        }
      }
      _detect(
        face: firstFace,
        step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
      );
    } catch (e) {
      _startProcessing();
    }
  }

  Future<void> _completeStep({
    required M7LivelynessStep step,
  }) async {
    final int indexToUpdate = _steps.indexWhere(
      (p0) => p0.step == step,
    );

    _steps[indexToUpdate] = _steps[indexToUpdate].copyWith(
      isCompleted: true,
    );
    if (mounted) {
      setState(() {});
    }
    await _stepsKey.currentState?.nextPage();
    _stopProcessing();
  }

  void _detect({
    required Face face,
    required M7LivelynessStep step,
  }) async {
    switch (step) {
      case M7LivelynessStep.blink:
        const double blinkThreshold = 0.25;
        if ((face.leftEyeOpenProbability ?? 1.0) < (blinkThreshold) &&
            (face.rightEyeOpenProbability ?? 1.0) < (blinkThreshold)) {
          _startProcessing();
          if (mounted) {
            setState(
              () => _didCloseEyes = true,
            );
          }
        }
        break;
      case M7LivelynessStep.turnLeft:
        const double headTurnThreshold = 45.0;
        if ((face.headEulerAngleY ?? 0) > (headTurnThreshold)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case M7LivelynessStep.turnRight:
        const double headTurnThreshold = -50.0;
        if ((face.headEulerAngleY ?? 0) > (headTurnThreshold)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case M7LivelynessStep.smile:
        const double smileThreshold = 0.75;
        if ((face.smilingProbability ?? 0) > (smileThreshold)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
    }
  }

  void _startProcessing() {
    if (!mounted) {
      return;
    }
    setState(
      () => _isProcessingStep = true,
    );
  }

  void _stopProcessing() {
    if (!mounted) {
      return;
    }
    setState(
      () => _isProcessingStep = false,
    );
  }

  void _startTimer() {
    _timerToDetectFace = Timer(
      Duration(seconds: widget.config.maxSecToDetect),
      () {
        _timerToDetectFace?.cancel();
        _timerToDetectFace = null;
        if (widget.config.allowAfterMaxSec) {
          _isCaptureButtonVisible = true;
          if (mounted) {
            setState(() {});
          }
          return;
        }
        _onDetectionCompleted(
          imgToReturn: null,
        );
      },
    );
  }

  Future<void> _takePicture({
    required bool didCaptureAutomatically,
  }) async {
    if (_cameraState == null) {
      _onDetectionCompleted();
      return;
    }
    _cameraState?.when(
      onPhotoMode: (p0) => Future.delayed(
        const Duration(milliseconds: 500),
        () => p0.takePhoto().then(
          (value) {
            _onDetectionCompleted(
              imgToReturn: value,
              didCaptureAutomatically: didCaptureAutomatically,
            );
          },
        ),
      ),
    );
  }

  void _onDetectionCompleted({
    String? imgToReturn,
    bool? didCaptureAutomatically,
  }) {
    if (_isCompleted) {
      return;
    }
    setState(
      () => _isCompleted = true,
    );
    final String imgPath = imgToReturn ?? "";
    if (imgPath.isEmpty || didCaptureAutomatically == null) {
      Navigator.of(context).pop(null);
      return;
    }
    Navigator.of(context).pop(
      M7CapturedImage(
        imgPath: imgPath,
        didCaptureAutomatically: didCaptureAutomatically,
      ),
    );
  }

  void _resetSteps() async {
    for (var p0 in _steps) {
      final int index = _steps.indexWhere(
        (p1) => p1.step == p0.step,
      );
      _steps[index] = _steps[index].copyWith(
        isCompleted: false,
      );
    }
    _didCloseEyes = false;
    if (_stepsKey.currentState?.currentIndex != 0) {
      _stepsKey.currentState?.reset();
    }
    if (mounted) {
      setState(() {});
    }
  }

  //* MARK: - Private Methods for UI Components
  //? =========================================================
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isInfoStepCompleted
            ? Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    SizedBox(
                      width: MediaQuery.of(context).size.width -
                          MediaQuery.of(context).size.width / 4,
                      height: MediaQuery.of(context).size.width,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 49, vertical: 0),
                            child: ClipOval(
                                child: Container(color: widget.primaryColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 61, vertical: 12),
                            child: ClipOval(
                                child: Stack(
                              children: [
                                CameraAwesomeBuilder.custom(
                                  flashMode: FlashMode.auto,
                                  previewFit: CameraPreviewFit.fitWidth,
                                  aspectRatio: CameraAspectRatios.ratio_16_9,
                                  sensor: Sensors.front,
                                  onImageForAnalysis: (img) =>
                                      _processCameraImage(img),
                                  imageAnalysisConfig: AnalysisConfig(
                                    autoStart: true,
                                    androidOptions:
                                        const AndroidAnalysisOptions.nv21(
                                            width: 250),
                                    maxFramesPerSecond: 30,
                                  ),
                                  builder: (state, previewSize, previewRect) {
                                    _cameraState = state;
                                    return M7PreviewDecoratorWidget(
                                      cameraState: state,
                                      faceDetectionStream:
                                          _faceDetectionController,
                                      previewSize: previewSize,
                                      previewRect: previewRect,
                                      detectionColor: _steps[_stepsKey
                                                  .currentState?.currentIndex ??
                                              0]
                                          .detectionColor,
                                    );
                                  },
                                  saveConfig: SaveConfig.photo(
                                    pathBuilder: () async {
                                      final String fileName =
                                          "${M7Utils.generate()}.jpg";
                                      final String path =
                                          await getTemporaryDirectory().then(
                                        (value) => value.path,
                                      );
                                      return "$path/$fileName";
                                    },
                                  ),
                                ),
                              ],
                            )),
                          ),
                          if (_isInfoStepCompleted)
                            M7LivelynessDetectionStepOverlay(
                              key: _stepsKey,
                              steps: _steps,
                              primaryColor: widget.primaryColor,
                              styleTextHeader: widget.styleTextHeader,
                              onCompleted: () => _takePicture(
                                didCaptureAutomatically: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    widget.text,
                    const SizedBox(height: 16),
                  ],
                ),
              )
            : M7LivelynessInfoWidget(
                onStartTap: () {
                  if (!mounted) {
                    return;
                  }
                  _startTimer();
                  setState(
                    () => _isInfoStepCompleted = true,
                  );
                },
              ),
      ],
    );
  }
}

class MyClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
        0, 0, size.width - size.width / 4.7, size.height - size.width / 2);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    return false;
  }
}
