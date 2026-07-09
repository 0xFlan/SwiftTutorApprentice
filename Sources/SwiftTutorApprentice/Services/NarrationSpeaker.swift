// NarrationSpeaker.swift
// ------------------------------------------------------------
// Speaks narration out loud using macOS's built-in speech
// synthesizer (AVSpeechSynthesizer). Fully offline — no API, no
// audio files. Used by the lesson "walkthrough" to narrate each
// step as the code types itself in.
//
// The one tricky bit: AVSpeechSynthesizer is callback-based, but
// the walkthrough is written with async/await. So `speak(_:)` is
// an async function that suspends until the utterance finishes
// (or is stopped), bridging the delegate callback to a
// continuation.
// ------------------------------------------------------------

import Foundation
import AVFoundation

@MainActor
final class NarrationSpeaker: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak `text` and return once it has finished (or was stopped).
    func speak(_ text: String) async {
        let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            continuation = cont
            let utterance = AVSpeechUtterance(string: spoken)
            // Slightly slower than default for a calm, learnable pace.
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
            utterance.postUtteranceDelay = 0.15
            synthesizer.speak(utterance)
        }
    }

    /// Stop any current speech immediately. Resolves a pending `speak`.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            resume()
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        resume()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        resume()
    }

    /// Resume the pending continuation exactly once.
    private func resume() {
        let cont = continuation
        continuation = nil
        cont?.resume()
    }
}
