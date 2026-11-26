//
//  AudioEngineAsset.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//


/// `AudioEngineAsset`s are objects that wrap up all the information needed for loading
/// and playing audio files. Objects that implement this protocol are intended to be enums
/// where each case corresponds to an audio asset and all cases share the same file type.
/// See `StaticAudioEngineAsset.swift`.
protocol AudioEngineAsset: RawRepresentable {
    /// Name of the asset
    var name: String { get }
    
    /// File type of the asset
    var type: String { get }
}

extension AudioEngineAsset where RawValue == String {
    
    // MARK: Asset Name Helper
    
    var name: String {
        return rawValue
    }
    
}

extension AudioEngineAsset {
    
    /// Defaults all audio engine assets to be wav files. If non-wav audio assets are added, they will
    /// need to override this default for the `type` property and possibly also the default implementation
    /// of `load()` to accommodate for their new file format.
    var type: String {
        return "wav"
    }
    
    var audioAsset: AudioAsset { .bundle(name: name, extension: type) }
}
