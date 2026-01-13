package build
import "core:time"
import "core:hash"
import "core:mem"
import "core:fmt"
import "core:strings"

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
        major=3,
        minor=2,
        patch=2
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

aprint_release_candicate :: proc(rc: Release_Candidate, allocator := context.allocator, newline := false) -> string {
    return fmt.aprintf("rc%d", transmute(u16)rc, allocator=allocator, newline=newline)
}

aprint_maybe_release_candicate :: proc(maybe_rc: Maybe(Release_Candidate), allocator := context.allocator, newline := false) -> string {
    if rc, defined := maybe_rc.?; defined {
        return aprint_release_candicate(rc, allocator, newline)
    } else do return fmt.aprintf("", allocator=allocator, newline=newline)
}

aprint_sem_version :: proc(v: Sem_Version, allocator := context.allocator, newline := false) -> string {
    return fmt.aprintf("v%d.%d.%d", v.major, v.minor, v.patch, allocator=allocator, newline=newline)
}

aprint_cal_version :: proc(v: Cal_Version, allocator := context.allocator, newline := false) -> string {
    if v.MM >= 10 {
        return fmt.aprintf("v%d.%d", v.YYYY, v.MM, allocator=allocator, newline=newline)
    } else {
        return fmt.aprintf("v%d.0%d", v.YYYY, v.MM, allocator=allocator, newline=newline)
    }
}

aprint_version :: proc(v: Version, allocator := context.allocator, newline := false) -> string {
    release := aprint_cal_version(v.release, allocator)
    defer delete(release, allocator)
    dev := aprint_sem_version(v.dev, allocator)
    defer delete(dev, allocator)
    rc := aprint_maybe_release_candicate(v.rc, allocator)
    defer delete(rc)
    return fmt.aprintf("%s dev-%s%s%s%s", release, dev, len(rc) > 0 ? "-" : "", rc, v.beta ? "-beta" : "", allocator=allocator, newline=newline)
}