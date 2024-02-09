import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_plus/src/custom_packages/crop_image/main/image_crop.dart';
import 'package:image_picker_plus/src/entities/app_theme.dart';
import 'package:image_picker_plus/src/custom_packages/crop_image/crop_image.dart';
import 'package:image_picker_plus/src/utilities/enum.dart';
import 'package:image_picker_plus/src/video_layout/record_count.dart';
import 'package:image_picker_plus/src/video_layout/record_fade_animation.dart';
import 'package:image_picker_plus/src/entities/selected_image_details.dart';
import 'package:image_picker_plus/src/entities/tabs_texts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class CustomCameraDisplay extends StatefulWidget {
  final bool selectedVideo;
  final AppTheme appTheme;
  final TabsTexts tapsNames;
  final bool enableCamera;
  final bool enableVideo;
  final VoidCallback moveToVideoScreen;
  final ValueNotifier<File?> selectedCameraImage;
  final ValueNotifier<bool> redDeleteText;
  final ValueChanged<bool> replacingTabBar;
  final ValueNotifier<bool> clearVideoRecord;
  final AsyncValueSetter<SelectedImagesDetails>? callbackFunction;

  const CustomCameraDisplay({
    Key? key,
    required this.appTheme,
    required this.tapsNames,
    required this.selectedCameraImage,
    required this.enableCamera,
    required this.enableVideo,
    required this.redDeleteText,
    required this.selectedVideo,
    required this.replacingTabBar,
    required this.clearVideoRecord,
    required this.moveToVideoScreen,
    required this.callbackFunction,
  }) : super(key: key);

  @override
  CustomCameraDisplayState createState() => CustomCameraDisplayState();
}

class CustomCameraDisplayState extends State<CustomCameraDisplay> {
  ValueNotifier<bool> startVideoCount = ValueNotifier(false);

  bool initializeDone = false;
  bool allPermissionsAccessed = true;

  List<CameraDescription>? cameras;
  late CameraController controller;

  final cropKey = GlobalKey<CustomCropState>();

  Flash currentFlashMode = Flash.auto;
  late Widget videoStatusAnimation;
  int selectedCamera = 0;
  File? videoRecordFile;

  @override
  void dispose() {
    startVideoCount.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    videoStatusAnimation = Container();
    _initializeCamera();

    super.initState();
  }

  Future<void> _initializeCamera() async {
    try {
      PermissionState state = await PhotoManager.requestPermissionExtend();
      if (!state.hasAccess || !state.isAuth) {
        allPermissionsAccessed = false;
        return;
      }
      allPermissionsAccessed = true;
      cameras = await availableCameras();
      if (!mounted) return;
      controller = CameraController(
        cameras![selectedCamera],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      initializeDone = true;
    } catch (e) {
      allPermissionsAccessed = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.appTheme.primaryColor,
      child: allPermissionsAccessed
          ? (initializeDone ? buildBody() : loadingProgress())
          : failedPermissions(),
    );
  }

  Widget failedPermissions() {
    return Center(
      child: Text(
        widget.tapsNames.acceptAllPermissions,
        style: TextStyle(color: widget.appTheme.focusColor),
      ),
    );
  }

  Center loadingProgress() {
    return Center(
      child: CircularProgressIndicator(
        color: widget.appTheme.focusColor,
        strokeWidth: 1,
      ),
    );
  }

  Widget buildBody() {
    Color whiteColor = widget.appTheme.primaryColor;
    File? selectedImage = widget.selectedCameraImage.value;
    return Column(
      children: [
        appBar(),
        Expanded(
          child: Stack(
            children: [
              if (selectedImage == null) ...[
                SizedBox(
                  width: double.infinity,
                  height: double.maxFinite,
                  child: CameraPreview(controller),
                ),
                buildFlashIcons(),
                buildPickImageContainer(whiteColor, context),
                chooseCamera(),
              ] else ...[
                SizedBox(
                  height: double.infinity,
                  width: double.infinity,
                  child: Image.file(selectedImage, fit: BoxFit.cover),
                )
              ],
            ],
          ),
        ),
      ],
    );
  }

  Align buildPickImageContainer(Color whiteColor, BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 270,
        color: Colors.transparent,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: RecordCount(
                  appTheme: widget.appTheme,
                  startVideoCount: startVideoCount,
                  makeProgressRed: widget.redDeleteText,
                  clearVideoRecord: widget.clearVideoRecord,
                ),
              ),
            ),
            const Spacer(),
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  padding: const EdgeInsets.all(60),
                  child: Align(
                    alignment: Alignment.center,
                    child: cameraButton(context),
                  ),
                ),
                Positioned(bottom: 120, child: videoStatusAnimation),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Align chooseCamera() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30, right: 10),
        child: IconButton.outlined(
          onPressed: () async {
            setState(() {
              int length = cameras?.length ?? 0;
              if (selectedCamera == 0 && length >= 2) {
                selectedCamera = 1;
              } else if (selectedCamera == 1 && length >= 2) {
                selectedCamera = 0;
              }
              if (kDebugMode) {
                print("selected camera --------> $selectedCamera");
              }
            });
            await controller.setDescription(cameras![selectedCamera]);
          },
          iconSize: 30,
          icon: const Icon(
            Icons.cameraswitch,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Align buildFlashIcons() {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        onPressed: () {
          setState(() {
            currentFlashMode = currentFlashMode == Flash.off
                ? Flash.auto
                : (currentFlashMode == Flash.auto ? Flash.on : Flash.off);
          });
          currentFlashMode == Flash.on
              ? controller.setFlashMode(FlashMode.torch)
              : currentFlashMode == Flash.off
                  ? controller.setFlashMode(FlashMode.off)
                  : controller.setFlashMode(FlashMode.auto);
        },
        icon: Icon(
            currentFlashMode == Flash.on
                ? Icons.flash_on_rounded
                : (currentFlashMode == Flash.auto
                    ? Icons.flash_auto_rounded
                    : Icons.flash_off_rounded),
            color: Colors.white),
      ),
    );
  }

  // CustomCrop buildCrop(File selectedImage) {
  //   String path = selectedImage.path;
  //   bool isThatVideo = path.contains("mp4", path.length - 5);
  //   return CustomCrop(
  //     image: selectedImage,
  //     isThatImage: !isThatVideo,
  //     key: cropKey,
  //     alwaysShowGrid: false,
  //     paintColor: widget.appTheme.primaryColor,
  //   );
  // }

  AppBar appBar() {
    Color whiteColor = widget.appTheme.primaryColor;
    Color blackColor = widget.appTheme.focusColor;
    File? selectedImage = widget.selectedCameraImage.value;
    double width = MediaQuery.sizeOf(context).width;
    double height = MediaQuery.sizeOf(context).height;
    return AppBar(
      backgroundColor: whiteColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.clear_rounded, color: blackColor, size: 30),
        onPressed: () {
          Navigator.of(context).maybePop(null);
        },
      ),
      title: selectedImage == null ? const Text('Camera') : const Text('Preview Image'),
      centerTitle: true,
      actions: <Widget>[
        if (selectedImage != null)
          AnimatedSwitcher(
            duration: const Duration(seconds: 1),
            switchInCurve: Curves.easeIn,
            child: Visibility(
              visible: videoRecordFile != null || selectedImage != null,
              child: IconButton(
                icon: Icon(Icons.check, color: blackColor, size: 30),
                onPressed: () async {
                  if (videoRecordFile != null) {
                    Uint8List byte = await videoRecordFile!.readAsBytes();
                    SelectedByte selectedByte = SelectedByte(
                      isThatImage: false,
                      selectedFile: videoRecordFile!,
                      selectedByte: byte,
                    );
                    SelectedImagesDetails details = SelectedImagesDetails(
                      multiSelectionMode: false,
                      selectedFiles: [selectedByte],
                      aspectRatio: 1.0,
                    );
                    if (!mounted) return;

                    if (widget.callbackFunction != null) {
                      await widget.callbackFunction!(details);
                    } else {
                      Navigator.of(context).maybePop(details);
                    }
                  } else if (selectedImage != null) {
                    Uint8List imageByte = await selectedImage.readAsBytes();
                    SelectedByte selectedByte = SelectedByte(
                      isThatImage: true,
                      selectedFile: selectedImage,
                      selectedByte: imageByte,
                    );

                    SelectedImagesDetails details = SelectedImagesDetails(
                      selectedFiles: [selectedByte],
                      multiSelectionMode: false,
                      aspectRatio: width / height,
                    );
                    if (!mounted) return;
                    Navigator.of(context).maybePop(details);
                    // if (widget.callbackFunction != null) {
                    //   await widget.callbackFunction!(details);
                    // } else {
                    //   Navigator.of(context).maybePop(details);
                    // }
                  }
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<File?> cropImage(File imageFile) async {
    await ImageCrop.requestPermissions();
    final scale = cropKey.currentState!.scale;
    final area = cropKey.currentState!.area;
    if (area == null) {
      return null;
    }
    final sample = await ImageCrop.sampleImage(
      file: imageFile,
      preferredSize: (2000 / scale).round(),
    );
    final File file = await ImageCrop.cropImage(
      file: sample,
      area: area,
    );
    sample.delete();
    return file;
  }

  GestureDetector cameraButton(BuildContext context) {
    Color whiteColor = Colors.white;
    return GestureDetector(
      onTap: widget.enableCamera ? onPress : null,
      onLongPress: widget.enableVideo ? onLongTap : null,
      onLongPressUp: widget.enableVideo ? onLongTapUp : onPress,
      child: CircleAvatar(
          backgroundColor: Colors.grey[400],
          radius: 40,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: whiteColor,
          )),
    );
  }

  onPress() async {
    try {
      if (!widget.selectedVideo) {
        final image = await controller.takePicture();
        final bytes = await image.readAsBytes();

        img.Image? originalImg = await img.decodeImageFile(image.path);
        img.Image flippedImg = img.flipHorizontal(originalImg!);
        File selectedImage = File(image.path);
        File flippedFile = await selectedImage
            .writeAsBytes(img.encodeJpg(flippedImg), flush: true);
        setState(() {
          widget.selectedCameraImage.value = flippedFile;
          widget.replacingTabBar(true);
        });
      } else {
        setState(() {
          videoStatusAnimation = buildFadeAnimation();
        });
      }
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  onLongTap() {
    controller.startVideoRecording();
    widget.moveToVideoScreen();
    setState(() {
      startVideoCount.value = true;
    });
  }

  onLongTapUp() async {
    setState(() {
      startVideoCount.value = false;
      widget.replacingTabBar(true);
    });
    XFile video = await controller.stopVideoRecording();
    videoRecordFile = File(video.path);
  }

  RecordFadeAnimation buildFadeAnimation() {
    return RecordFadeAnimation(child: buildMessage());
  }

  Widget buildMessage() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
            color: Color.fromARGB(255, 54, 53, 53),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.tapsNames.holdButtonText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Center(
            child: Icon(
              Icons.arrow_drop_down_rounded,
              color: Color.fromARGB(255, 49, 49, 49),
              size: 65,
            ),
          ),
        ),
      ],
    );
  }
}
