//
//  FluttedPDFView.swift
//

import Foundation
import Flutter
import PDFKit
import UIKit

enum PDFException: Error {
  case runtimeError(String)
}

// MARK: - FLTPDFViewFactory

class FLTPDFViewFactory: NSObject {
  private var messenger: FlutterBinaryMessenger!
  
  init(messenger: FlutterBinaryMessenger) {
    super.init()
    self.messenger = messenger
  }
  
  public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

// MARK: FlutterPlatformViewFactory protocol

extension FLTPDFViewFactory: FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let arguments: [String: Any]? = (args as? [String : Any]?) ?? [:];
    let pdfviewController: FLTPDFViewController! = FLTPDFViewController(frame: frame,
                                                                        viewIdentifier: viewId,
                                                                        arguments: arguments,
                                                                        binaryMessenger: messenger)
    return pdfviewController
  }
}

// MARK: - FLTPDFViewController

class FLTPDFViewController : NSObject, FlutterPlatformView, PDFViewDelegate {
  private var pdfView: FLTPDFView!
  private var viewId: Int64?
  private var channel: FlutterMethodChannel!
  
  init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: [String: Any]?, binaryMessenger messenger: FlutterBinaryMessenger) {
    super.init()
    
    let channelName = String(format:"plugins.endigo.io/pdfview_%lld", viewId)
    channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    
    channel.setMethodCallHandler {[weak self] flutterMethodCall, flutterResult in
      self?.onMethodCall(call: flutterMethodCall, result: flutterResult)
    }
    
    self.viewId = viewId
    
    pdfView = FLTPDFView(frame:frame, arguments: args, controler: self)
  }
  
  func onMethodCall(call: FlutterMethodCall!, result: FlutterResult) {
    if (call.method == "pageCount") {
      pdfView.getPageCount(call: call, result:result)
    } else if (call.method == "currentPage") {
      pdfView.getCurrentPage(call: call, result:result)
    } else if (call.method == "setPage") {
      pdfView.setPage(call: call, result:result)
    } else if (call.method == "updateSettings") {
      pdfView.onUpdateSettings(call: call, result:result)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
  
  func invokeChannelMethod(name: String, arguments args: Any) {
    channel.invokeMethod(name, arguments: args)
  }
  
  func view() -> UIView {
    return pdfView
  }
}

// MARK: - FLTPDFViewArguments

fileprivate class FLTPDFViewArguments {
  var pageFling: Bool
  var enableSwipe: Bool
  var swipeHorizontal: Bool
  var preventLinkNavigation: Bool
  var autoSpacing: Bool
  var defaultPageNumber: Int
  var password: String?
  var filePath: String?
  var pdfData: FlutterStandardTypedData?
  
  init(fromMap map: [String: Any]) {
    self.pageFling = map["pageFling"] as? Bool ?? false
    self.enableSwipe = map["enableSwipe"] as? Bool ?? false
    self.swipeHorizontal = map["swipeHorizontal"] as? Bool ?? false
    self.preventLinkNavigation = map["preventLinkNavigation"] as? Bool ?? false
    self.autoSpacing = map["autoSpacing"] as? Bool ?? false
    self.defaultPageNumber = map["defaultPage"] as? Int ?? 0
    self.filePath = map["filePath"] as? String
    self.pdfData = map["pdfData"] as? FlutterStandardTypedData
  }
}

// MARK: - FLTPDFView

class FLTPDFView : UIView {
  private weak var controller: FLTPDFViewController!
  private var pdfView: PDFView!
  private var pageCount: Int!
  private var currentPage: Int!
  private var currentDestination: PDFDestination!
  private var viewArguments: FLTPDFViewArguments!
  private var defaultPage: PDFPage!
  private var wasDefaultPageSetted: Bool = false
  
  
  init(frame: CGRect, arguments args: Any?, controler: FLTPDFViewController) {
    super.init(frame: frame)
    
    controller = controler
    
    pdfView = PDFView(frame:frame)
    pdfView.delegate = self
    
    guard let argumentsMap = args as? [String: Any] else { return }
    viewArguments = FLTPDFViewArguments(fromMap: argumentsMap)
    
    var document: PDFDocument!
    if let filePath = viewArguments.filePath {
      let sourcePDFUrl = URL(fileURLWithPath: filePath)
      document = PDFDocument(url: sourcePDFUrl)
      UIApplication.shared.open(sourcePDFUrl)
      
    } else if let pdfData = viewArguments.pdfData {
      let sourcePDFdata = pdfData.data
      document = PDFDocument(data: sourcePDFdata)
    }
    
    if document == nil {
      controller.invokeChannelMethod(name: "onError",
                                     arguments: ["error": "cannot create document: File not in PDF format or corrupted."])
    } else {
      pdfView.autoresizesSubviews = true
      pdfView.autoresizingMask = UIView.AutoresizingMask.flexibleWidth
      pdfView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
      
      if viewArguments.swipeHorizontal {
        pdfView.displayDirection = PDFDisplayDirection.horizontal
      } else {
        pdfView.displayDirection = PDFDisplayDirection.vertical
      }
      
      pdfView.autoScales = viewArguments.autoSpacing
      
      pdfView.usePageViewController(viewArguments.pageFling, withViewOptions: nil)
      pdfView.displayMode = viewArguments.enableSwipe ? PDFDisplayMode.singlePageContinuous : PDFDisplayMode.singlePage
      pdfView.document = document
      
      pdfView.maxScaleFactor = 4.0
      pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
      
      if let password = viewArguments.password,
         (pdfView.document?.isEncrypted) ?? false {
        pdfView?.document?.unlock(withPassword: password)
      }
      
      let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.onDoubleTap(recognizer:)))
      tapGestureRecognizer.numberOfTapsRequired = 2
      tapGestureRecognizer.numberOfTouchesRequired = 1
      pdfView.addGestureRecognizer(tapGestureRecognizer)
      
      if let pageCount = pdfView.document?.pageCount {
        var defaultPageNumber = viewArguments.defaultPageNumber
        
        if pageCount <= defaultPageNumber {
          defaultPageNumber = pageCount - 1
        }
        
        defaultPage = document.page(at: defaultPageNumber)
      }
      
      DispatchQueue.main.async(qos: .background) { [weak self] in
        self?.handleRenderCompleted(pagesCount: document.pageCount)
      }
    }
    
    if #available(iOS 11.0, *) {
      var scrollView: UIScrollView!
      
      for subview: AnyObject in pdfView.subviews {
        if let view = subview as? UIScrollView {
          scrollView = view
        }
      }
      
      scrollView.contentInsetAdjustmentBehavior = UIScrollView.ContentInsetAdjustmentBehavior.never
      if #available(iOS 13.0, *) {
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
      }
    }
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(self.handlePageChanged(notification:)),
                                           name: NSNotification.Name.PDFViewPageChanged,
                                           object:pdfView)
    self.addSubview(pdfView)
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    pdfView.frame = self.frame
    pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
    pdfView.maxScaleFactor = 4.0
    if viewArguments.autoSpacing {
      pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
    }
    
    if !wasDefaultPageSetted && defaultPage != nil {
      pdfView.go(to: defaultPage)
      wasDefaultPageSetted = true
    }
  }
  
  override func removeFromSuperview() {
    NotificationCenter.default.removeObserver(self)
  }
  
  func getPageCount(call: FlutterMethodCall, result: FlutterResult) {
    pageCount = pdfView.document?.pageCount
    result(pageCount)
  }
  
  func getCurrentPage(call: FlutterMethodCall, result: FlutterResult) {
    currentPage = pdfView.document?.index(for: pdfView.currentPage!)
    result(currentPage)
  }
  
  func setPage(call: FlutterMethodCall, result: FlutterResult) {
    guard
      let arguments = call.arguments as? [String : Any],
      let pageNumber = arguments["page"] as? Int,
      let page = pdfView.document?.page(at: pageNumber)
    else { return result(false) }
    
    pdfView.go(to: page)
    result(true)
  }
  
  func onUpdateSettings(call:FlutterMethodCall, result:FlutterResult) {
    result(nil)
  }
  
  @objc func handlePageChanged(notification: NSNotification!) {
    guard
      let currentPage = pdfView.currentPage,
      let pageCount = pdfView.document?.pageCount,
      let pageIndex = pdfView.document?.index(for: currentPage)
    else { return }
    
    let arguments = ["page": pageIndex, "total": pageCount]
    controller.invokeChannelMethod(name: "onPageChanged", arguments: arguments)
  }
  
  func handleRenderCompleted(pagesCount: Int!) {
    guard let count = pagesCount else { return }
    controller.invokeChannelMethod(name: "onRender", arguments: ["pages" : count])
  }
  
  @objc func onDoubleTap(recognizer: UITapGestureRecognizer!) {
    if recognizer.state == UIGestureRecognizer.State.ended {
      if pdfView.scaleFactor == pdfView.scaleFactorForSizeToFit {
        let point: CGPoint = recognizer.location(in: pdfView)
        guard let page: PDFPage = pdfView.page(for: point, nearest: true) else { return }
        
        let pdfPoint: CGPoint = pdfView.convert(point, to: page)
        let rect: CGRect = page.bounds(for: PDFDisplayBox.mediaBox)
        let destination: PDFDestination = PDFDestination(page: page,
                                                         at: CGPointMake(pdfPoint.x - (rect.size.width / 4), pdfPoint.y + (rect.size.height / 4)))
        
        UIView.animate(withDuration: 0.2, animations: { [self] in
          pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit * 2
          pdfView.go(to: destination)
        })
      } else {
        UIView.animate(withDuration: 0.2, animations: { [self] in
          pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        })
      }
    }
  }
}

// MARK: PDFViewDelegate protocol

extension FLTPDFView: PDFViewDelegate {
  func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
    if !viewArguments.preventLinkNavigation {
      UIApplication.shared.open(url)
    }
    controller.invokeChannelMethod(name: "onLinkHandler", arguments: url.absoluteString)
  }
}

// MARK: FlutterPlatformView protocol

extension FLTPDFView: FlutterPlatformView {
  func view() -> UIView {
    return pdfView
  }
}
