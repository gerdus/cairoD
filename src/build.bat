:: ~ @echo off
dmd cairo/c/cairo.d cairo/c/pdf.d cairo/c/svg.d cairo/c/xcb.d cairo/c/directfb.d cairo/c/ps.d cairo/c/win32.d cairo/cairo.d cairo/util.d cairo/directfb.d cairo/pdf.d cairo/ps.d cairo/svg.d cairo/win32.d cairo/xcb.d -lib -L-lcairo -of../libcairod.lib -version=CAIRO_HAS_PS_SURFACE -version=CAIRO_HAS_PDF_SURFACE -version=CAIRO_HAS_SVG_SURFACE -version=CAIRO_HAS_WIN32_SURFACE -version=CAIRO_HAS_PNG_FUNCTIONS -version=CAIRO_HAS_WIN32_FONT -version=WindowsAPI -I../../WindowsAPI