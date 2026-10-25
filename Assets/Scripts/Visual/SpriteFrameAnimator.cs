using UnityEngine;

/// <summary>
/// Minimal frame-by-frame animation for the 0x72 sprites: loops the idle or the
/// run frames and flips the sprite to face left or right.
/// </summary>
[RequireComponent(typeof(SpriteRenderer))]
public class SpriteFrameAnimator : MonoBehaviour
{
    [SerializeField] private Sprite[] _idleFrames;
    [SerializeField] private Sprite[] _runFrames;
    [SerializeField, Min(1f)] private float _framesPerSecond = 8f;

    private SpriteRenderer _renderer;

    /// <summary>Plays the run frames when true, the idle frames otherwise.</summary>
    public bool Running { get; set; }

    private void Awake()
    {
        _renderer = GetComponent<SpriteRenderer>();
    }

    /// <summary>Faces left for a negative x, right for a positive x; 0 keeps the facing.</summary>
    public void Face(float x)
    {
        if (x < 0f) _renderer.flipX = true;
        else if (x > 0f) _renderer.flipX = false;
    }

    private void Update()
    {
        Sprite[] frames = Running && _runFrames.Length > 0 ? _runFrames : _idleFrames;
        if (frames == null || frames.Length == 0) return;
        _renderer.sprite = frames[(int)(Time.time * _framesPerSecond) % frames.Length];
    }
}
