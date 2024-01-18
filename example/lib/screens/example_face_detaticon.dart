import 'package:flutter/cupertino.dart';
import 'package:m7_livelyness_detection/index.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  final List<M7LivelynessStepItem> veificationSteps = [
    M7LivelynessStepItem(
      step: M7LivelynessStep.blink,
      title: "Blink",
      isCompleted: false,
      detectionColor: Colors.amber,
    ),
    M7LivelynessStepItem(
      step: M7LivelynessStep.smile,
      title: "Smile",
      isCompleted: false,
      detectionColor: Colors.green.shade800,
    ),
  ];

  void initilizeDetection() => M7LivelynessDetection.instance.configure(
        lineColor: Colors.white,
        dotColor: Colors.purple.shade800,
        dotSize: 2.0,
        lineWidth: 2,
        dashValues: [2.0, 5.0],
        displayDots: false,
        displayLines: false,
        thresholds: [
          M7SmileDetectionThreshold(probability: 0.8),
          M7BlinkDetectionThreshold(
            leftEyeProbability: 0.25,
            rightEyeProbability: 0.25,
          ),
        ],
      );

  void _onStartLivelyness(context) async {
    final M7CapturedImage? response =
        await M7LivelynessDetection.instance.detectLivelyness(
      context,
      primaryColor: const Color.fromRGBO(229, 101, 83, 1),
      config: M7DetectionConfig(
        steps: veificationSteps,
        startWithInfoScreen: false,
        maxSecToDetect: 2500,
        allowAfterMaxSec: false,
        captureButtonColor: const Color.fromRGBO(229, 101, 83, 1),
      ),
      text: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 22),
        child: Text(
          'Пожалуйста, расположите свое лицо в овал',
          textAlign: TextAlign.center,
        ),
      ),
    );
    if (response == null) {
      return;
    }
    print('ALI IMAGE:' + response.imgPath);
    // model.uploadImageIdentificationSelfie(File(response.imgPath));
    // Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) => const DocumentPictureFrontWidget()));
  }

  @override
  void initState() {
    initilizeDetection();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text('Видео-идентификация'),
      ),
      body: Column(
        children: [
          CupertinoButton(
            onPressed: () => _onStartLivelyness(context),
            color: const Color.fromRGBO(229, 101, 83, 1),
            padding: const EdgeInsets.all(0),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Start',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
