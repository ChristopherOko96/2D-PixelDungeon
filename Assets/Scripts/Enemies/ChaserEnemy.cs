using UnityEngine;

/// <summary>
/// Walks straight at its target and hurts the player on contact, at most once
/// per contact cooldown. Dies when its health reaches 0 (Story 002).
/// </summary>
[RequireComponent(typeof(Rigidbody2D))]
public class ChaserEnemy : MonoBehaviour, IDamageable
{
    [SerializeField] private EnemyStats _stats;
    [SerializeField] private Transform _target;
    [SerializeField] private SpriteRenderer _renderer;
    [SerializeField] private SpriteFrameAnimator _animator;
    [SerializeField, Min(0f)] private float _hitFlashSeconds = 0.1f;

    private Rigidbody2D _body;
    private Health _health;
    private float _nextContactTime;
    private float _flashUntil;

    /// <summary>Sets what to chase; the scene builder wires this, spawners can call it.</summary>
    public void SetTarget(Transform target) => _target = target;

    private void Awake()
    {
        _body = GetComponent<Rigidbody2D>();
        _body.gravityScale = 0f;
        _body.freezeRotation = true;
        _health = new Health(_stats.MaxHealth);
    }

    private void Update()
    {
        _renderer.color = Time.time < _flashUntil ? new Color(1f, 0.4f, 0.4f) : Color.white;
    }

    private void FixedUpdate()
    {
        if (_target == null || !_target.gameObject.activeInHierarchy)
        {
            _animator.Running = false;
            return;
        }

        Vector2 toTarget = (Vector2)_target.position - _body.position;
        Vector2 step = toTarget.normalized * _stats.MoveSpeed * Time.fixedDeltaTime;
        _body.MovePosition(_body.position + step);
        _animator.Running = true;
        _animator.Face(toTarget.x);
    }

    private void OnCollisionStay2D(Collision2D collision)
    {
        if (Time.time < _nextContactTime) return;
        var player = collision.collider.GetComponentInParent<PlayerHealth>();
        if (player == null) return;

        player.TakeDamage(_stats.ContactDamage);
        _nextContactTime = Time.time + _stats.ContactCooldown;
    }

    /// <inheritdoc />
    public bool TakeDamage(int amount)
    {
        if (!_health.TakeDamage(amount, Time.time)) return false;
        _flashUntil = Time.time + _hitFlashSeconds;
        if (_health.IsDead) Destroy(gameObject);
        return true;
    }
}
