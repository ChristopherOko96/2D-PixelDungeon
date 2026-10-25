using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Isaac-style heart row in the top-left corner of the view: full, half and
/// empty hearts drawn as sprites parented to the camera.
/// </summary>
public class HeartsHud : MonoBehaviour
{
    [SerializeField] private PlayerHealth _player;
    [SerializeField] private Sprite _fullHeart;
    [SerializeField] private Sprite _halfHeart;
    [SerializeField] private Sprite _emptyHeart;
    [SerializeField, Min(0f)] private float _spacing = 0.9f;
    [SerializeField] private Vector2 _margin = new Vector2(0.7f, 0.6f);
    [SerializeField] private int _sortingOrder = 100;

    private readonly List<SpriteRenderer> _hearts = new List<SpriteRenderer>();

    private void Start()
    {
        Camera cam = Camera.main;
        transform.SetParent(cam.transform, false);
        float halfHeight = cam.orthographicSize;
        float halfWidth = halfHeight * cam.aspect;
        transform.localPosition = new Vector3(-halfWidth + _margin.x, halfHeight - _margin.y, 10f);

        int heartCount = _player.Health.Max / 2;
        for (int i = 0; i < heartCount; i++)
        {
            var heart = new GameObject($"Heart_{i}").AddComponent<SpriteRenderer>();
            heart.transform.SetParent(transform, false);
            heart.transform.localPosition = new Vector3(i * _spacing, 0f, 0f);
            heart.sortingOrder = _sortingOrder;
            _hearts.Add(heart);
        }

        _player.Health.Changed += (current, max) => Refresh(current);
        Refresh(_player.Health.Current);
    }

    private void Refresh(int halfHearts)
    {
        for (int i = 0; i < _hearts.Count; i++)
        {
            int left = halfHearts - i * 2;
            _hearts[i].sprite = left >= 2 ? _fullHeart : left == 1 ? _halfHeart : _emptyHeart;
        }
    }
}
