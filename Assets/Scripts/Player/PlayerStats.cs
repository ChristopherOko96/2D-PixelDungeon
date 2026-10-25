using UnityEngine;

/// <summary>
/// Tunable movement and shooting values for the player (Story 001).
/// Edit the asset in Assets/Data instead of changing code.
/// </summary>
[CreateAssetMenu(fileName = "PlayerStats", menuName = "Basement Run/Player Stats")]
public class PlayerStats : ScriptableObject
{
    /// <summary>Movement speed in world units per second.</summary>
    [Min(0f)] public float MoveSpeed = 4f;

    /// <summary>Shots per second while the fire input is held.</summary>
    [Min(0.1f)] public float FireRate = 3f;

    /// <summary>Projectile speed in world units per second.</summary>
    [Min(0f)] public float ProjectileSpeed = 8f;

    /// <summary>Seconds before a projectile that hit nothing despawns.</summary>
    [Min(0.05f)] public float ProjectileLifetime = 1.2f;

    /// <summary>Stick deflection below which the gamepad is treated as idle.</summary>
    [Range(0f, 0.9f)] public float StickDeadzone = 0.25f;
}
