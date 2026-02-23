import 'dart:io';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';

Future<String> extractText(File imageFile) async {
  final inputImage = InputImage.fromFile(imageFile);
  final textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final RecognizedText recognizedText =
      await textRecognizer.processImage(inputImage);

  await textRecognizer.close();

  return recognizedText.text;
}

Future<void> saveToFile(String text) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/ocr_output.txt');

  await file.writeAsString(text);

  // ignore: avoid_print
  print('Saved to: ${file.path}');
}
