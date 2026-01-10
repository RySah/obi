package hash

import "core:hash/xxhash"

import "core:fmt"

// NOTE(rysah): Ditching this in favor of the faster FastCDC (Fast Content-Defined Chunking) 
// https://en.wikipedia.org/wiki/Rolling_hash
//
// RABIN_POLY :: 0xAD93D23594C935
// RABIN_K    :: 53

// rabin_fingerprint :: proc(data: []byte) -> (fp: u64) {
//     fp = 0
//     for i := 0; i < len(data); i += 1 {
//         // Shift fp by 8 bits and add a new byte
//         fp = (fp << 8) | u64(data[i])

//         // Reduce modulo POLY
//         for j: i64 = 7; j >= 0; j -= 1 {
//             if fp & (1 << u64(RABIN_K + j)) != 0 {
//                 fp ~= RABIN_POLY << u64(j)
//             }
//         }
//     }
//     return
// }

FAST_CDC_GEAR      :: #load("Fast_CDC_GEAR.bin", []u8)
FAST_CDC_MIN_CHUNK ::  (8  * 1024)
FAST_CDC_AVG_CHUNK ::  (32 * 1024)
FAST_CDC_MAX_CHUNK ::  (128 * 1024)
FAST_CDC_MASK      ::  (FAST_CDC_AVG_CHUNK - 1)

@(init, private)
_init :: proc "contextless" () {
    assert_contextless(len(FAST_CDC_GEAR) == 256) // This indicates deployment failed as the GEAR bytes for FastCDC hasher is not the correct length of 256 bytes
}


