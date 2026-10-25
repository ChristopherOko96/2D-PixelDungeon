using UnityEngine;

/// <summary>
/// The player's hearts. Health counts in half hearts (MaxHearts x 2), blinks
/// while invulnerable, and ends the run at 0.
/// </summary>
public class PlayerHealth : MonoBehaviour, IDamageable
{
    [SerializeField] private PlayerStats _stats;
    [SerializeField] private RunController _run;
    [SerializeField] private SpriteRenderer _renderer;
    [SerializeField, Min(1f)] private float _blinksPerSecond = 12f;

    /// <summary>The underlying counter, in half hearts. Created in Awake.</summary>
    public Health Health { get; private set; }

    private void Awake()
    {
        Health = new Health(_stats.MaxHearts * 2, _stats.InvulnerabilitySeconds);
        Health.Died += OnDied;
    }

    /// <inheritdoc />
    public bool TakeDamage(int amount) => Health.TakeDamage(amount, Time.time);

    private void Update()
    {
        if (Health.IsDead) return;
        bool blinking = Health.IsInvulnerable(Time.time);
        _renderer.enabled = !blinking || (int)(Time.time * _blinksPerSecond) % 2 == 0;
    }

    private void OnDied()
    {
        _renderer.enabled = true;
        _renderer.color = new Color(1f, 0.35f, 0.35f);
        GetComponent<PlayerController>().enabled = false;
        GetComponent<Rigidbody2D>().simulated = false;
        _run.EndRun();
    }
}
