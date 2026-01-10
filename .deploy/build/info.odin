package build
import "core:time"
import "core:hash"
import "core:mem"

/*
These are the 2 seperate versioning formats that'll be used in the project.
- https://semver.org/  - For development only
- https://calver.org/  - Any form of releases (beta, alpha etc)
*/


/*
Refers to the version of a software release that is considered stable enough for final testing before the official public release.
The value indicates the iteration count of the release candidate, e.g. 1 is the first attempt at a final release, and subsequent numbers 
reflect necessary fixes based on feedback.
*/
Release_Candidate :: distinct u16

Sem_Version :: struct {
    // MAJOR version when you make incompatible API changes
    major: u32,
    // MINOR version when you add functionality in a backward compatible manner
    minor: u32,
    // PATCH version when you make backward compatible bug fixes
    patch: u32
}

/* 
Format YYYY.MM
*/
Cal_Version :: struct {
    YYYY: u32,
    MM: u32
}

Version :: struct {
    dev: Sem_Version,
    release: Cal_Version,
    rc: Maybe(Release_Candidate),
    beta: bool
}

get_cal_version :: proc() -> (out: Cal_Version) {
    curr_time := time.now()
    out.YYYY = u32(time.year(curr_time))
    out.MM = u32(time.month(curr_time))
    return
}

// Update this function on new versions
get_version :: proc() -> (OUT: Version) {
    OUT.dev = {
        major=0,
        minor=0,
        patch=0
    }
    OUT.release = get_cal_version()
    OUT.rc = nil
    OUT.beta = false
    return
}

version_hash :: proc(ver: Version) -> u64 {
    return hash.murmur64a(mem.any_to_bytes(ver))
} 

get_deployment_hash :: proc() -> u64 {
    odin_version_hash := ODIN_VERSION_HASH
    return hash.murmur64a(transmute([]byte)odin_version_hash) ~ version_hash(get_version())
}
