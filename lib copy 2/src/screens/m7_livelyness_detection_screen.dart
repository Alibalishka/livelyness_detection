// import 'dart:async';
// import 'dart:ui' as ui;

// import 'package:collection/collection.dart';
// import 'package:m7_livelyness_detection/index.dart';

// List<CameraDescription> availableCams = [];

// class M7LivelynessDetectionScreenV1 extends StatefulWidget {
//   final M7DetectionConfig config;
//   final Widget text;
//   final Color primaryColor;
//   final TextStyle? styleTextHeader;
//   final PreferredSizeWidget? appBar;
//   const M7LivelynessDetectionScreenV1({
//     required this.config,
//     super.key,
//     this.primaryColor = Colors.white,
//     required this.text,
//     this.styleTextHeader,
//     required this.appBar,
//   });

//   @override
//   State<M7LivelynessDetectionScreenV1> createState() =>
//       _MLivelyness7DetectionScreenState();
// }

// class _MLivelyness7DetectionScreenState
//     extends State<M7LivelynessDetectionScreenV1> {
//   //* MARK: - Private Variables
//   //? =========================================================
//   late bool _isInfoStepCompleted;
//   late final List<M7LivelynessStepItem> steps;
//   CameraController? _cameraController;
//   CustomPaint? _customPaint;
//   int _cameraIndex = 0;
//   bool _isBusy = false;
//   final GlobalKey<M7LivelynessDetectionStepOverlayState> _stepsKey =
//       GlobalKey<M7LivelynessDetectionStepOverlayState>();
//   bool _isProcessingStep = false;
//   bool _didCloseEyes = false;
//   bool _isTakingPicture = false;
//   Timer? _timerToDetectFace;
//   bool _isCaptureButtonVisible = false;

//   late final List<M7LivelynessStepItem> _steps;

//   //* MARK: - Life Cycle Methods
//   //? =========================================================
//   @override
//   void initState() {
//     _preInitCallBack();
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback(
//       (_) => _postFrameCallBack(),
//     );
//   }

//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     _timerToDetectFace?.cancel();
//     _timerToDetectFace = null;
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF1F2F3),
//       appBar: widget.appBar,
//       body: SafeArea(
//         child: _buildBody(),
//       ),
//     );
//   }

//   //* MARK: - Private Methods for Business Logic
//   //? =========================================================
//   void _preInitCallBack() {
//     _steps = widget.config.steps;
//     _isInfoStepCompleted = !widget.config.startWithInfoScreen;
//   }

//   void _postFrameCallBack() async {
//     availableCams = await availableCameras();
//     if (availableCams.any(
//       (element) =>
//           element.lensDirection == CameraLensDirection.front &&
//           element.sensorOrientation == 90,
//     )) {
//       _cameraIndex = availableCams.indexOf(
//         availableCams.firstWhere((element) =>
//             element.lensDirection == CameraLensDirection.front &&
//             element.sensorOrientation == 90),
//       );
//     } else {
//       _cameraIndex = availableCams.indexOf(
//         availableCams.firstWhere(
//           (element) => element.lensDirection == CameraLensDirection.front,
//         ),
//       );
//     }
//     if (!widget.config.startWithInfoScreen) {
//       _startLiveFeed();
//     }
//   }

//   void _startTimer() {
//     _timerToDetectFace = Timer(
//       Duration(seconds: widget.config.maxSecToDetect),
//       () {
//         _timerToDetectFace?.cancel();
//         _timerToDetectFace = null;
//         if (widget.config.allowAfterMaxSec) {
//           _isCaptureButtonVisible = true;
//           setState(() {});
//           return;
//         }
//         _onDetectionCompleted(
//           imgToReturn: null,
//         );
//       },
//     );
//   }

//   void _startLiveFeed() async {
//     final camera = availableCams[_cameraIndex];
//     // _cameraController = CameraController(
//     //   camera,
//     //   ResolutionPreset.high,
//     //   imageFormatGroup: ImageFormatGroup.jpeg,
//     //   enableAudio: false,
//     // );
//     // _cameraController?.initialize().then((_) {
//     //   if (!mounted) {
//     //     return;
//     //   }
//     //   _cameraController?.startImageStream(_processCameraImage);
//     //   if (mounted) {
//     //     _startTimer();
//     //     setState(() {});
//     //   }
//     // });
//     _cameraController = CameraController(
//       camera,
//       ResolutionPreset.high,
//       enableAudio: false,
//     );
//     _cameraController?.initialize().then((_) {
//       if (!mounted) {
//         return;
//       }
//       _startTimer();
//       _cameraController?.startImageStream(_processCameraImage);
//       setState(() {});
//     });
//   }

//   Future<void> _processCameraImage(CameraImage cameraImage) async {
//     final WriteBuffer allBytes = WriteBuffer();
//     for (final Plane plane in cameraImage.planes) {
//       allBytes.putUint8List(plane.bytes);
//     }
//     final bytes = allBytes.done().buffer.asUint8List();

//     final Size imageSize = Size(
//       cameraImage.width.toDouble(),
//       cameraImage.height.toDouble(),
//     );

//     final camera = availableCams[_cameraIndex];
//     final imageRotation = InputImageRotationValue.fromRawValue(
//       camera.sensorOrientation,
//     );
//     if (imageRotation == null) return;

//     final inputImageFormat = InputImageFormatValue.fromRawValue(
//       cameraImage.format.raw,
//     );
//     if (inputImageFormat == null) return;

//     final planeData = cameraImage.planes;

//     final inputImageData = InputImageMetadata(
//       size: imageSize,
//       rotation: imageRotation,
//       format: inputImageFormat,
//       bytesPerRow: planeData.first.bytesPerRow,
//     );

//     final inputImage = InputImage.fromBytes(
//       bytes: bytes,
//       metadata: inputImageData,
//     );

//     _processImage(inputImage);
//   }

//   Future<void> _processImage(InputImage inputImage) async {
//     if (_isBusy) {
//       return;
//     }
//     _isBusy = true;
//     final faces = await M7MLHelper.instance.processInputImage(inputImage);

//     if (inputImage.metadata?.size != null &&
//         inputImage.metadata?.rotation != null) {
//       if (faces.isEmpty) {
//         _resetSteps();
//       } else {
//         final firstFace = faces.first;
//         final painter = M7FaceDetectorPainter(
//           firstFace,
//           inputImage.metadata!.size,
//           inputImage.metadata!.rotation,
//         );
//         _customPaint = CustomPaint(
//           painter: painter,
//           child: Container(
//             color: Colors.transparent,
//             height: double.infinity,
//             width: double.infinity,
//             margin: EdgeInsets.only(
//               top: MediaQuery.of(context).padding.top,
//               bottom: MediaQuery.of(context).padding.bottom,
//             ),
//           ),
//         );
//         if (_isProcessingStep &&
//             _steps[_stepsKey.currentState?.currentIndex ?? 0].step ==
//                 M7LivelynessStep.blink) {
//           if (_didCloseEyes) {
//             if ((faces.first.leftEyeOpenProbability ?? 1.0) < 0.75 &&
//                 (faces.first.rightEyeOpenProbability ?? 1.0) < 0.75) {
//               await _completeStep(
//                 step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
//               );
//             }
//           }
//         }
//         _detect(
//           face: faces.first,
//           step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
//         );
//       }
//     } else {
//       _resetSteps();
//     }
//     _isBusy = false;
//     if (mounted) {
//       setState(() {});
//     }
//   }

//   Future<void> _completeStep({
//     required M7LivelynessStep step,
//   }) async {
//     final int indexToUpdate = _steps.indexWhere(
//       (p0) => p0.step == step,
//     );

//     _steps[indexToUpdate] = _steps[indexToUpdate].copyWith(
//       isCompleted: true,
//     );
//     if (mounted) {
//       setState(() {});
//     }
//     await _stepsKey.currentState?.nextPage();
//     _stopProcessing();
//   }

//   void _takePicture({
//     required bool didCaptureAutomatically,
//   }) async {
//     try {
//       if (_cameraController == null) return;
//       // if (face == null) return;
//       if (_isTakingPicture) {
//         return;
//       }
//       setState(
//         () => _isTakingPicture = true,
//       );
//       await _cameraController?.stopImageStream();
//       final XFile? clickedImage = await _cameraController?.takePicture();
//       if (clickedImage == null) {
//         _startLiveFeed();
//         return;
//       }
//       _onDetectionCompleted(
//         imgToReturn: clickedImage,
//         didCaptureAutomatically: didCaptureAutomatically,
//       );
//     } catch (e) {
//       _startLiveFeed();
//     }
//   }

//   void _onDetectionCompleted({
//     XFile? imgToReturn,
//     bool? didCaptureAutomatically,
//   }) {
//     final String imgPath = imgToReturn?.path ?? "";
//     if (imgPath.isEmpty || didCaptureAutomatically == null) {
//       Navigator.of(context).pop(null);
//       return;
//     }
//     Navigator.of(context).pop(
//       M7CapturedImage(
//         imgPath: imgPath,
//         didCaptureAutomatically: didCaptureAutomatically,
//       ),
//     );
//   }

//   void _resetSteps() async {
//     for (var p0 in _steps) {
//       final int index = _steps.indexWhere(
//         (p1) => p1.step == p0.step,
//       );
//       _steps[index] = _steps[index].copyWith(
//         isCompleted: false,
//       );
//     }
//     _customPaint = null;
//     _didCloseEyes = false;
//     if (_stepsKey.currentState?.currentIndex != 0) {
//       _stepsKey.currentState?.reset();
//     }
//     if (mounted) {
//       setState(() {});
//     }
//   }

//   void _startProcessing() {
//     if (!mounted) {
//       return;
//     }
//     setState(
//       () => _isProcessingStep = true,
//     );
//   }

//   void _stopProcessing() {
//     if (!mounted) {
//       return;
//     }
//     setState(
//       () => _isProcessingStep = false,
//     );
//   }

//   void _detect({
//     required Face face,
//     required M7LivelynessStep step,
//   }) async {
//     if (_isProcessingStep) {
//       return;
//     }
//     switch (step) {
//       case M7LivelynessStep.blink:
//         final M7BlinkDetectionThreshold? blinkThreshold =
//             M7LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
//           (p0) => p0 is M7BlinkDetectionThreshold,
//         ) as M7BlinkDetectionThreshold?;
//         if ((face.leftEyeOpenProbability ?? 1.0) <
//                 (blinkThreshold?.leftEyeProbability ?? 0.25) &&
//             (face.rightEyeOpenProbability ?? 1.0) <
//                 (blinkThreshold?.rightEyeProbability ?? 0.25)) {
//           _startProcessing();
//           if (mounted) {
//             setState(
//               () => _didCloseEyes = true,
//             );
//           }
//         }
//         break;
//       case M7LivelynessStep.turnLeft:
//         final M7HeadTurnDetectionThreshold? headTurnThreshold =
//             M7LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
//           (p0) => p0 is M7HeadTurnDetectionThreshold,
//         ) as M7HeadTurnDetectionThreshold?;
//         if ((face.headEulerAngleY ?? 0) >
//             (headTurnThreshold?.rotationAngle ?? 45)) {
//           _startProcessing();
//           await _completeStep(step: step);
//         }
//         break;
//       case M7LivelynessStep.turnRight:
//         final M7HeadTurnDetectionThreshold? headTurnThreshold =
//             M7LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
//           (p0) => p0 is M7HeadTurnDetectionThreshold,
//         ) as M7HeadTurnDetectionThreshold?;
//         if ((face.headEulerAngleY ?? 0) >
//             (headTurnThreshold?.rotationAngle ?? -50)) {
//           _startProcessing();
//           await _completeStep(step: step);
//         }
//         break;
//       case M7LivelynessStep.smile:
//         final M7SmileDetectionThreshold? smileThreshold =
//             M7LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
//           (p0) => p0 is M7SmileDetectionThreshold,
//         ) as M7SmileDetectionThreshold?;
//         if ((face.smilingProbability ?? 0) >
//             (smileThreshold?.probability ?? 0.75)) {
//           _startProcessing();
//           await _completeStep(step: step);
//         }
//         break;
//     }
//   }

//   //* MARK: - Private Methods for UI Components
//   //? =========================================================
//   Widget _buildBody() {
//     return Stack(
//       children: [
//         _buildDetectionBody(),
//         // : M7LivelynessInfoWidget(
//         //     onStartTap: () {
//         //       if (mounted) {
//         //         setState(
//         //           () => _isInfoStepCompleted = true,
//         //         );
//         //       }
//         //       _startLiveFeed();
//         //     },
//         //   ),
//         // Align(
//         //   alignment: Alignment.topRight,
//         //   child: Padding(
//         //     padding: const EdgeInsets.only(
//         //       right: 10,
//         //       top: 10,
//         //     ),
//         //     child: CircleAvatar(
//         //       radius: 20,
//         //       backgroundColor: Colors.black,
//         //       child: IconButton(
//         //         onPressed: () => _onDetectionCompleted(
//         //           imgToReturn: null,
//         //           didCaptureAutomatically: null,
//         //         ),
//         //         icon: const Icon(
//         //           Icons.close_rounded,
//         //           size: 20,
//         //           color: Colors.white,
//         //         ),
//         //       ),
//         //     ),
//         //   ),
//         // ),
//       ],
//     );
//   }

//   Widget _buildDetectionBody() {
//     if (_cameraController == null ||
//         _cameraController?.value.isInitialized == false) {
//       return const Center(
//         child: CircularProgressIndicator.adaptive(),
//       );
//     }
//     final size = MediaQuery.of(context).size;
//     var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
//     if (scale < 1) scale = 1 / scale;
//     final Widget cameraView = CameraPreview(_cameraController!);
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.all(Radius.circular(16)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const SizedBox(height: 16),
//           SizedBox(
//             // width: MediaQuery.of(context).size.width -
//             //     MediaQuery.of(context).size.width / 4,
//             height: MediaQuery.of(context).size.width,
//             child: Stack(
//               children: [
//                 Padding(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 49, vertical: 0),
//                   child: ClipOval(child: Container(color: Colors.amber)),
//                 ),
//                 Positioned.fill(
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 61, vertical: 12),
//                     child: Transform.scale(
//                       scale: 1,
//                       child: Stack(
//                         children: [
//                           ClipOval(child: cameraView),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 if (_customPaint != null) _customPaint!,
//                 M7LivelynessDetectionStepOverlay(
//                   key: _stepsKey,
//                   steps: _steps,
//                   styleTextHeader: widget.styleTextHeader,
//                   primaryColor: widget.primaryColor,
//                   onCompleted: () => Future.delayed(
//                     const Duration(milliseconds: 500),
//                     () => _takePicture(
//                       didCaptureAutomatically: true,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 24),
//           widget.text,
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }
// }
