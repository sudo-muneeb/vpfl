# Draft: VPFL v1.0.1 first public release (unpublished)

VPFL is a local video player for x86_64 Linux, built with Flutter and mpv.
This release is planned to provide native DEB packages for Ubuntu 24.04 and
Linux Mint 22.x, RPM packages for Fedora 44, and `vpfl-bin` packages for Arch
Linux. The files and checksums will be listed in the GitHub Release only after
the exact source commit and generated assets pass release qualification.

VPFL supports local video playback, seeking, speed and volume controls,
embedded and external subtitles, a browsable video library, and playback
resume. Its Linux desktop entry registers supported video MIME types under
`io.github.sudo_muneeb.vpfl`.

Known limits: playback codecs depend on system mpv/FFmpeg libraries. Fedora's
default codec set may be narrower than the codec set used in release CI.
Rendering and hardware decode on physical GPUs require desktop verification.
Flatpak and Flathub packages are not included.

Before publication, replace this draft with the actual qualification SHA,
package checksums, tested desktop details, and any observed limitations.
