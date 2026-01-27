using System;
using RaylibBeef;
using game.UI;

class Game {
    private bool mIsRunning;
    public Player mPlayer;
    public World mWorld;

    GameObject go;
    GameObject go2;

    Scene scene = new Scene() ~ delete _;

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
        go = new GameObject();
        go.transform = .(.(5, 3, 5), .(0, 0, 0, 1), .(1, 1, 1));
        var meshRenderer = go.AddComponent<MeshRenderer>();
        meshRenderer.Model = ModelManager.Get("assets/models/building_A.gltf");
        go.AddComponent<BoxCollider>();
        scene.[Friend]objectsInScene.Add(go);

        go2 = new GameObject();
        go2.transform = .(.(5, 5, 6), .(0, 0, 0, 1), .(1, 1, 1));
        go2.[Friend]parent = go;
        go.[Friend]children.Add(go2);
        var meshRenderer2 = go2.AddComponent<MeshRenderer>();
        meshRenderer2.Model = ModelManager.Get("assets/models/building_B.gltf");
        go2.AddComponent<BoxCollider>();
        scene.[Friend]objectsInScene.Add(go2);

        scene.WakeScene();

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
            Transform transform = go.transform;
            transform.rotation = Raymath.QuaternionMultiply(transform.rotation, Raymath.QuaternionFromAxisAngle(.(0, 1, 0), frameTime));
            go.transform = transform;
            mPlayer.Update(frameTime);
            mWorld.Update(frameTime);
            scene.Update(frameTime);
            PhysicsServer.Update(frameTime);
            // Check for game state changes
        }

        ui.Update();
    }

    public void Render() {
        Raylib.BeginDrawing();
        defer Raylib.EndDrawing();

        if (mIsRunning) {
            scene.RefreshRenderables();
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