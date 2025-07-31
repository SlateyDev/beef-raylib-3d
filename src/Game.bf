using System;
using RaylibBeef;

class Game 
{
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
    }

    public void Stop() {
        mIsRunning = false;
    }
}