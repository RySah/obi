package extmath

RABIN_POLY :: 0xAD93D23594C935
RABIN_K    :: 53

rabin_fingerprint :: proc(data: []byte) -> (fp: u64) {
    fp = 0
    for i := 0; i < len(data); i += 1 {
        // Shift fp by 8 bits and add a new byte
        fp = (fp << 8) | u64(data[i])

        // Reduce modulo POLY
        for j: i64 = 7; j >= 0; j -= 1 {
            if fp & (1 << u64(RABIN_K + j)) != 0 {
                fp ~= RABIN_POLY << u64(j)
            }
        }
    }
    return
}
