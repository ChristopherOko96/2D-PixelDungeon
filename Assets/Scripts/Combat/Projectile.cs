using UnityEngine;

/// <summary>
/// A straight-flying shot. Damages the first <see cref="IDamageable"/> it touches
/// that is not its owner, and despawns on any collider that is not its owner or
/// another projectile (walls, enemies), or when its lifetime runs out.
/// Needs a dynamic Rigidbody2D (gravity 0) and a trigger Collider2D.
/// </summary>
[RequireComponent(typeof(Rigidbody2D))]
public class Projectile : MonoBehaviour
{
    private GameObject _owner;
    private int _damage;

    /// <summary>
    /// Starts the projectile moving.
    /// </summary>
    /// <param name="direction">Flight direction; normalized here.</param>
    /// <param name="speed">World units per second.</param>
    /// <param name="lifetime">Seconds until it despawns on its own.</param>
    /// <param name="damage">Damage dealt to the first target hit.</param>
    /// <param name="owner">The shooter, whose colliders the shot ignores.</param>
    public void Launch(Vector2 direction, float speed, float lifetime, int damage, GameObject owner)
    {
        _owner = owner;
        _damage = damage;
        var body = GetComponent<Rigidbody2D>();
        body.gravityScale = 0f;
        body.AddForce(direction.normalized * speed * body.mass, ForceMode2D.Impulse);
        Destroy(gameObject, lifetime);
    }

    private void OnTriggerEnter2D(Collider2D other)
    {
        if (other.attachedRigidbody != null && other.attachedRigidbody.gameObject == _owner) return;
        if (other.GetComponentInParent<Projectile>() != null) return;

        other.GetComponentInParent<IDamageable>()?.TakeDamage(_damage);
        Destroy(gameObject);
    }
}
