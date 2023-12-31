//
//  SDKQuickstartViewController.swift
//  InteractiveLiveStreaming
//
//  Created by Bradley Hoang on 14/06/2023.
//

import UIKit
import AVFoundation
import AgoraRtcKit


class SDKQuickstartViewController: UIViewController {
  // The main entry point for Video SDK
  var agoraEngine: AgoraRtcEngineKit!
  // By default, set the current user role to broadcaster to both send and receive streams.
  var userRole: AgoraClientRole = .broadcaster
  
  // Update with the App ID of your project generated on Agora Console.
  let appID = "c16fc101b1bd482a8533831e5057ebff"
  // Update with the temporary token generated in Agora Console.
  var token = "007eJxTYKiXPMbPJCziVjVTfvOO8Mkvbyl8sFqkIBLnt9Bn/zTX3QsUGJINzdKSDQ0MkwyTUkwsjBItTI2NLYwNU00NTM1Tk9LSfHd1pjQEMjIEcAgwMTJAIIjPBNTJwAAASwcbZg=="
  // Update with the channel name you used to generate the token in Agora Console.
  var channelName = "c1"
  
  // The video feed for the local user is displayed here
  var localView: UIView!
  // The video feed for the remote user is displayed here
  var remoteView: UIView!
  // Click to join or leave a call
  var joinButton: UIButton!
  // Choose to be broadcaster or audience
  var role: UISegmentedControl!
  // Track if the local user is in a call
  var joined: Bool = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
    initViews()
    initializeAgoraEngine()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    leaveChannel()
    DispatchQueue.global(qos: .userInitiated).async {AgoraRtcEngineKit.destroy()}
  }
  
  func joinChannel() async {
    if await !self.checkForPermissions() {
      showMessage(title: "Error", text: "Permissions were not granted")
      return
    }
    
    let option = AgoraRtcChannelMediaOptions()
    
    // Set the client role option as broadcaster or audience.
    if self.userRole == .broadcaster {
      option.clientRoleType = .broadcaster
      setupLocalVideo()
    } else {
      option.clientRoleType = .audience
    }
    // For a live streaming scenario, set the channel profile as liveBroadcasting.
    option.channelProfile = .liveBroadcasting
    // Join the channel with a temp token. Pass in your token and channel name here
    let result = agoraEngine.joinChannel(
      byToken: token, channelId: channelName, uid: 0, mediaOptions: option,
      joinSuccess: { (channel, uid, elapsed) in }
    )
    // Check if joining the channel was successful and set joined Bool accordingly
    if result == 0 {
      joined = true
      showMessage(title: "Success", text: "Successfully joined the channel as \(self.userRole)")
    }
  }
  
  func leaveChannel() {
    agoraEngine.stopPreview()
    let result = agoraEngine.leaveChannel(nil)
    // Check if leaving the channel was successful and set joined Bool accordingly
    if result == 0 { joined = false }
  }
  
  
  func initializeAgoraEngine() {
    let config = AgoraRtcEngineConfig()
    // Pass in your App ID here.
    config.appId = appID
    // Use AgoraRtcEngineDelegate for the following delegate parameter.
    agoraEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
  }
  
  func setupLocalVideo() {
    // Enable the video module
    agoraEngine.enableVideo()
    // Start the local video preview
    agoraEngine.startPreview()
    let videoCanvas = AgoraRtcVideoCanvas()
    videoCanvas.uid = 0
    videoCanvas.renderMode = .hidden
    videoCanvas.view = localView
    // Set the local video view
    agoraEngine.setupLocalVideo(videoCanvas)
  }
  
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    remoteView.frame = CGRect(x: 20, y: 50, width: 350, height: 330)
    localView.frame = CGRect(x: 20, y: 400, width: 350, height: 330)
  }
  
  func initViews() {
    // Initializes the remote video view. This view displays video when a remote host joins the channel.
    remoteView = UIView()
    self.view.addSubview(remoteView)
    // Initializes the local video window. This view displays video when the local user is a host.
    localView = UIView()
    self.view.addSubview(localView)
    //  Button to join or leave a channel
    joinButton = UIButton(type: .system)
    joinButton.frame = CGRect(x: 140, y: 700, width: 100, height: 50)
    joinButton.setTitle("Join", for: .normal)
    
    joinButton.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
    self.view.addSubview(joinButton)
    
    // Selector to be the host or the audience
    role = UISegmentedControl(items: ["Broadcast", "Audience"])
    role.frame = CGRect(x: 20, y: 740, width: 350, height: 40)
    role.selectedSegmentIndex = 0
    role.addTarget(self, action: #selector(roleAction), for: .valueChanged)
    self.view.addSubview(role)
  }
  
  @objc func buttonAction(sender: UIButton!) {
    if !joined {
      sender.isEnabled = false
      Task {
        await joinChannel()
        sender.isEnabled = true
      }
    } else {
      leaveChannel()
    }
  }
  
  @objc func roleAction(sender: UISegmentedControl!) {
    self.userRole = sender.selectedSegmentIndex == 0 ? .broadcaster : .audience
  }
  
  
  func checkForPermissions() async -> Bool {
    var hasPermissions = await self.avAuthorization(mediaType: .video)
    // Break out, because camera permissions have been denied or restricted.
    if !hasPermissions { return false }
    hasPermissions = await self.avAuthorization(mediaType: .audio)
    return hasPermissions
  }
  
  func avAuthorization(mediaType: AVMediaType) async -> Bool {
    let mediaAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: mediaType)
    switch mediaAuthorizationStatus {
    case .denied, .restricted: return false
    case .authorized: return true
    case .notDetermined:
      return await withCheckedContinuation { continuation in
        AVCaptureDevice.requestAccess(for: mediaType) { granted in
          continuation.resume(returning: granted)
        }
      }
    @unknown default: return false
    }
  }
  
  func showMessage(title: String, text: String, delay: Int = 2) -> Void {
    let deadlineTime = DispatchTime.now() + .seconds(delay)
    DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
      let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
      self.present(alert, animated: true)
      alert.dismiss(animated: true, completion: nil)
    })
  }
  
}

extension SDKQuickstartViewController: AgoraRtcEngineDelegate {
  // Callback called when a new host joins the channel
  func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
    let videoCanvas = AgoraRtcVideoCanvas()
    videoCanvas.uid = uid
    videoCanvas.renderMode = .hidden
    videoCanvas.view = remoteView
    agoraEngine.setupRemoteVideo(videoCanvas)
  }
}
