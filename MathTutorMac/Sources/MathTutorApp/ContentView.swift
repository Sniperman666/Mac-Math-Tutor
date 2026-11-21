import AppKit
import MathTutorCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: TutorViewModel
    @State private var isImportingImage = false
    @State private var showHistory = false

    var body: some View {
        NavigationView {
            InputPanel(isImportingImage: $isImportingImage)
                .frame(minWidth: 340)
                .disabled(viewModel.isWorking)
            SolutionPanel()
        }
        .frame(minWidth: 920, minHeight: 640)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isImportingImage = true
                } label: {
                    Label("Import image", systemImage: "photo")
                }
                .disabled(viewModel.isWorking)
                Button {
                    showHistory.toggle()
                } label: {
                    Label("History", systemImage: "clock")
                }
                .disabled(viewModel.history.isEmpty || viewModel.isWorking)
            }
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet()
        }
        .fileImporter(
            isPresented: $isImportingImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                viewModel.recognizeImage(at: url)
            case let .failure(error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct InputPanel: View {
    @EnvironmentObject private var viewModel: TutorViewModel
    @Binding var isImportingImage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Math Tutor")
                    .font(.largeTitle.bold())
                Text("Enter a problem to get an answer and worked explanation, locally.")
                    .foregroundColor(.secondary)
            }

            Picker("Input method", selection: $viewModel.selectedInputMode) {
                ForEach(InputMode.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            if viewModel.selectedInputMode == .type {
                TextEditor(text: $viewModel.problem)
                    .font(.system(.title3, design: .monospaced))
                    .frame(minHeight: 170)
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                    .overlay(
                        Group {
                            if viewModel.problem.isEmpty {
                                Text("Try 2x + 4 = 10 or “area of a circle with radius 4”")
                                    .foregroundColor(.secondary)
                                    .padding(18)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )

                HStack {
                    Button("Paste") { viewModel.pasteProblem() }
                    Button("Use image") { isImportingImage = true }
                }
            } else {
                HandwritingPad()
                    .frame(height: 230)
            }

            if viewModel.recognitionNeedsReview {
                Label("Review the recognized text before solving. OCR can confuse ×, x, fractions, and exponents.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundColor(.orange)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .foregroundColor(.red)
            }

            Button {
                viewModel.solve()
            } label: {
                HStack {
                    if viewModel.isWorking {
                        ProgressView().controlSize(.small)
                    }
                    Text(viewModel.isWorking ? "Working…" : "Solve and explain")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(DefaultButtonStyle())
            .controlSize(.large)
            .disabled(viewModel.problem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isWorking)

            ExampleProblems()
            Spacer()
        }
        .padding(24)
    }
}

private struct ExampleProblems: View {
    @EnvironmentObject private var viewModel: TutorViewModel
    private let examples = [
        "2x + 4 = 10",
        "x^2 - 5x + 6 = 0",
        "differentiate x^3 + 2x",
        "mean 8, 10, 12, 14",
        "area of a circle with radius 4"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try an example")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    Button(example) { viewModel.loadExample(example) }
                        .buttonStyle(DefaultButtonStyle())
                }
            }
        }
    }
}

private struct SolutionPanel: View {
    @EnvironmentObject private var viewModel: TutorViewModel

    var body: some View {
        Group {
            if let solution = viewModel.solution {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Label(solution.subject, systemImage: "function")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.blue.opacity(0.12)))
                            Spacer()
                            Button("Copy worked solution") { viewModel.copySolution() }
                        }
                        Text(solution.interpretation)
                            .font(.title2.weight(.semibold))
                        Text("Problem: \(solution.originalProblem)")
                            .foregroundColor(.secondary)
                        Divider()
                        ForEach(solution.steps.indices, id: \.self) { index in
                            StepCard(index: index + 1, step: solution.steps[index])
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Answer")
                                .font(.headline)
                            Text(solution.answer)
                                .font(.system(.title, design: .rounded).weight(.bold))
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.12)))
                        Label("Use these steps to understand the method and explain the work in your own words.", systemImage: "lightbulb")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(28)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("Your worked solution appears here")
                        .font(.title2.weight(.semibold))
                    Text("Enter an equation or a supported math question, then choose “Solve and explain.”")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 430)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Worked Solution")
    }
}

private struct StepCard: View {
    let index: Int
    let step: SolutionStep

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))
            VStack(alignment: .leading, spacing: 7) {
                Text(step.title)
                    .font(.headline)
                Text(step.explanation)
                    .foregroundColor(.secondary)
                Text(step.expression)
                    .font(.system(.title3, design: .monospaced))
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
    }
}

private struct HistorySheet: View {
    @EnvironmentObject private var viewModel: TutorViewModel
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            List(viewModel.history) { item in
                Button {
                    viewModel.solution = item
                    viewModel.problem = item.originalProblem
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(item.originalProblem).lineLimit(1)
                        Text("\(item.subject) · \(item.answer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Local history")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }
}
