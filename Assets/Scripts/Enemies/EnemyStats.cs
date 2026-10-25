using UnityEngine;

/// <summary>
/// Tunable values for one enemy type (Story 002). One asset per type, e.g.
/// Assets/Data/GoblinStats.asset.
/// </summary>
[CreateAssetMenu(fileName = "EnemyStats", menuName = "Basement Run/Enemy Stats")]
public class EnemyStats : ScriptableObject
{
    /// <summary>Hits needed to kill it (one player shot deals PlayerStats.ShotDamage).</summary>
    [Min(1)] public int MaxHealth = 3;

    /// <summary>Chase speed in world units per second.</summary>
    [Min(0f)] public float MoveSpeed = 1.8f;

    /// <summary>Damage per contact, in half hearts.</summary>
    [Min(1)] public int ContactDamage = 1;

    /// <summary>Seconds between two contact hits from the same enemy.</summary>
    [Min(0f)] public float ContactCooldown = 0.8f;
}
