using System;

/// <summary>
/// Plain hit-point counter with optional invulnerability after each hit.
/// No Unity dependency: the caller passes the current time, so the class can be
/// tested in EditMode without a scene (Story 002).
/// </summary>
public class Health
{
    private readonly float _invulnerableSeconds;
    private float _invulnerableUntil = float.NegativeInfinity;

    /// <summary>Raised after a hit lands: (current, max).</summary>
    public event Action<int, int> Changed;

    /// <summary>Raised once, when current reaches 0.</summary>
    public event Action Died;

    /// <summary>Maximum hit points.</summary>
    public int Max { get; }

    /// <summary>Current hit points, between 0 and <see cref="Max"/>.</summary>
    public int Current { get; private set; }

    /// <summary>True once current has reached 0.</summary>
    public bool IsDead => Current <= 0;

    /// <param name="max">Starting and maximum hit points; must be positive.</param>
    /// <param name="invulnerableSeconds">Seconds after a hit during which further hits are ignored.</param>
    public Health(int max, float invulnerableSeconds = 0f)
    {
        if (max <= 0) throw new ArgumentOutOfRangeException(nameof(max), "Health needs at least 1 hit point.");
        Max = max;
        Current = max;
        _invulnerableSeconds = Math.Max(0f, invulnerableSeconds);
    }

    /// <summary>True while hits are ignored after the last one landed.</summary>
    public bool IsInvulnerable(float now) => now < _invulnerableUntil;

    /// <summary>
    /// Applies damage unless dead, invulnerable, or the amount is not positive.
    /// </summary>
    /// <returns>True when the hit landed.</returns>
    public bool TakeDamage(int amount, float now)
    {
        if (amount <= 0 || IsDead || IsInvulnerable(now)) return false;

        Current = Math.Max(0, Current - amount);
        _invulnerableUntil = now + _invulnerableSeconds;
        Changed?.Invoke(Current, Max);
        if (IsDead) Died?.Invoke();
        return true;
    }
}
