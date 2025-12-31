![ct3 logo](https://www.ajl.mqr.link/mat/img/ajl_logo_x75.png)

# ct3 (mpv-game controller)

## Definition
(ai-audio image) processing utility seeks to perform editorial operations allowing enhanced experience for fundamental image processing tasks.

## Backdrop
a bundled build of [mpv](https://github.com/mpv-player/mpv) with sdl enabled to recive game controller strokes included multiple plugin scripts:
- [file-browser](https://github.com/CogentRedTester/mpv-file-browser)
- [crop](https://github.com/occivink/mpv-scripts/blob/master/scripts/crop.lua)
- [bookmarker-menu](https://github.com/NurioHin/mpv-bookmarker)
- [visualizer](https://github.com/mfcc64/mpv-scripts/blob/master/visualizer.lua)
- [playlistmanager](https://github.com/jonniek/mpv-playlistmanager)
- a merger of [slicing](https://github.com/Kagami/mpv_slicing) and [encode](https://github.com/occivink/mpv-scripts/blob/master/scripts/encode.lua)


### Configuration
[mpv v0.35](https://github.com/mpv-player/mpv/tree/release/0.35) branch
build system: waf

```
:: ./build/ct3 -v
[cplayer] Command line options: '-v'
[cplayer] mpv 0.35.1-dirty Copyright © 2000-2023 mpv/MPlayer/mplayer2 projects
[cplayer]  built on Mon Dec 29 19:29:46 CET 2025
[cplayer] FFmpeg library versions:
[cplayer]    libavutil       57.28.100
[cplayer]    libavcodec      59.37.100
[cplayer]    libavformat     59.27.100
[cplayer]    libswscale      6.7.100
[cplayer]    libavfilter     8.44.100
[cplayer]    libswresample   4.7.100
[cplayer] FFmpeg version: n5.1.2-11-g30d432f205
[cplayer] 
[cplayer] Configuration: ./waf configure --enable-sdl2 --disable-sdl2-audio --disable-sdl2-video --enable-cplugins --enable-libmpv-static --enable-static-build --disable-vapoursynth
[cplayer] List of enabled features: asm av-channel-layout bsd-fstatfs build-date cocoa coreaudio cplayer cplugins debug-build ffmpeg gl gl-cocoa glob glob-posix gpl iconv javascript jpeg jpegxl lcms2 libarchive libass libavdevice libbluray libdl libm libmpv-static lua luadef52 macos-10-11-features macos-10-12-2-features macos-10-14-features macos-cocoa-cb macos-media-player macos-touchbar optimize osx-thread-name plain-gl posix posix-or-mingw pthreads rubberband sdl2 sdl2-gamepad static-build stdatomic swift uchardet vector videotoolbox-gl videotoolbox-hwaccel zimg zlib
```

### Compitablity
The app got bundled on mac osx 10.14

### Download 
mac osx bundle [ct3](https://www.mqr.link/mat/pkg/ct3.app.zip)

## Control
performance is an intellectual procedure in (ai-audio image) processing through mechanisms varies in control and connectivity.

### Mapping

- [x] [gamecontroller](https://www.mqr.link/#/en/tool/ct3/prf/ds4)
- [ ] magic keyboard

## Operations

### Cut 
Cut is produced by setting A-Z points with a stroke on Game-controller.


The produceded clips located is in the home folder inside ct3 directory, categorized by type:
  /Users/account/ct3
  ├ aud (audio split)
  ├ img (screenshot)
  └ vid (video split)

### Mark registry
Register and browse mark points for media files.

### Color
Set negation or modify contrast, gamma, brightness and saturation levels.

### Capture
Snap frame as raw or with captions.

### Audio visualization
Provided multiple types of audio visualization.
