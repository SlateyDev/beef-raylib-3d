using RaylibBeef;
using System;

class ProjectileLifetime : Component {
    public float LifeRemaining;
    public float Speed;

    public delegate void OnProjectileDestroyed(GameObject gameObject);
    public Event<OnProjectileDestroyed> OnProjectileDestroyed = default ~ OnProjectileDestroyed.Dispose();

    RigidBody rigidBody;

    public override void Awake() {
        rigidBody = GetComponent<RigidBody>();
    }

    public override void Update(float frameTime) {
        Vector3 dir = Raymath.Vector3RotateByQuaternion(.(0,0,1), gameObject.transform.rotation);
        dir.y = 0.0f;
        dir = Raymath.Vector3Normalize(dir);

        gameObject.transform.translation += dir * Speed * frameTime;
        //rigidBody.SetLinearVelocity(Raymath.Vector3Normalize(Direction) * Speed);

        if (LifeRemaining <= 0) return;

        LifeRemaining -= frameTime;

        if (LifeRemaining <= 0) {
            Console.WriteLine("Destroy Projectile");
            OnProjectileDestroyed.Invoke(this.gameObject);
            this.gameObject.Destroy();
        }
    }
}