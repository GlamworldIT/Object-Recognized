import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(MyApp());
}

const String ssd = "SSD Model";
const String yolo = "YOLO Model";

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TfliteHome(),
    );
  }
}

class TfliteHome extends StatefulWidget {
  @override
  _TfliteHomeState createState() => _TfliteHomeState();
}

class _TfliteHomeState extends State<TfliteHome> {
  String _model;
  File _image;
  double _imageWidth;
  double _imageHeight;
  List _recognitions;

  static var _priority = [ssd, yolo];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _model = ssd;
    loadModel();
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == yolo) {
        res = await Tflite.loadModel(
          model: "assets/tflite/yolov2_tiny.tflite",
          labels: "assets/tflite/yolov2_tiny.txt",
        );
        print("res: yolo $res");
      } else {
        res = await Tflite.loadModel(
          model: "assets/tflite/ssd_mobilenet.tflite",
          labels: "assets/tflite/ssd_mobilenet.txt",
        );
        print("res: ssd $res");
      }
    } on PlatformException {
      print("Failed to load model");
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];

    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: (size.width),
      child: _image == null
          ? Center(
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Text(
                "No image selected",
                style: TextStyle(fontSize: 20.0,color: Colors.grey[600]),
              ),
            ))
          : Image.file(_image),
    ));

    stackChildren.addAll(renderBoxes(size));

    return Scaffold(
      appBar: AppBar(
        // title: Text(
        //   "Object Detector",
        //   style: TextStyle(fontSize: 16),
        // ),
        actions: [
          DropdownButton(
            items: _priority.map((String dropDownStringItem) {
              return DropdownMenuItem<String>(
                value: dropDownStringItem,
                child: Text(dropDownStringItem),
              );
            }).toList(),
            dropdownColor: Colors.blue,
            iconEnabledColor: Colors.white,
            style: TextStyle(
              color: Colors.white,
            ),
            value: _model,
            onChanged: (valueSelectedByUser) {
              setState(() {
                _model = valueSelectedByUser;
                loadModel();
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.camera_alt,
              color: Colors.white,
            ),
            onPressed: () {
              //loadModel();
              getImageFromCamera();
            },
          ),
          IconButton(
            icon: Icon(
              Icons.image,
              color: Colors.white,
            ),
            onPressed: () {
              //loadModel();
              getImageFromGallery();
            },
          ),
        ],
      ),
      body: Stack(
        children: stackChildren,
      ),
    );
  }

  Future getImageFromCamera() async {
    //Tflite.close();
    File newImageFile = await ImagePicker.pickImage(source: ImageSource.camera);
    if (newImageFile != null) {
      setState(() {
        this._image = newImageFile;
      });
      predictImage();
    }
  }

  Future getImageFromGallery() async {
    //Tflite.close();
    File newImageFile =
        await ImagePicker.pickImage(source: ImageSource.gallery);
    if (newImageFile != null) {
      setState(() {
        this._image = newImageFile;
      });
      predictImage();
    }
  }

  predictImage() async {
    if (_image == null) return;

    if (_model == yolo) {
      await yollov2Tiny();
    } else {
      await ssdMobileNet();
    }

    FileImage(_image)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo info, bool _) {
          setState(() {
            _imageWidth = info.image.width.toDouble();
            _imageHeight = info.image.height.toDouble();
          });
        })));
  }

  yollov2Tiny() async {
    var recognition = await Tflite.detectObjectOnImage(
        path: _image.path,
        model: "YOLO",
        threshold: 0.3,
        imageMean: 0.0,
        imageStd: 255.0,
        numResultsPerClass: 1);
    setState(() {
      _recognitions = recognition;
    });
  }

  ssdMobileNet() async {
    var recognition = await Tflite.detectObjectOnImage(
        path: _image.path, numResultsPerClass: 1);
    setState(() {
      _recognitions = recognition;
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageHeight == null || _imageWidth == null) return [];

    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;

    Color blue = Colors.blue;

    return _recognitions.map((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: blue, width: 3)),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.white,
              fontSize: 15.0,
            ),
          ),
        ),
      );
    }).toList();
  }
}
