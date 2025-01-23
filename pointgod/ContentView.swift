//
//  ContentView.swift
//  pointgod
//
//  Created by Rui Fu on 1/20/25.
//  With help from chatgpt
//  Board Game Scoring App

import SwiftUI
import Vision
import UIKit
import AVFoundation

struct ContentView: View {
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var preprocessedImage: UIImage? = nil
    @State private var detectedNumbers: [DetectedNumber] = []
    @State private var totalScore: Int = 0
    @State private var history: [(image: UIImage, score: Int)] = []
    @State private var isCameraSource = true

    var body: some View {
        NavigationView {
            VStack {
                if let image = preprocessedImage {
                    ZStack {
                        GeometryReader { geometry in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()

                            ForEach(detectedNumbers, id: \ .id) { number in
                                let scaleX = geometry.size.width / image.size.width
                                let scaleY = geometry.size.height / image.size.height
                                let scaledPositionX = number.position.x * scaleX
                                let scaledPositionY = number.position.y * scaleY
                                let scaledWidth = number.size.width * scaleX
                                let scaledHeight = number.size.height * scaleY

                                ZStack {
                                    Rectangle()
                                        .fill(number.isSelected ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                                        .frame(width: scaledWidth, height: scaledHeight)
                                        .position(x: scaledPositionX, y: scaledPositionY)
                                        .onTapGesture {
                                            toggleNumberSelection(for: number)
                                        }

                                    Text(number.value)
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.black.opacity(0.7))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                        .position(x: scaledPositionX, y: scaledPositionY)
                                }
                            }
                        }
                    }
                } else {
                    Text("Select or capture a board game image to detect scores.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                if !detectedNumbers.isEmpty {
                    Text("Detected Numbers:")
                        .font(.headline)

                    List(detectedNumbers.map { $0.value }, id: \ .self) { number in
                        Text(number)
                    }

                    Text("Total Score: \(totalScore)")
                        .font(.title)
                        .padding(.top)
                }

                Spacer()

                HStack {
                    Button(action: {
                        isCameraSource = true
                        showImagePicker = true
                    }) {
                        Text("Capture Image")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        isCameraSource = false
                        showImagePicker = true
                    }) {
                        Text("Select from Photos")
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    NavigationLink(destination: HistoryView(history: history)) {
                        Text("History")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Board Game Scoring")
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, onImageSelected: detectText, sourceType: isCameraSource ? .camera : .photoLibrary)
        }
    }

    func detectText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        detectedNumbers = [] // Reset detected numbers
        totalScore = 0 // Reset total score

        // Preprocess the image
        preprocessedImage = preprocessImage(image)
        guard let processedCGImage = preprocessedImage?.cgImage else { return }

        // Segment the image into regions and process each region
        let regions = segmentImage(processedCGImage)
        for region in regions {
            processRegion(region)
        }

        DispatchQueue.main.async {
            // Add to history
            if history.count >= 10 {
                history.removeFirst()
            }
            if let preprocessedImage = preprocessedImage {
                history.append((image: preprocessedImage, score: totalScore))
            }
        }
    }

    func preprocessImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        // Convert to grayscale
        let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono")!
        grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)

        // Adjust brightness and contrast moderately to avoid darkening
        let colorControlsFilter = CIFilter(name: "CIColorControls")!
        colorControlsFilter.setValue(grayscaleFilter.outputImage, forKey: kCIInputImageKey)
        colorControlsFilter.setValue(1.2, forKey: "inputContrast")
        colorControlsFilter.setValue(0.1, forKey: "inputBrightness")

        let context = CIContext()
        guard let outputImage = colorControlsFilter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    func segmentImage(_ image: CGImage) -> [CGRect] {
            let request = VNDetectTextRectanglesRequest()
            request.reportCharacterBoxes = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])

            guard let observations = request.results as? [VNTextObservation] else { return [] }

            return observations.compactMap { $0.boundingBox }.map { boundingBox in
                let x = boundingBox.origin.x * CGFloat(image.width)
                let y = (1 - boundingBox.origin.y - boundingBox.size.height) * CGFloat(image.height)
                let width = boundingBox.size.width * CGFloat(image.width)
                let height = boundingBox.size.height * CGFloat(image.height)

                return CGRect(x: x, y: y, width: width, height: height)
            }
        }

        func processRegion(_ region: CGRect) {
            // Placeholder function for processing each region of the image.
            // Replace with actual OCR logic as needed.

            // For demonstration, adding dummy numbers for each region
            let randomValue = Int.random(in: 1...100)
            let detectedNumber = DetectedNumber(
                id: UUID(),
                value: "\(randomValue)",
                position: CGPoint(x: region.midX, y: region.midY),
                size: CGSize(width: region.width, height: region.height),
                isSelected: true
            )

            detectedNumbers.append(detectedNumber)
            totalScore += randomValue
        }

        func toggleNumberSelection(for number: DetectedNumber) {
            if let index = detectedNumbers.firstIndex(where: { $0.id == number.id }) {
                detectedNumbers[index].isSelected.toggle()
                totalScore += detectedNumbers[index].isSelected ? Int(detectedNumbers[index].value) ?? 0 : -(Int(detectedNumbers[index].value) ?? 0)
            }
        }
    }

    struct HistoryView: View {
        var history: [(image: UIImage, score: Int)]

        var body: some View {
            List(history.indices, id: \ .self) { index in
                let entry = history[index]
                VStack(alignment: .leading) {
                    Text("Image \(index + 1)")
                        .font(.headline)
                    Text("Score: \(entry.score)")
                        .font(.subheadline)

                    Image(uiImage: entry.image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                }
                .padding()
            }
            .navigationTitle("History")
        }
    }

    struct DetectedNumber: Identifiable {
        let id: UUID
        let value: String
        let position: CGPoint
        let size: CGSize
        var isSelected: Bool
    }

    struct ImagePicker: UIViewControllerRepresentable {
        @Binding var image: UIImage?
        var onImageSelected: (UIImage) -> Void
        var sourceType: UIImagePickerController.SourceType

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.sourceType = sourceType
            return picker
        }

        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

        class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let parent: ImagePicker

            init(_ parent: ImagePicker) {
                self.parent = parent
            }

            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
                if let selectedImage = info[.originalImage] as? UIImage {
                    parent.image = selectedImage
                    parent.onImageSelected(selectedImage)
                }
                picker.dismiss(animated: true)
            }

            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                picker.dismiss(animated: true)
            }
        }
    }
