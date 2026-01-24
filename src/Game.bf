using System;
using RaylibBeef;
using game.UI;

class Game {
    private bool mIsRunning;
    public Player mPlayer;
    public World mWorld;

    private UIScene ui;

    public this() {
        mIsRunning = true;
    }

    public ~this() {
        delete(mPlayer);
        delete(mWorld);
        delete(ui);
    }

    public void Start() {
        // Initialize game resources
        mPlayer = new Player(.(-5.0f, 1.0f, 0.0f)); // Position player slightly above the floor
        mWorld = new World();
        mWorld.LoadLevel("");
        ui = new UIScene();

        var currentScreenWidth = Raylib.GetScreenWidth();
	    //var currentScreenHeight = Raylib.GetScreenHeight();

        var button1 = new Button(.(10, 100, 200, 90), "TEST BUTTON");
        var button2 = new Button(.(10, 200, 200, 90), "TEST BUTTON 2");

        button1.onClick.Add(new (button) => {Console.WriteLine($"Clicked {button.text}");});
        button2.onClick.Add(new (button) => {Console.WriteLine($"Clicked {button.text}");});

        ui.elements.Add(new Text(.(float(currentScreenWidth) / 2 - 170, 20, 340, 20), "TITLE"));
        ui.elements.Add(button1);
        ui.elements.Add(button2);
    }

    public void Update(float frameTime) {
        if (mIsRunning) {
            mPlayer.Update(frameTime);
            mWorld.Update(frameTime);
            PhysicsServer.Update();
            // Check for game state changes
        }

        ui.Update();
    }

    public void Render() {
        Raylib.BeginDrawing();
        defer Raylib.EndDrawing();

        if (mIsRunning) {
            // Render the world (which now includes shadow mapping)
            mWorld.Render(mPlayer.camera);
        }
        
        Raylib.BeginMode2D(Camera2D{zoom = 1});
        Raylib.DrawRectanglePro(Rectangle(10, 10, 120, 20), .(0,0), 0, Raylib.BLACK);
        Raylib.DrawFPS(14, 11);

        ui.Render();
        Raylib.EndMode2D();
    }

    public void Stop() {
        mIsRunning = false;
    }
}