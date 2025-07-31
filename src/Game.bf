using System;
using RaylibBeef;

class Game {
    private bool mIsRunning;
    public Player mPlayer;
    public World mWorld;

    public this() {
        mIsRunning = true;
    }

    public ~this() {
        delete(mPlayer);
        delete(mWorld);
    }

    public void Start() {
        // Initialize game resources
        mPlayer = new Player(.(1.0f, 1.0f, 0.0f)); // Position player slightly above the floor
        mWorld = new World();
        mWorld.LoadLevel("");
    }

    public void Update(float frameTime) {
        if (mIsRunning) {
            mPlayer.Update(frameTime);
            mWorld.Update(frameTime);
            // Check for game state changes
        }
    }

    public void Render() {
        Raylib.BeginDrawing();
        defer Raylib.EndDrawing();

        if (mIsRunning) {
            // Render the world (which now includes shadow mapping)
            mWorld.Render(mPlayer.camera);
        }
        
        Raylib.BeginMode2D(Camera2D(.(0, 0), .(0, 0), 0f, 1.0f));
        Raylib.DrawRectanglePro(Rectangle(10, 10, 120, 20), .(0,0), 0, Raylib.BLACK);
        Raylib.DrawFPS(14, 11);
        // Text("FPS: " + Raylib.GetFPS(), 10, 10, 20, Raylib.BLACK);
        Raylib.EndMode2D();
    }

    public void Stop() {
        mIsRunning = false;
    }
}