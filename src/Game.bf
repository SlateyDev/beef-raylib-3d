using System;
using RaylibBeef;

class Game 
{
    private bool mIsRunning;
    private Player mPlayer;
    public World mWorld;

    public this() {
        mIsRunning = true;
        mPlayer = new Player(.(1.0f, 1.0f, 0.0f)); // Position player slightly above the floor
        mWorld = new World();
    }

    public ~this() {
        delete(mPlayer);
        delete(mWorld);
    }

    public void Start() {
        // Initialize game resources
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
    }

    public void Stop() {
        mIsRunning = false;
    }
}