// NarrationSpeaker.swift
// ------------------------------------------------------------
// Speaks narration out loud using macOS's built-in speech
// synthesizer (AVSpeechSynthesizer). Fully offline — no API, no
// audio files. Used by the authored lesson presentation player.
//
// The one tricky bit: AVSpeechSynthesizer is callback-based, but
// presentation playback uses async/await. So `speak(_:)` is
// an async function that suspends until the utterance finishes
// (or is stopped), bridging the delegate callback to a
// continuation.
// ------------------------------------------------------------

import Foundation
@preconcurrency import AVFoundation

struct NarrationVoiceSelection {
    let voice: AVSpeechSynthesisVoice?
}

@MainActor
protocol PresentationNarrating: AnyObject {
    func isAvailable(for locale: String) -> Bool
    func speak(_ text: String, locale: String) async
    func stop()
}

@MainActor
final class NarrationSpeaker: NSObject, PresentationNarrating,
    AVSpeechSynthesizerDelegate {

    private struct ActiveSpeech {
        let utterance: AVSpeechUtterance
        let continuation: CheckedContinuation<Void, Never>
    }

    private let synthesizer: AVSpeechSynthesizer?
    private let startSpeaking: (AVSpeechUtterance) -> Void
    private let stopSpeaking: () -> Void
    private let voiceResolver: (String) -> NarrationVoiceSelection?
    private var activeSpeech: ActiveSpeech?

    override init() {
        let synthesizer = AVSpeechSynthesizer()
        self.synthesizer = synthesizer
        self.startSpeaking = { synthesizer.speak($0) }
        self.stopSpeaking = {
            synthesizer.stopSpeaking(at: .immediate)
        }
        self.voiceResolver = Self.resolveInstalledVoice(for:)
        super.init()
        synthesizer.delegate = self
    }

    init(
        startSpeaking: @escaping (AVSpeechUtterance) -> Void,
        stopSpeaking: @escaping () -> Void,
        voiceResolver: @escaping (String) -> NarrationVoiceSelection?
    ) {
        self.synthesizer = nil
        self.startSpeaking = startSpeaking
        self.stopSpeaking = stopSpeaking
        self.voiceResolver = voiceResolver
        super.init()
    }

    func isAvailable(for locale: String) -> Bool {
        voiceResolver(locale) != nil
    }

    func speak(_ text: String) async {
        await speak(text, locale: Locale.current.identifier)
    }

    /// Speak `text` and return once it has finished (or was stopped).
    func speak(_ text: String, locale: String) async {
        guard Task.isCancelled == false else { return }
        let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty,
              let selection = voiceResolver(locale) else { return }
        guard Task.isCancelled == false else { return }
        if activeSpeech != nil {
            stop()
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let utterance = AVSpeechUtterance(string: spoken)
            utterance.voice = selection.voice
            // Slightly slower than default for a calm, learnable pace.
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
            utterance.postUtteranceDelay = 0.15
            activeSpeech = ActiveSpeech(
                utterance: utterance,
                continuation: cont
            )
            startSpeaking(utterance)
        }
    }

    /// Stop any current speech immediately. Resolves a pending `speak`.
    func stop() {
        let stoppedSpeech = activeSpeech
        activeSpeech = nil
        stopSpeaking()
        stoppedSpeech?.continuation.resume()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    /// Resume only the continuation belonging to this exact utterance.
    private func finish(_ utterance: AVSpeechUtterance) {
        guard let activeSpeech,
              activeSpeech.utterance === utterance else { return }
        self.activeSpeech = nil
        activeSpeech.continuation.resume()
    }

    private static func resolveInstalledVoice(
        for locale: String
    ) -> NarrationVoiceSelection? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .sorted { $0.identifier < $1.identifier }
        let requested = normalizedLanguageTag(locale)
        if let exact = voices.first(where: {
            normalizedLanguageTag($0.language) == requested
        }) {
            return NarrationVoiceSelection(voice: exact)
        }
        return nil
    }

    private static func normalizedLanguageTag(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}
