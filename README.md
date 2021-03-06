# cairoD [![Build Status](https://travis-ci.org/cairoD/cairoD.svg)](https://travis-ci.org/cairoD/cairoD)

This is a D2 binding and wrapper for the [cairo](http://cairographics.org) graphics library.

Currently cairoD targets cairo version **1.10.2**.

Homepage: https://github.com/cairoD/cairoD

## Examples

The cairoD library ships with some examples in the [example](https://github.com/cairoD/cairoD/tree/master/example) directory.
Some of these examples are ported from [cairographics.org](http://cairographics.org/samples/), some are original. To build these
examples, simply use dub:

```bash
dub run
```

Some examples can directly present the results in a GTK2 or GTK3 window. Simply use the correct dub configurations:

```bash
dub run --config=gtk2
dub run --config=gtk3
```

![GTK3 example image](example_gtk3.png)

## Building

You can use [dub] to make this library a dependency for your project.
[dub]: http://code.dlang.org/packages/cairod


### Customizing the cairoD configuration
The cairo library provides certain features as optional extensions. CairoD
does not provide access to these extensions by default. To enable the extensions,
pass the matching version to your D compiler or specify the versions in your dub.json
file:

```json
"dependencies": {
    "cairod": {"version": "~>0.0.1"}
},
"versions": ["CairoPNG"]
```

The following versions are available:

| version name         | Cairo C feature            | Description                             |
| -------------------- | -------------------------- | --------------------------------------- |
| CairoPNG             | CAIRO_HAS_PNG_FUNCTIONS    | Enable loading/saving of PNG files      |
| CairoPSSurface       | CAIRO_HAS_PS_SURFACE       | Enable cairo.ps module                  |
| CairoPDFSurface      | CAIRO_HAS_PDF_SURFACE      | Enable cairo.pdf module                 |
| CairoSVGSurface      | CAIRO_HAS_SVG_SURFACE      | Enable cairo.svg module                 |
| CairoFTFont          | CAIRO_HAS_FT_FONT          | Enable cairo.ft module (FreeType fonts) |
| CairoWin32Surface    | CAIRO_HAS_WIN32_SURFACE    | Enable cairo.win32 module (rendering)   |
| CairoWin32Font       | CAIRO_HAS_WIN32_FONT       | Enable cairo.win32 module (fonts)       |
| CairoXlibSurface     | CAIRO_HAS_XLIB_SURFACE     | Enable cairo.xlib module                |
| CairoXCBSurface      | CAIRO_HAS_XCB_SURFACE      | Enable cairo.xcb module                 |
| CairoDirectFBSurface | CAIRO_HAS_DIRECTFB_SURFACE | Enable cairo.directfb module            |



## Links

- Cairo [homepage](http://cairographics.org).

## License

Distributed under the Boost Software License, Version 1.0.

See the accompanying file LICENSE_1_0.txt or view it [online][BoostLicense].

[BoostLicense]: http://www.boost.org/LICENSE_1_0.txt
