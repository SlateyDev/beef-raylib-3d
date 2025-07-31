using System;
using System.Diagnostics;
using RaylibBeef;

class Program {
#if BF_PLATFORM_WASM
    private function void em_callback_func();

    [CLink, CallingConvention(.Stdcall)]
    private static extern void emscripten_set_main_loop(em_callback_func func, int32 fps, int32 simulateInfinteLoop);

    [CLink, CallingConvention(.Stdcall)]
    private static extern int32 emscripten_set_main_loop_timing(int32 mode, int32 value);

    [CLink, CallingConvention(.Stdcall)]
    private static extern double emscripten_get_now();

    private static void EmscriptenMainLoop() {
        var frameTime = Raylib.GetFrameTime();
	    Update(frameTime);
    }
#endif

    public static Game game;

    public static int Main() {
        Raylib.SetTraceLogLevel(.LOG_ALL);
        Raylib.SetTraceLogCallback((logType, text, args) => {
            Debug.WriteLine(StringView(text), args);
        });

        Raylib.SetConfigFlags(ConfigFlags.FLAG_MSAA_4X_HINT);
        Raylib.InitWindow(1366, 768, "Beef FPS");
        Raylib.SetTargetFPS(60);

        game = new Game();
        defer delete game;

        game.Start();

#if BF_PLATFORM_WASM
        emscripten_set_main_loop(=> EmscriptenMainLoop, 0, 1);
#else
        while (!Raylib.WindowShouldClose()) {
            var frameTime = Raylib.GetFrameTime();
        	Update(frameTime);
        }
#endif

        game.Stop();

        Raylib.CloseWindow();
        return 0;
    }

    private static void Update(float frameTime) {
        game.Update(frameTime);
        game.Render();
    }
}