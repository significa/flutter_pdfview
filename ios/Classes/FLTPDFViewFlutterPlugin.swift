//
//  PDFViewFlutterPlugin.swift
//  flutter_pdfview
//
//  Created by Daniel Almeida on 01/08/2023.
//

import Flutter
import UIKit

public class FLTPDFViewFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = FLTPDFViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "plugins.endigo.io/pdfview")
  }  
}
