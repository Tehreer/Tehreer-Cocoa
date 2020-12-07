//
//  ViewController.swift
//  macDemo
//
//  Created by Tayyab Akram on 07/12/2020.
//

import Cocoa
import TehreerCocoa

enum TypefaceTag {
    static let tajNastaleeq = "TajNstaleeq"
}

class ViewController: NSViewController {
    @IBOutlet private weak var label: TLabel!

    func register(file: (name: String, type: String), forTag tag: String) {
        if let fullPath = Bundle.main.path(forResource: file.name, ofType: file.type),
           let typeface = Typeface(path: fullPath) {
            TypefaceManager.default.register(typeface, forTag: tag)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        register(file: ("TajNastaleeq", "ttf"), forTag: TypefaceTag.tajNastaleeq)

        label.typeface = TypefaceManager.default.typeface(forTag: TypefaceTag.tajNastaleeq)
        label.textSize = 40
        label.textColor = .blue
        label.text = "یہ ایک اردو فونٹ ہے۔"
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
