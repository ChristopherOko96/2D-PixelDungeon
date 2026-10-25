using UnityEngine;
using UnityEngine.InputSystem;

/// <summary>
/// Twin-stick player: WASD / left stick moves, the mouse aims (hold left button
/// to fire), arrow keys and the right stick also aim and fire.
/// Aim priority: right stick, then arrow keys, then mouse.
/// </summary>
[RequireComponent(typeof(Rigidbody2D))]
public class PlayerController : MonoBehaviour
{
    [SerializeField] private PlayerStats _stats;
    [SerializeField] private Projectile _projectilePrefab;

    private Rigidbody2D _body;
    private Camera _camera;
    private Vector2 _move;
    private float _nextShotTime;

    private void Awake()
    {
        _body = GetComponent<Rigidbody2D>();
        _body.gravityScale = 0f;
        _body.freezeRotation = true;
        _camera = Camera.main;
    }

    private void Update()
    {
        _move = ReadMove();
        if (TryReadAim(out Vector2 aim) && Time.time >= _nextShotTime)
        {
            Shoot(aim);
            _nextShotTime = Time.time + 1f / _stats.FireRate;
        }
    }

    private void FixedUpdate()
    {
        _body.MovePosition(_body.position + _move * _stats.MoveSpeed * Time.fixedDeltaTime);
    }

    /// <summary>Movement input, clamped to length 1 so diagonals are not faster.</summary>
    private Vector2 ReadMove()
    {
        Vector2 move = Vector2.zero;
        var keyboard = Keyboard.current;
        if (keyboard != null)
        {
            if (keyboard.wKey.isPressed) move.y += 1f;
            if (keyboard.sKey.isPressed) move.y -= 1f;
            if (keyboard.dKey.isPressed) move.x += 1f;
            if (keyboard.aKey.isPressed) move.x -= 1f;
        }

        var gamepad = Gamepad.current;
        if (gamepad != null)
        {
            Vector2 stick = gamepad.leftStick.ReadValue();
            if (stick.magnitude > _stats.StickDeadzone) move += stick;
        }

        return Vector2.ClampMagnitude(move, 1f);
    }

    /// <summary>Returns true and the aim direction when any fire input is active.</summary>
    private bool TryReadAim(out Vector2 aim)
    {
        var gamepad = Gamepad.current;
        if (gamepad != null)
        {
            aim = gamepad.rightStick.ReadValue();
            if (aim.magnitude > _stats.StickDeadzone) return true;
        }

        aim = Vector2.zero;
        var keyboard = Keyboard.current;
        if (keyboard != null)
        {
            if (keyboard.upArrowKey.isPressed) aim.y += 1f;
            if (keyboard.downArrowKey.isPressed) aim.y -= 1f;
            if (keyboard.rightArrowKey.isPressed) aim.x += 1f;
            if (keyboard.leftArrowKey.isPressed) aim.x -= 1f;
            if (aim != Vector2.zero) return true;
        }

        var mouse = Mouse.current;
        if (mouse != null && mouse.leftButton.isPressed && _camera != null)
        {
            Vector3 screen = mouse.position.ReadValue();
            screen.z = -_camera.transform.position.z;
            aim = (Vector2)_camera.ScreenToWorldPoint(screen) - _body.position;
            return aim.sqrMagnitude > 0.0001f;
        }

        return false;
    }

    private void Shoot(Vector2 direction)
    {
        Projectile shot = Instantiate(_projectilePrefab, _body.position, Quaternion.identity);
        shot.Launch(direction, _stats.ProjectileSpeed, _stats.ProjectileLifetime, gameObject);
    }
}
