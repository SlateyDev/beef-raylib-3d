using RaylibBeef;
using System.Collections;

class CharacterAutoShooter : Component {
    float projectileFrequency = 1;
    float projectileLife = 1;

    float shootTime = 0;

    RigidBody rigidBody;

    List<GameObject> projectiles = new List<GameObject>() ~ delete _;

    void OnProjectileDestroyed(GameObject projectile) {
        projectiles.Remove(projectile);
    }

    public override void Update(float frameTime) {

        shootTime += frameTime;

        if (shootTime > projectileFrequency) {
            shootTime -= projectileFrequency;
            if (shootTime > projectileFrequency) shootTime = 0;

            var worldTransform = gameObject.GetWorldTransform();
            var newBullet = GameObject.Instantiate(worldTransform.translation, worldTransform.rotation);
            newBullet.IsActive = false;
            var meshRenderer = newBullet.AddComponent<MeshRenderer>();
            meshRenderer.Model = ModelManager.Get("assets/models/box_A.gltf");
            var collider = newBullet.AddComponent<SphereCollider>();
            collider.radius = 0.2f;
            rigidBody = newBullet.AddComponent<RigidBody>();
            rigidBody.motionType = .Kinematic;
            rigidBody.layer = .FRIENDLY_PROJECTILE;
            var projectileLifetime = newBullet.AddComponent<ProjectileLifetime>();
            projectileLifetime.LifeRemaining = projectileLife;

            projectileLifetime.Speed = 5;
            projectileLifetime.OnProjectileDestroyed.Add(new => OnProjectileDestroyed);
            newBullet.IsActive = true;
        }
    }
}