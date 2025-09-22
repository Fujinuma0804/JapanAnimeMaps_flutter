// import Flutter
// import UIKit
// import AVFoundation
// import Photos
// import CoreLocation
//
// @UIApplicationMain
// @objc class AppDelegate: FlutterAppDelegate {
//     override func application(
//         _ application: UIApplication,
//         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//     ) -> Bool {
//         let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
//
//         // ネイティブカメラチャンネルを設定
//         let cameraChannel = FlutterMethodChannel(
//             name: "com.jam.camera/native_camera",
//             binaryMessenger: controller.binaryMessenger
//         )
//
//         // カメラハンドラーを初期化
//         let cameraHandler = NativeCameraHandler()
//         cameraHandler.setupMethodChannel(cameraChannel)
//
//         GeneratedPluginRegistrant.register(with: self)
//         return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//     }
// }
//
// // MARK: - ネイティブカメラハンドラー
// class NativeCameraHandler: NSObject {
//     private var methodChannel: FlutterMethodChannel?
//     private var captureSession: AVCaptureSession?
//     private var camera: AVCaptureDevice?
//     private var cameraInput: AVCaptureDeviceInput?
//     private var photoOutput: AVCapturePhotoOutput?
//     private var videoOutput: AVCaptureMovieFileOutput?
//     private var previewLayer: AVCaptureVideoPreviewLayer?
//     private var textureRegistry: FlutterTextureRegistry?
//     private var textureId: Int64?
//
//     // カメラ設定
//     private var currentCameraPosition: AVCaptureDevice.Position = .back
//     private var isFlashOn: Bool = false
//     private var currentZoomLevel: CGFloat = 1.0
//     private var exposureOffset: Float = 0.0
//
//     // 録画関連
//     private var isRecording: Bool = false
//     private var videoFileURL: URL?
//
//     func setupMethodChannel(_ channel: FlutterMethodChannel) {
//         methodChannel = channel
//
//         channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
//             self?.handleMethodCall(call, result: result)
//         }
//     }
//
//     private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         switch call.method {
//         case "initializeCamera":
//             initializeCamera(call.arguments as? [String: Any], result: result)
//         case "switchCamera":
//             switchCamera(call.arguments as? [String: Any], result: result)
//         case "setFlashMode":
//             setFlashMode(call.arguments as? [String: Any], result: result)
//         case "setFocusPoint":
//             setFocusPoint(call.arguments as? [String: Any], result: result)
//         case "setExposureOffset":
//             setExposureOffset(call.arguments as? [String: Any], result: result)
//         case "setZoomLevel":
//             setZoomLevel(call.arguments as? [String: Any], result: result)
//         case "capturePhoto":
//             capturePhoto(call.arguments as? [String: Any], result: result)
//         case "captureCompositePhoto":
//             captureCompositePhoto(call.arguments as? [String: Any], result: result)
//         case "startVideoRecording":
//             startVideoRecording(result: result)
//         case "stopVideoRecording":
//             stopVideoRecording(result: result)
//         case "getCameraCapabilities":
//             getCameraCapabilities(result: result)
//         case "pauseCamera":
//             pauseCamera(result: result)
//         case "resumeCamera":
//             resumeCamera(result: result)
//         case "dispose":
//             dispose(result: result)
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }
//
//     // MARK: - カメラ初期化
//     private func initializeCamera(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
//         guard let args = arguments,
//               let cameraPositionString = args["cameraPosition"] as? String else {
//             result(["success": false, "error": "Invalid arguments"])
//             return
//         }
//
//         // カメラ権限をチェック
//         let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
//         if cameraStatus != .authorized {
//             AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
//                 DispatchQueue.main.async {
//                     if granted {
//                         self?.setupCaptureSession(cameraPositionString, result: result)
//                     } else {
//                         result(["success": false, "error": "Camera permission denied"])
//                     }
//                 }
//             }
//         } else {
//             setupCaptureSession(cameraPositionString, result: result)
//         }
//     }
//
//     private func setupCaptureSession(_ cameraPositionString: String, result: @escaping FlutterResult) {
//         captureSession = AVCaptureSession()
//         captureSession?.sessionPreset = .photo
//
//         // カメラデバイスを取得
//         currentCameraPosition = cameraPositionString == "front" ? .front : .back
//
//         guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
//             result(["success": false, "error": "Camera device not available"])
//             return
//         }
//
//         self.camera = camera
//
//         do {
//             // カメラ入力を設定
//             cameraInput = try AVCaptureDeviceInput(device: camera)
//             if let input = cameraInput, captureSession?.canAddInput(input) == true {
//                 captureSession?.addInput(input)
//             }
//
//             // 写真出力を設定
//             photoOutput = AVCapturePhotoOutput()
//             if let output = photoOutput, captureSession?.canAddOutput(output) == true {
//                 captureSession?.addOutput(output)
//             }
//
//             // 動画出力を設定
//             videoOutput = AVCaptureMovieFileOutput()
//             if let videoOut = videoOutput, captureSession?.canAddOutput(videoOut) == true {
//                 captureSession?.addOutput(videoOut)
//             }
//
//             // プレビューレイヤーを設定
//             previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
//             previewLayer?.videoGravity = .resizeAspectFill
//
//             // Textureとして登録（実際のFlutterアプリでは別途テクスチャレジストリが必要）
//             textureId = Int64.random(in: 1...1000000)
//
//             // セッションを開始
//             DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//                 self?.captureSession?.startRunning()
//             }
//
//             result([
//                 "success": true,
//                 "textureId": textureId!
//             ])
//
//         } catch {
//             result(["success": false, "error": "Failed to setup camera: \(error.localizedDescription)"])
//         }
//     }
//
//     // MARK: - カメラ切り替え
//     private func switchCamera(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
//         guard let args = arguments,
//               let cameraPositionString = args["cameraPosition"] as? String,
//               let session = captureSession else {
//             result(["success": false, "error": "Invalid arguments or session not initialized"])
//             return
//         }
//
//         let newPosition: AVCaptureDevice.Position = cameraPositionString == "front" ? .front : .back
//
//         guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
//             result(["success": false, "error": "Requested camera not available"])
//             return
//         }
//
//         do {
//             session.beginConfiguration()
//
//             // 古い入力を削除
//             if let oldInput = cameraInput {
//                 session.removeInput(oldInput)
//             }
//
//             // 新しい入力を追加
//             let newInput = try AVCaptureDeviceInput(device: newCamera)
//             if session.canAddInput(newInput) {
//                 session.addInput(newInput)
//                 cameraInput = newInput
//                 camera = newCamera
//                 currentCameraPosition = newPosition
//             }
//
//             session.commitConfiguration()
//
//             result(["success": true])
//
//         } catch {
//             session.commitConfiguration()
//             result(["success": false, "error": "Failed to switch camera: \(error.localizedDescription)"])
//         }
//     }
//
//     // MARK: - フラッシュ設定
//     private func setFlashMode(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
//         guard let args = arguments,
//               let flashModeString = args["flashMode"] as? String else {
//             result(["success": false, "error": "Invalid arguments"])
//             return
//         }
//
//         isFlashOn = flashModeString == "on"
//         result(["success": true])
//     }
//
//     // MARK: - フォーカス設定
//     private func setFocusPoint(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
//         guard let args = arguments,
//               let x = args["x"] as? Double,
//               let y = args["y"] as? Double,
//               let camera = camera else {
//             result(["success": false, "error": "Invalid arguments or camera not available"])
//             return
//         }
//
//         let focusPoint = CGPoint(x: x, y: y)
//
//         do {
//             try camera.lockForConfiguration()
//
//             if camera.isFocusPointOfInterestSupported {
//                 camera.focusPointOfInterest = focusPoint
//                 camera.focusMode = .autoFocus
//             }
//
//             if camera.isExposurePointOfInterestSupported {
//                 camera.exposurePointOfInterest = focusPoint
//                 camera.exposureMode = .autoExpose
//             }
//
//             camera.unlockForConfiguration()
//
//             result(["success": true])
//
//         } catch {
//             result(["success": false, "error": "Failed to set focus: \(error.localizedDescription)"])
//         }
//     }
//
//     // MARK: - 露出調整
//     private func setExposureOffset(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
//         guard let args = arguments,
//               let offset = args["offset"] as? Double,
//               let camera = camera else {
//             result(["success": false, "error": "Invalid arguments or camera not available"])
//             return
//         }
//
//         exposureOffset = Float(offset)
//
//         do {
//             try camera.lockForConfiguration()
//
//             if camera.isExposureModeSupported(.custom) {
//                 let clampedOffset = max(camera.minExposureTargetBias, min(camera.maxExposureTargetBias, Float(offset)))
//                 camera.setExposureTargetBias(clampedOffset, completionHandler: nil)
//             }
//
//             camera.unlockForConfiguration()
//
//             result(["success": true])
//
//         } catch {
//             result(["success": false, "error": "Failed to set exposure: \(error.localizedDescription)"])
//         }
//     }
//
//     // MARK: - ズーム設定
//     private func setZoomLevel(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
//         guard let args = arguments,
//               let zoomLevel = args["zoomLevel"] as? Double,
//               let camera = camera else {
//             result(["success": false, "error": "Invalid arguments or camera not available"])
//             return
//         }
//
//         currentZoomLevel = CGFloat(zoomLevel)
//
//         do {
//             try camera.lockForConfiguration()
//
//             let maxZoom = camera.activeFormat.videoMaxZoomFactor
//             let clampedZoom = max(1.0, min(maxZoom, CGFloat(zoomLevel)))
//             camera.videoZoomFactor = clampedZoom
//
//             camera.unlockForConfiguration()
//
//             result(["success": true])
//
//         } catch {
//             result(["success": false, "error": "Failed to set zoom: \(error.localizedDescription)"])
//         }
//     }
//
//     // MARK: - 通常写真撮影
//     private func capturePhoto(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
//         guard let photoOutput = photoOutput else {
//             result(["success": false, "error": "Photo output not available"])
//             return
//         }
//
//         let settings = AVCapturePhotoSettings()
//
//         // フラッシュ設定
//         if isFlashOn && settings.availableFlashModes.contains(.on) {
//             settings.flashMode = .on
//         } else {
//             settings.flashMode = .off
//         }
//
//         // 高画質設定
//         if let quality = arguments?["quality"] as? Int {
//             settings.photoQualityPrioritization = quality >= 90 ? .quality : .speed
//         }
//
//         let delegate = PhotoCaptureDelegate { [weak self] imageData, error in
//             if let error = error {
//                 result(["success": false, "error": "Photo capture failed: \(error.localizedDescription)"])
//                 return
//             }
//
//             guard let data = imageData else {
//                 result(["success": false, "error": "No image data received"])
//                 return
//             }
//
//             // 写真を一時ファイルに保存
//             let tempDir = FileManager.default.temporaryDirectory
//             let fileName = "photo_\(Date().timeIntervalSince1970).jpg"
//             let fileURL = tempDir.appendingPathComponent(fileName)
//
//             do {
//                 try data.write(to: fileURL)
//                 result([
//                     "success": true,
//                     "imagePath": fileURL.path
//                 ])
//             } catch {
//                 result(["success": false, "error": "Failed to save photo: \(error.localizedDescription)"])
//             }
//         }
//
//         photoOutput.capturePhoto(with: settings, delegate: delegate)
//     }
//
//     // MARK: - 合成写真撮影
//     private func captureCompositePhoto(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
//         guard let photoOutput = photoOutput,
//               let args = arguments else {
//             result(["success": false, "error": "Photo output not available or invalid arguments"])
//             return
//         }
//
//         let settings = AVCapturePhotoSettings()
//
//         // フラッシュ設定
//         if isFlashOn && settings.availableFlashModes.contains(.on) {
//             settings.flashMode = .on
//         } else {
//             settings.flashMode = .off
//         }
//
//         // 高画質設定
//         if let quality = args["quality"] as? Int {
//             settings.photoQualityPrioritization = quality >= 90 ? .quality : .speed
//         }
//
//         let delegate = PhotoCaptureDelegate { [weak self] imageData, error in
//             if let error = error {
//                 result(["success": false, "error": "Photo capture failed: \(error.localizedDescription)"])
//                 return
//             }
//
//             guard let data = imageData else {
//                 result(["success": false, "error": "No image data received"])
//                 return
//             }
//
//             // 画像合成処理
//             self?.processCompositeImage(data, arguments: args, result: result)
//         }
//
//         photoOutput.capturePhoto(with: settings, delegate: delegate)
//     }
//
//     private func processCompositeImage(_ imageData: Data, arguments: [String: Any], result: @escaping FlutterResult) {
//         guard let baseImage = UIImage(data: imageData) else {
//             result(["success": false, "error": "Failed to create image from data"])
//             return
//         }
//
//         let overlayInfo = arguments["overlay"] as? [String: Any]
//         let locationInfo = arguments["location"] as? [String: Any]
//
//         var finalImage = baseImage
//
//         // オーバーレイ画像の合成
//         if let overlay = overlayInfo,
//            let hasOverlay = overlay["hasOverlay"] as? Bool,
//            hasOverlay,
//            let imageUrl = overlay["imageUrl"] as? String,
//            let x = overlay["x"] as? Double,
//            let y = overlay["y"] as? Double,
//            let width = overlay["width"] as? Double,
//            let height = overlay["height"] as? Double {
//
//             // ネットワーク画像をダウンロードして合成
//             downloadAndCompositeImage(baseImage, overlayUrl: imageUrl, x: x, y: y, width: width, height: height) { compositeImage in
//                 if let composite = compositeImage {
//                     finalImage = composite
//                 }
//
//                 // 位置情報をEXIFに追加（オプション）
//                 self.addLocationToImage(finalImage, locationInfo: locationInfo, result: result)
//             }
//         } else {
//             // 位置情報のみ追加
//             addLocationToImage(finalImage, locationInfo: locationInfo, result: result)
//         }
//     }
//
//     private func downloadAndCompositeImage(_ baseImage: UIImage, overlayUrl: String, x: Double, y: Double, width: Double, height: Double, completion: @escaping (UIImage?) -> Void) {
//         guard let url = URL(string: overlayUrl) else {
//             completion(nil)
//             return
//         }
//
//         URLSession.shared.dataTask(with: url) { data, _, error in
//             DispatchQueue.main.async {
//                 guard let data = data,
//                       let overlayImage = UIImage(data: data) else {
//                     completion(nil)
//                     return
//                 }
//
//                 // 画像合成
//                 let compositeImage = self.compositeImages(baseImage: baseImage, overlayImage: overlayImage, x: x, y: y, width: width, height: height)
//                 completion(compositeImage)
//             }
//         }.resume()
//     }
//
//     private func compositeImages(baseImage: UIImage, overlayImage: UIImage, x: Double, y: Double, width: Double, height: Double) -> UIImage? {
//         let size = baseImage.size
//
//         UIGraphicsBeginImageContextWithOptions(size, false, baseImage.scale)
//
//         // ベース画像を描画
//         baseImage.draw(in: CGRect(origin: .zero, size: size))
//
//         // オーバーレイ画像を指定位置に描画
//         let overlayRect = CGRect(x: x, y: y, width: width, height: height)
//         overlayImage.draw(in: overlayRect)
//
//         let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
//         UIGraphicsEndImageContext()
//
//         return compositeImage
//     }
//
//     private func addLocationToImage(_ image: UIImage, locationInfo: [String: Any]?, result: @escaping FlutterResult) {
//         guard let imageData = image.jpegData(compressionQuality: 1.0) else {
//             result(["success": false, "error": "Failed to convert image to data"])
//             return
//         }
//
//         // 写真を一時ファイルに保存
//         let tempDir = FileManager.default.temporaryDirectory
//         let fileName = "composite_photo_\(Date().timeIntervalSince1970).jpg"
//         let fileURL = tempDir.appendingPathComponent(fileName)
//
//         do {
//             try imageData.write(to: fileURL)
//             result([
//                 "success": true,
//                 "imagePath": fileURL.path
//             ])
//         } catch {
//             result(["success": false, "error": "Failed to save composite photo: \(error.localizedDescription)"])
//         }
//     }
//
//     // MARK: - 動画撮影
//     private func startVideoRecording(result: @escaping FlutterResult) {
//         guard let videoOutput = videoOutput,
//               !isRecording else {
//             result(["success": false, "error": "Video output not available or already recording"])
//             return
//         }
//
//         let tempDir = FileManager.default.temporaryDirectory
//         let fileName = "video_\(Date().timeIntervalSince1970).mov"
//         videoFileURL = tempDir.appendingPathComponent(fileName)
//
//         guard let fileURL = videoFileURL else {
//             result(["success": false, "error": "Failed to create video file URL"])
//             return
//         }
//
//         videoOutput.startRecording(to: fileURL, recordingDelegate: self)
//         isRecording = true
//
//         result(["success": true])
//     }
//
//     private func stopVideoRecording(result: @escaping FlutterResult) {
//         guard let videoOutput = videoOutput,
//               isRecording else {
//             result(["success": false, "error": "Not currently recording"])
//             return
//         }
//
//         videoOutput.stopRecording()
//         // 結果はAVCaptureFileOutputRecordingDelegateで処理
//     }
//
//     // MARK: - カメラ性能情報取得
//     private func getCameraCapabilities(result: @escaping FlutterResult) {
//         guard let camera = camera else {
//             result(["success": false, "error": "Camera not available"])
//             return
//         }
//
//         let capabilities = [
//             "minExposure": camera.minExposureTargetBias,
//             "maxExposure": camera.maxExposureTargetBias,
//             "maxZoom": camera.activeFormat.videoMaxZoomFactor,
//             "hasFlash": camera.hasFlash,
//             "hasTorch": camera.hasTorch
//         ] as [String : Any]
//
//         result(capabilities)
//     }
//
//     // MARK: - カメラ制御
//     private func pauseCamera(result: @escaping FlutterResult) {
//         captureSession?.stopRunning()
//         result(["success": true])
//     }
//
//     private func resumeCamera(result: @escaping FlutterResult) {
//         DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//             self?.captureSession?.startRunning()
//         }
//         result(["success": true])
//     }
//
//     private func dispose(result: @escaping FlutterResult) {
//         captureSession?.stopRunning()
//         captureSession = nil
//         camera = nil
//         cameraInput = nil
//         photoOutput = nil
//         videoOutput = nil
//         previewLayer = nil
//         result(["success": true])
//     }
// }
//
// // MARK: - 写真撮影デリゲート
// class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
//     private let completion: (Data?, Error?) -> Void
//
//     init(completion: @escaping (Data?, Error?) -> Void) {
//         self.completion = completion
//     }
//
//     func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//         if let error = error {
//             completion(nil, error)
//             return
//         }
//
//         guard let imageData = photo.fileDataRepresentation() else {
//             completion(nil, NSError(domain: "PhotoCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image data"]))
//             return
//         }
//
//         completion(imageData, nil)
//     }
// }
//
// // MARK: - 動画撮影デリゲート
// extension NativeCameraHandler: AVCaptureFileOutputRecordingDelegate {
//     func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
//         isRecording = false
//
//         if let error = error {
//             // エラー処理をFlutterに通知
//             methodChannel?.invokeMethod("onVideoRecordingError", arguments: ["error": error.localizedDescription])
//         } else {
//             // 成功をFlutterに通知
//             methodChannel?.invokeMethod("onVideoRecordingComplete", arguments: ["videoPath": outputFileURL.path])
//         }
//     }
// }