using System;
using RaylibBeef;
using game.UI;

class Game {
    private bool mIsRunning;
    public SceneCamera currentCamera;
    public World mWorld;

    /*GameObject go;
    GameObject go2;
    GameObject go3;*/

    Scene scene = new Scene() ~ delete _;

    private UIScene ui;

    public this() {
        mIsRunning = true;
    }

    public ~this() {
        delete(mWorld);
        delete(ui);
    }

    public void Start() {
        MeshRenderer meshRenderer;

        var player = GameObject.Instantiate(.(2, 0, -2), Raymath.QuaternionIdentity());
        var characterController = player.AddComponent<CharacterController>();
        characterController.[Friend]halfHeight = 0.87662f * 0.5f - characterController.[Friend]radius;
        player.AddComponent<CharacterControllerDebugRenderer>();

        var characterRotator = GameObject.Instantiate(.(0, 0, 0), Raymath.QuaternionIdentity(), player);
        characterRotator.AddComponent<CharacterRotator>();
        characterRotator.AddComponent<CharacterAutoShooter>();
        meshRenderer = characterRotator.AddComponent<MeshRenderer>();
        meshRenderer.Model = ModelManager.Get("assets/models/the-doctor.gltf");

        var cameraPivot = GameObject.Instantiate(.(0, 1, 0), Raymath.QuaternionFromEuler(45 * Raylib.DEG2RAD, 0, 0), player);
        //cameraPivot.AddComponent<CameraPitchController>();
        //cameraController.[Friend]lookAt = player;

        var playerCamera = GameObject.Instantiate(.(0, 0, -8), Raymath.QuaternionIdentity(), cameraPivot);
        var sceneCamera = playerCamera.AddComponent<SceneCamera>();
        sceneCamera.SetActive(true);

        /*go = GameObject.Instantiate(.(5, 3, 5), Raymath.QuaternionFromAxisAngle(.(0.5f, 0, 0), 15 * Raymath.DEG2RAD));
        meshRenderer = go.AddComponent<MeshRenderer>();
        meshRenderer.Model = ModelManager.Get("assets/models/building_A.gltf");
        go.AddComponent<MeshBoundingBoxCollider>();
        go.AddComponent<RigidBody>();

        go2 = GameObject.Instantiate(.(5, 5, 6), Raymath.QuaternionIdentity(), go);
        var meshRenderer2 = go2.AddComponent<MeshRenderer>();
        meshRenderer2.Model = ModelManager.Get("assets/models/building_B.gltf");
        go2.AddComponent<BoxCollider>();

        go3 = GameObject.Instantiate(.(2, 1, 2), Raymath.QuaternionIdentity(), go2);
        var meshRenderer3 = go3.AddComponent<MeshRenderer>();
        meshRenderer3.Model = ModelManager.Get("assets/models/building_C.gltf");
        go3.AddComponent<BoxCollider>();*/

        // Initialize game resources
        mWorld = new World();
        mWorld.LoadLevel("");
        ui = new UIScene();

        //var currentScreenWidth = Raylib.GetScreenWidth();
	    //var currentScreenHeight = Raylib.GetScreenHeight();

        /*var button1 = new Button(.(10, 100, 200, 90), "TEST BUTTON");
        var button2 = new Button(.(10, 200, 200, 90), "TEST BUTTON 2");

        button1.onClick.Add(new (button) => {Console.WriteLine($"Clicked {button.text}");});
        button2.onClick.Add(new (button) => {Console.WriteLine($"Clicked {button.text}");});

        ui.elements.Add(new Text(.(float(currentScreenWidth) / 2 - 170, 20, 340, 20), "TITLE"));
        ui.elements.Add(button1);
        ui.elements.Add(button2);*/

        scene.WakeScene();
    }

    public void Update(float frameTime) {
        if (mIsRunning) {
            // House flipper test. Currently shows that render offset isn't being correctly set based on rotation.
            /*if (Raylib.IsKeyPressed(.KEY_F)) {
                Random rand = new Random();
                defer delete rand;

                var impulsePoint = Vector3((float)rand.NextDoubleSigned(), (float)rand.NextDoubleSigned(), (float)rand.NextDoubleSigned());
                impulsePoint += go.GetWorldTransform().translation;
                go.GetComponent<RigidBody>().AddImpulse(.(0, 50000, 0), impulsePoint);
            }*/

            /*Transform transform = go2.transform;
            transform.rotation = Raymath.QuaternionMultiply(transform.rotation, Raymath.QuaternionFromAxisAngle(.(0, 1, 0), frameTime));
            go2.transform = transform;

            transform = go3.transform;
            transform.rotation = Raymath.QuaternionMultiply(transform.rotation, Raymath.QuaternionFromAxisAngle(.(0, 1, 0), frameTime));
            go3.transform = transform;*/

            mWorld.Update(frameTime);
            scene.Update(frameTime);
            PhysicsServer.Update(frameTime);
        }

        ui.Update();
    }

    public void Render() {
        Raylib.BeginDrawing();
        defer Raylib.EndDrawing();

        if (mIsRunning) {
            scene.RefreshRenderables();
            // Render the world (which now includes shadow mapping)
            mWorld.Render(currentCamera.[Friend]camera);
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