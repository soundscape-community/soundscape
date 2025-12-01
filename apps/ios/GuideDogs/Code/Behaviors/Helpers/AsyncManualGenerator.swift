//
//  AsyncManualGenerator.swift
//  Soundscape
//
//  Introduces an async variant of ManualGenerator so behaviors can
//  await callout playback without inlining event handling logic.
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

@available(*, deprecated, message: "AsyncManualGenerator has been folded into ManualGenerator. Conform directly to ManualGenerator instead.")
typealias AsyncManualGenerator = ManualGenerator
