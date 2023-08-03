//
//  PDFViewFlutterPlugin.swift
//


import Flutter
import UIKit

public class FLTPDFViewFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = FLTPDFViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "plugins.endigo.io/pdfview")
  }  
}
