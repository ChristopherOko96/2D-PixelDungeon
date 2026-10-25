/// <summary>Anything a projectile or contact attack can hurt.</summary>
public interface IDamageable
{
    /// <summary>Applies damage; returns true when the hit landed.</summary>
    bool TakeDamage(int amount);
}
