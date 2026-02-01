using RaylibBeef;
using SDL2;
using System;
using System.Diagnostics;

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
    static SDL.SDL_GameController* gameController = null;

    static float maxFrameTime = 1f / 60f * 4f;
    public static int Main() {
        Raylib.SetTraceLogLevel(.LOG_ALL);
        //Raylib.SetTraceLogCallback((logType, text, args) => {
        //    Debug.WriteLine(StringView(text), args);
        //});

        //Raylib.SetConfigFlags(.FLAG_MSAA_4X_HINT);
        Raylib.SetConfigFlags(.FLAG_WINDOW_RESIZABLE);
        Raylib.InitWindow(1280, 720, "Plague Doctor - Survivor");
        //Raylib.SetTargetFPS(60);
        SDL.Init(.GameController);

        game = new Game();
        defer delete game;

        game.Start();

        var numJoysticks = SDL.NumJoysticks();
        Console.WriteLine($"Number of joysticks connected = {numJoysticks}");
        if (numJoysticks > 0) {
            if (SDL.IsGameController(0)) {
                gameController = SDL.GameControllerOpen(0);
            }
        }

#if BF_PLATFORM_WASM
        emscripten_set_main_loop(=> EmscriptenMainLoop, 0, 1);
#else
        while (!Raylib.WindowShouldClose()) {
            var frameTime = Raylib.GetFrameTime();
        	Update(frameTime);
        }
#endif

        if (gameController != null) {
            SDL.GameControllerClose(gameController);
        }
        game.Stop();

        SDL.Quit();
        Raylib.CloseWindow();
        return 0;
    }

    private static void Update(float frameTime) {
        SDL.GameControllerUpdate();

        SDL.Event event;
        while (SDL.PollEvent(out event) != 0) {
            if (event.type == SDL.EventType.ControllerDeviceadded) {
                if (event.cdevice.which != 0) continue;

                if (SDL.IsGameController(0)) {
                    gameController = SDL.GameControllerOpen(0);
                }
            }
        }

        game.Update(frameTime);
        game.Render();
    }
}