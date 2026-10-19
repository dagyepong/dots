import QtQuick
import qs.services

// One GPU-backed wallpaper image. WallpaperLayer.qml creates one of
// these per wallpaper switch and destroy()s it the instant it's done
// being blended — see the "why this file's lifecycle matters" comment
// at the top of WallpaperLayer.qml. Nothing else should create or
// destroy an instance of this; treat it as WallpaperLayer.qml's
// private implementation detail, not a general-purpose Image.
Image {
    id: root

    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    // The picture is decoded at the output's own size, so at rest (and in the
    // blend) it is drawn 1:1 and the mipmap levels are never sampled. Edit
    // Desktop only shows it at about 0.6 - 0.75 of that size, which plain
    // bilinear filtering (`smooth`) handles fine (mipmaps matter from about
    // half size down). It is NEVER switched on for the mode: changing `mipmap`
    // on a live Image makes Qt throw the GPU texture away and upload the
    // whole full-size picture again, at the exact moment the mode starts (and
    // again when it ends), which is what made the edited monitor blink black.
    // The wallpaper's pixels are left exactly as they are.
    mipmap: false

    // This Image *is* the cache slot for this particular switch — a
    // second, separate pixmap-cache copy of the same bytes sitting
    // alongside it for a wallpaper that's about to be destroyed anyway
    // is exactly the kind of "nobody owns this, nobody frees it"
    // memory the leak fix here is trying to avoid.
    cache: false

    // Layering is what lets WallpaperLayer.qml's ShaderEffect sample
    // this Image as a texture (`source1`/`source2`); WallpaperLayer.qml
    // binds this to true only while this slot is actually part of a
    // blend, and back to false the moment it's the sole steady-state
    // wallpaper — idle costs zero extra FBO/texture memory instead of
    // one permanently-allocated layer per slot for the whole session.
    layer.enabled: false
    layer.smooth: true
}
