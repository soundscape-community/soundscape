//
//  Soundscape-Bridging-Header.h
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

// External
#import <SDWebImage/UIImageView+WebCache.h>

// Helpers
#import "GDAJSONObject.h"
#import "ObjCExceptionHandling.h"

// The AVAudioPlayerNode callback only publishes a flag. The audio control queue reads it.
#include <stdint.h>
_Static_assert(__atomic_always_lock_free(sizeof(uint32_t), 0), "Audio completion must be lock-free");

static inline void SoundscapeAudioSignal(uint32_t *flag) {
    __atomic_store_n(flag, 1, __ATOMIC_RELEASE);
}

static inline bool SoundscapeAudioDidSignal(const uint32_t *flag) {
    return __atomic_load_n(flag, __ATOMIC_ACQUIRE) != 0;
}
