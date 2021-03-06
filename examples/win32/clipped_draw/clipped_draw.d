module clipped_draw;

/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/

/+
 + Demonstrates the use of WS_CLIPCHILDREN when calling CreateWindow().
 + This clips the drawing of a parent window with any child windows,
 + therefore it won't draw over the children's areas, avoiding flicker.
 +
 + I'm also using the ps.rcPaint from the BeginPaint call to limit
 + blitting to only the areas that need to be updated. I'm also not
 + re-drawing (with cairo) the areas of a widget that have already
 + been drawn.
 +
 + These techniques give us good drawing and blitting performance.
 + We could also dynamically create the backbuffer for the main
 + window (atm. it creates a memory buffer the size of the screen).
 +/

import core.memory;
import core.runtime;
import core.thread;
import core.stdc.config;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.functional;
import std.math;
import std.random;
import std.range;
import std.stdio;
import std.string;
import std.traits;
import std.utf;

pragma(lib, "gdi32.lib");

import win32.windef;
import win32.winuser;
import win32.wingdi;

alias std.algorithm.min min;  // conflict resolution
alias std.algorithm.max max;  // conflict resolution

import cairo.cairo;
import cairo.win32;

alias cairo.cairo.RGB RGB;   // conflict resolution

struct StateContext
{
    Context ctx;

    this(Context ctx)
    {
        this.ctx = ctx;
        ctx.save();
    }

    ~this()
    {
        ctx.restore();
    }

    alias ctx this;
}

class PaintBuffer
{
    this(HDC localHdc, int cxClient, int cyClient)
    {
        hdc    = localHdc;
        width  = cxClient;
        height = cyClient;

        hBuffer    = CreateCompatibleDC(localHdc);
        hBitmap    = CreateCompatibleBitmap(localHdc, cxClient, cyClient);
        hOldBitmap = SelectObject(hBuffer, hBitmap);

        surf = new Win32Surface(hBuffer);
        ctx = Context(surf);
        initialized = true;
    }

    ~this()
    {
        if (initialized)
        {
            clear();
        }
    }

    void clear()
    {
        ctx.dispose();
        surf.finish();
        surf.dispose();

        SelectObject(hBuffer, hOldBitmap);
        DeleteObject(hBitmap);
        DeleteDC(hBuffer);
        initialized = false;
    }

    HDC hdc;
    bool initialized;
    int width, height;
    HDC hBuffer;
    HBITMAP hBitmap;
    HBITMAP hOldBitmap;
    Context ctx;
    Surface surf;
}

abstract class Widget
{
    Widget parent;
    PAINTSTRUCT ps;
    PaintBuffer mainPaintBuff;
    PaintBuffer paintBuffer;
    HWND hwnd;
    int width, height;
    int xOffset, yOffset;
    bool needsRedraw = true;

    this(HWND hwnd, int width, int height)
    {
        this.hwnd = hwnd;
        this.width = width;
        this.height = height;
        //~ SetTimer(hwnd, 100, 1, null);
    }

    @property Size!int size()
    {
        return Size!int(width, height);
    }

    abstract LRESULT process(UINT message, WPARAM wParam, LPARAM lParam)
    {
        switch (message)
        {
            case WM_ERASEBKGND:
            {
                return 1;
            }

            case WM_PAINT:
            {
                OnPaint(hwnd, message, wParam, lParam);
                return 0;
            }

            case WM_SIZE:
            {
                width  = LOWORD(lParam);
                height = HIWORD(lParam);

                auto localHdc = GetDC(hwnd);

                if (paintBuffer !is null)
                {
                    paintBuffer.clear();
                }

                paintBuffer = new PaintBuffer(localHdc, width, height);
                ReleaseDC(hwnd, localHdc);

                needsRedraw = true;
                InvalidateRect(hwnd, null, true);
                return 0;
            }

            case WM_TIMER:
            {
                InvalidateRect(hwnd, null, true);
                return 0;
            }

            case WM_MOVE:
            {
                xOffset = LOWORD(lParam);
                yOffset = HIWORD(lParam);
                return 0;
            }

            case WM_DESTROY:
            {
                paintBuffer.clear();
                PostQuitMessage(0);
                return 0;
            }

            default:
        }

        return DefWindowProc(hwnd, message, wParam, lParam);
    }

    abstract void OnPaint(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);
    abstract void draw(StateContext ctx);
}

class TestWidget2 : Widget
{
    this(HWND hwnd, int width, int height)
    {
        super(hwnd, width, height);
    }

    override LRESULT process(UINT message, WPARAM wParam, LPARAM lParam)
    {
        return super.process(message, wParam, lParam);
    }

    override void OnPaint(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
    {
        auto ctx = paintBuffer.ctx;
        auto hBuffer = paintBuffer.hBuffer;
        auto hdc = BeginPaint(hwnd, &ps);
        auto boundRect = ps.rcPaint;

        if (needsRedraw)
        {
            //~ writeln("drawing");
            draw(StateContext(ctx));
            needsRedraw = false;
        }

        with (boundRect)
        {
            //~ writeln("blitting");
            BitBlt(hdc, left, top, right - left, bottom - top, paintBuffer.hBuffer, left, top, SRCCOPY);
        }

        EndPaint(hwnd, &ps);
    }

    override void draw(StateContext ctx)
    {
        ctx.setSourceRGB(1, 1, 1);
        ctx.paint();

        ctx.scale(width, height);
        ctx.moveTo(0, 0);

        ctx.rectangle(0, 0, 1, 1);
        ctx.setSourceRGBA(1, 1, 1, 0);
        ctx.setOperator(Operator.CAIRO_OPERATOR_CLEAR);
        ctx.fill();

        ctx.setSourceRGB(0, 0, 0);
        ctx.setOperator(Operator.CAIRO_OPERATOR_OVER);

        auto linpat = new LinearGradient(0, 0, 1, 1);
        linpat.addColorStopRGB(0, RGB(0, 0.3, 0.8));
        linpat.addColorStopRGB(1, RGB(0, 0.8, 0.3));

        auto radpat = new RadialGradient(0.5, 0.5, 0.25, 0.5, 0.5, 0.75);
        radpat.addColorStopRGBA(0,   RGBA(0, 0, 0, 1));
        radpat.addColorStopRGBA(0.5, RGBA(0, 0, 0, 0));

        ctx.setSource(linpat);
        ctx.mask(radpat);
    }
}

class TestWidget : Widget
{
    RGB backColor;

    this(HWND hwnd, int width, int height)
    {
        super(hwnd, width, height);
        this.backColor = RGB(1, 0, 0);

        auto localHdc = GetDC(hwnd);
        auto hWindow = CreateWindow(WidgetClass.toUTF16z, null,
                       WS_CHILDWINDOW | WS_VISIBLE | WS_CLIPCHILDREN,  // WS_CLIPCHILDREN is necessary
                       0, 0, 0, 0,
                       hwnd, cast(HANDLE)1,                                   // child ID
                       cast(HINSTANCE)GetWindowLongPtr(hwnd, GWL_HINSTANCE),  // hInstance
                       null);

        auto widget = new TestWidget2(hWindow, width / 2, width / 2);
        WidgetHandles[hWindow] = widget;

        auto size = widget.size;
        MoveWindow(hWindow, size.width / 2, size.height / 2, size.width, size.height, true);
    }

    override LRESULT process(UINT message, WPARAM wParam, LPARAM lParam)
    {
        return super.process(message, wParam, lParam);
    }

    override void OnPaint(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
    {
        auto ctx = paintBuffer.ctx;
        auto hBuffer = paintBuffer.hBuffer;
        auto hdc = BeginPaint(hwnd, &ps);
        auto boundRect = ps.rcPaint;

        if (needsRedraw)
        {
            //~ writeln("drawing");
            draw(StateContext(ctx));
            needsRedraw = false;
        }

        with (boundRect)
        {
            //~ writeln("blitting");
            BitBlt(hdc, left, top, right - left, bottom - top, paintBuffer.hBuffer, left, top, SRCCOPY);
        }

        EndPaint(hwnd, &ps);
    }

    override void draw(StateContext ctx)
    {
        ctx.save();
        ctx.scale(width, height);
        ctx.moveTo(0, 0);

        ctx.rectangle(0, 0, 1, 1);
        ctx.setSourceRGBA(1, 1, 1, 0);
        ctx.setOperator(Operator.CAIRO_OPERATOR_CLEAR);
        ctx.fill();

        ctx.setSourceRGB(0, 0, 0);
        ctx.setOperator(Operator.CAIRO_OPERATOR_OVER);

        auto linpat = new LinearGradient(0, 0, 1, 1);
        linpat.addColorStopRGB(0, RGB(0, 0.3, 0.8));
        linpat.addColorStopRGB(1, RGB(0, 0.8, 0.3));

        auto radpat = new RadialGradient(0.5, 0.5, 0.25, 0.5, 0.5, 0.75);
        radpat.addColorStopRGBA(0,   RGBA(0, 0, 0, 1));
        radpat.addColorStopRGBA(0.5, RGBA(0, 0, 0, 0));

        ctx.setSource(linpat);
        ctx.mask(radpat);

        ctx.moveTo(0.1, 0.5);
        ctx.restore();

        ctx.setSourceRGB(1, 1, 1);
        ctx.selectFontFace("Tahoma", FontSlant.CAIRO_FONT_SLANT_NORMAL, FontWeight.CAIRO_FONT_WEIGHT_NORMAL);
        ctx.setFontSize(20);
        ctx.showText("weeeeeeeeeeeeeeeeeeeeeeeeeee");
    }
}

/* A place to hold Widget objects. Since each window has a unique HWND,
 * we can use this hash type to store references to Widgets and call
 * their window processing methods.
 */
Widget[HWND] WidgetHandles;

/*
 * All Widget windows have this window procedure registered via RegisterClass(),
 * we use it to dispatch to the appropriate Widget window processing method.
 *
 * A similar technique is used in the DFL and DGUI libraries for all of its
 * windows and widgets.
 */
extern (Windows)
LRESULT winDispatch(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    auto widget = hwnd in WidgetHandles;

    if (widget !is null)
    {
        return widget.process(message, wParam, lParam);
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

extern (Windows)
LRESULT mainWinProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    static PaintBuffer paintBuffer;
    static int width, height;
    static int TimerID = 16;

    static HMENU widgetID = cast(HMENU)0;  // todo: each widget has its own HMENU ID

    void draw(StateContext ctx)
    {
        ctx.setSourceRGB(0.3, 0.3, 0.3);
        ctx.paint();
    }

    switch (message)
    {
        case WM_CREATE:
        {
            auto hDesk = GetDesktopWindow();
            RECT rc;
            GetClientRect(hDesk, &rc);

            auto localHdc = GetDC(hwnd);
            paintBuffer = new PaintBuffer(localHdc, rc.right, rc.bottom);

            auto hWindow = CreateWindow(WidgetClass.toUTF16z, null,
                           WS_CHILDWINDOW | WS_VISIBLE | WS_CLIPCHILDREN,  // WS_CLIPCHILDREN is necessary
                           0, 0, 0, 0,
                           hwnd, widgetID,                                        // child ID
                           cast(HINSTANCE)GetWindowLongPtr(hwnd, GWL_HINSTANCE),  // hInstance
                           null);

            auto widget = new TestWidget(hWindow, 400, 400);
            WidgetHandles[hWindow] = widget;

            auto size = widget.size;
            MoveWindow(hWindow, size.width / 3, size.width / 3, size.width, size.height, true);

            //~ SetTimer(hwnd, TimerID, 1, null);

            return 0;
        }

        case WM_LBUTTONDOWN:
        {
            SetFocus(hwnd);
            return 0;
        }

        case WM_SIZE:
        {
            width = LOWORD(lParam);
            height = HIWORD(lParam);
            return 0;
        }

        case WM_PAINT:
        {
            auto ctx = paintBuffer.ctx;
            auto hBuffer = paintBuffer.hBuffer;
            PAINTSTRUCT ps;
            auto hdc = BeginPaint(hwnd, &ps);
            auto boundRect = ps.rcPaint;

            draw(StateContext(paintBuffer.ctx));

            with (boundRect)
            {
                BitBlt(hdc, left, top, right - left, bottom - top, paintBuffer.hBuffer, left, top, SRCCOPY);
            }

            EndPaint(hwnd, &ps);
            return 0;
        }

        case WM_TIMER:
        {
            InvalidateRect(hwnd, null, true);
            return 0;
        }

        case WM_MOUSEWHEEL:
        {
            return 0;
        }

        case WM_DESTROY:
        {
            paintBuffer.clear();
            PostQuitMessage(0);
            return 0;
        }

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

string WidgetClass = "WidgetClass";

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    string appName = "layered drawing";

    HWND hwnd;
    MSG  msg;
    WNDCLASS wndclass;

    /* One class for the main window */
    wndclass.lpfnWndProc = &mainWinProc;
    wndclass.cbClsExtra  = 0;
    wndclass.cbWndExtra  = 0;
    wndclass.hInstance   = hInstance;
    wndclass.hIcon       = LoadIcon(null, IDI_APPLICATION);
    wndclass.hCursor     = LoadCursor(null, IDC_ARROW);
    wndclass.hbrBackground = null;
    wndclass.lpszMenuName  = null;
    wndclass.lpszClassName = appName.toUTF16z;

    if (!RegisterClass(&wndclass))
    {
        MessageBox(null, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    /* Separate window class for Widgets. */
    wndclass.hbrBackground = null;
    wndclass.lpfnWndProc   = &winDispatch;
    wndclass.cbWndExtra    = 0;
    wndclass.hIcon         = null;
    wndclass.lpszClassName = WidgetClass.toUTF16z;

    if (!RegisterClass(&wndclass))
    {
        MessageBox(null, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    hwnd = CreateWindow(appName.toUTF16z, "layered drawing",
                        WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN,  // WS_CLIPCHILDREN is necessary
                        CW_USEDEFAULT, CW_USEDEFAULT,
                        CW_USEDEFAULT, CW_USEDEFAULT,
                        null, null, hInstance, null);

    ShowWindow(hwnd, iCmdShow);
    UpdateWindow(hwnd);

    while (GetMessage(&msg, null, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return msg.wParam;
}

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;

    try
    {
        Runtime.initialize();
        myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate();
    }
    catch (Throwable o)
    {
        MessageBox(null, o.toString().toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = -1;
    }

    return result;
}
