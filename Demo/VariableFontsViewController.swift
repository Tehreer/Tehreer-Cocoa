//
// Copyright (C) 2021 Muhammad Tayyab Akram
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import TehreerCocoa
import UIKit

private enum CellID {
    static let axis = "AxisCell"
}

class VariationAxisCell: UITableViewCell {
    @IBOutlet weak var axisButton: UIButton!
    @IBOutlet weak var minValueLabel: UILabel!
    @IBOutlet weak var coordinateSlider: UISlider!
    @IBOutlet weak var maxValueLabel: UILabel!

    private var onValueChanged: ActionCallback!

    fileprivate func configure(with axis: VariationAxis, coordinate: CGFloat, onValueChanged: @escaping ActionCallback) {
        axisButton.setTitle(axis.name, for: .normal)
        minValueLabel.text = "\(axis.minValue)"
        maxValueLabel.text = "\(axis.maxValue)"

        coordinateSlider.minimumValue = Float(axis.minValue)
        coordinateSlider.maximumValue = Float(axis.maxValue)
        coordinateSlider.value = Float(coordinate)
        coordinateSlider.addTarget(self, action: #selector(coordinateValueChanged(_:)), for: .valueChanged)

        self.onValueChanged = onValueChanged
    }

    @objc private func coordinateValueChanged(_ sender: Any) {
        onValueChanged?()
    }
}

class VariableFontsViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet private weak var typefaceField: UITextField!
    @IBOutlet private weak var instanceField: UITextField!
    @IBOutlet private weak var axisTableView: UITableView!
    @IBOutlet private weak var previewLabel: TLabel!

    @IBOutlet private weak var typefacePicker: UIPickerView!
    @IBOutlet private weak var typefaceToolbar: UIToolbar!
    @IBOutlet private weak var instancePicker: UIPickerView!
    @IBOutlet private weak var instanceToolbar: UIToolbar!

    private var fileNames: [String] = []
    private var fontFiles: [FontFile] = []
    private var instances: [Typeface] = []

    private var typeface: Typeface?
    private var variationAxes: [VariationAxis] = []
    private var variationCoordinates: [CGFloat] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        typefaceField.inputView = typefacePicker
        typefaceField.inputAccessoryView = typefaceToolbar
        instanceField.inputView = instancePicker
        instanceField.inputAccessoryView = instanceToolbar

        previewLabel.text = "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789"
        previewLabel.textSize = 56.0
        previewLabel.verticalAlignment = .middle

        loadFontFiles()
        setupFont(at: 0)
    }

    private func loadFontFiles() {
        guard let bundlePath = Bundle.main.path(forResource: "VFonts", ofType: "bundle"),
              let fileNames = (try? FileManager.default.contentsOfDirectory(atPath: bundlePath))?.sorted(),
              let fontBundle = Bundle(path: bundlePath) else {
            return
        }

        self.fileNames = fileNames

        for i in 0 ..< fileNames.count {
            let components = fileNames[i].components(separatedBy: ".")

            guard let fullPath = fontBundle.path(forResource: components.first, ofType: components.last),
                  let inputStream = InputStream(fileAtPath: fullPath),
                  let fontFile = FontFile(stream: inputStream) else {
                continue
            }

            fontFiles.append(fontFile)
        }
    }

    private func fontName(at index: Int) -> String {
        return fileNames[index].components(separatedBy: ".").first ?? ""
    }

    private func setupFont(at index: Int) {
        let fontFile = fontFiles[index]

        guard let firstFace = fontFile.typefaces.first else {
            return
        }

        instances = fontFile.typefaces
        variationAxes = firstFace.variationAxes

        typefaceField.text = fontName(at: index)
        instancePicker.reloadAllComponents()

        setupTypeface(firstFace)
    }

    private func setupTypeface(_ face: Typeface) {
        typeface = face
        variationCoordinates = typeface?.variationCoordinates ?? []

        instanceField.text = typeface?.styleName
        axisTableView.reloadData()

        updatePreview()
    }

    private func setupCoordinate(_ coordinate: CGFloat, forAxis axisIndex: Int) {
        variationCoordinates[axisIndex] = coordinate
        typeface = typeface?.variationInstance(forCoordinates: variationCoordinates)

        updatePreview()
    }

    private func updatePreview() {
        previewLabel.typeface = typeface
    }

    // MARK: - Actions

    @IBAction private func doneButtonPressed(_ sender: Any) {
        view.endEditing(true)
    }

    // MARK: - UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView === typefacePicker {
            return fileNames.count
        }
        if pickerView === instancePicker {
            return instances.count
        }

        return 0
    }

    // MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView === typefacePicker {
            return fontName(at: row)
        }
        if pickerView === instancePicker {
            return instances[row].styleName
        }

        return nil
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView === typefacePicker {
            setupFont(at: row)
            return
        }
        if pickerView === instancePicker {
            setupTypeface(instances[row])
            return
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return variationAxes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellID.axis, for: indexPath) as! VariationAxisCell
        cell.configure(with: variationAxes[indexPath.row], coordinate: variationCoordinates[indexPath.row]) { [weak self] in
            self?.setupCoordinate(CGFloat(cell.coordinateSlider.value), forAxis: indexPath.row)
        }

        return cell
    }
}
