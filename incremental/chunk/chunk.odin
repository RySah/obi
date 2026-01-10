package chunk

import "core:hash/xxhash"

import "core:fmt"

// NOTE(rysah): Ditching this in favor of the faster FastCDC (Fast Content-Defined Chunking) 
// https://en.wikipedia.org/wiki/Rolling_hash
//
// RABIN_POLY :: 0xAD93D23594C935
// RABIN_K    :: 53
// 
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

FASTCDC_GEAR_BINARY :: #load("Fast_CDC_GEAR.bin", []u8)
FASTCDC_GEAR        : []byte

@(init, private)
_init :: proc "contextless" () {
    FASTCDC_GEAR = FASTCDC_GEAR_BINARY
    assert_contextless(len(FASTCDC_GEAR) == 256) // This indicates deployment failed as the GEAR bytes for FastCDC hasher is not the correct length of 256 bytes
}

FASTCDC_MIN_CHUNK ::  (8  * 1024)
FASTCDC_AVG_CHUNK ::  (32 * 1024)
FASTCDC_MAX_CHUNK ::  (128 * 1024)
FASTCDC_MASK      ::  (FASTCDC_AVG_CHUNK - 1)

FastCDC_Chunk_Callback :: #type proc(offset, size: int, client_data: rawptr)

fastcdc_chunk :: proc(
    data: []byte, 
    cb: FastCDC_Chunk_Callback, 
    client_data: rawptr
) {
    pos := 0
    data_len := len(data)

    for pos < data_len {
        start := pos
        hash: u32 = 0

        limit := pos + FASTCDC_MAX_CHUNK
        if limit > data_len do limit = data_len

        min_end := pos + FASTCDC_MIN_CHUNK
        if min_end > data_len do min_end = data_len

        for pos < limit {
            hash = (hash << 1) + u32(FASTCDC_GEAR[data[pos]])
            pos += 1

            if pos >= min_end && (hash & FASTCDC_MASK) == 0 {
                break
            }
        }

        cb(start, pos-start, client_data)
    }
}

Chunk_Sig :: struct {
    hash: u64,
    size: u32
}

Sig_Builder :: struct {
    data: []byte,
    out: []Chunk_Sig,
    count: int
}

@private _on_chunk :: proc(off, size: int, client_data: rawptr) {
    b := transmute(^Sig_Builder)client_data
    if b.count >= len(b.out) do return

    h := xxhash.XXH3_64(b.data[off:size])
    i := b.count
    b.count += 1
    b.out[i] = { hash=h, size=u32(size) }
}

build_sig :: proc(data: []byte, buf: []Chunk_Sig) -> []Chunk_Sig {
    b := Sig_Builder {
        data = data,
        out = buf,
        count = 0
    }

    fastcdc_chunk(data, _on_chunk, &b)
    return buf[:b.count]
}

sig_equal :: proc(a, b: []Chunk_Sig) -> bool {
    if len(a) != len(b) do return false
    for i := 0; i < len(a); i += 1 {
        if a[i].hash != b[i].hash || a[i].size != b[i].size do return false
    }
    return true
}
