using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

/// <summary>
/// Builds the Story 001 test room from code: pixel-art import settings for the
/// Tiny Dungeon tiles, the PlayerStats asset, the projectile prefab and
/// Assets/Scenes/TestRoom.unity (a copy of SampleScene, which brings the
/// orthographic camera and the Global Light 2D the URP 2D renderer needs).
/// Run from the menu, or headless:
/// Unity -batchmode -quit -projectPath . -executeMethod TestRoomBuilder.Build
/// </summary>
public static class TestRoomBuilder
{
    private const string TilesFolder = "Assets/Art/Sprites/TinyDungeon/Tiles";
    private const string ScenePath = "Assets/Scenes/TestRoom.unity";
    private const string StatsPath = "Assets/Data/PlayerStats.asset";
    private const string ProjectilePath = "Assets/Prefabs/Projectile.prefab";

    private const int PlayerTile = 96;
    private const int ProjectileTile = 102;
    private const int FloorTile = 48;
    private const int WallTile = 40;

    // Room size in tiles, walls included. The camera's orthographic size 5 shows 10 tiles vertically.
    private const int RoomWidth = 15;
    private const int RoomHeight = 9;

    /// <summary>Creates or rebuilds every Story 001 asset and the test scene.</summary>
    [MenuItem("Basement Run/Build Test Room")]
    public static void Build()
    {
        ConfigureTileImport();
        EnsureFolder("Assets", "Data");
        EnsureFolder("Assets", "Prefabs");

        PlayerStats stats = AssetDatabase.LoadAssetAtPath<PlayerStats>(StatsPath);
        if (stats == null)
        {
            stats = ScriptableObject.CreateInstance<PlayerStats>();
            AssetDatabase.CreateAsset(stats, StatsPath);
        }

        BuildProjectilePrefab();
        AssetDatabase.SaveAssets();
        BuildScene();

        EditorBuildSettings.scenes = new[]
        {
            new EditorBuildSettingsScene(ScenePath, true),
            new EditorBuildSettingsScene("Assets/Scenes/SampleScene.unity", true),
        };
        AssetDatabase.SaveAssets();
        Debug.Log("TestRoomBuilder: test room built at " + ScenePath);
    }

    private static void ConfigureTileImport()
    {
        foreach (string guid in AssetDatabase.FindAssets("t:Texture2D", new[] { TilesFolder }))
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            var importer = (TextureImporter)AssetImporter.GetAtPath(path);
            importer.textureType = TextureImporterType.Sprite;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.spritePixelsPerUnit = 16;
            importer.filterMode = FilterMode.Point;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.mipmapEnabled = false;
            importer.SaveAndReimport();
        }
    }

    private static Sprite Tile(int index)
    {
        return AssetDatabase.LoadAssetAtPath<Sprite>($"{TilesFolder}/tile_{index:D4}.png");
    }

    private static void BuildProjectilePrefab()
    {
        var go = new GameObject("Projectile");
        var renderer = go.AddComponent<SpriteRenderer>();
        renderer.sprite = Tile(ProjectileTile);
        renderer.sortingOrder = 20;

        var body = go.AddComponent<Rigidbody2D>();
        body.bodyType = RigidbodyType2D.Dynamic;
        body.gravityScale = 0f;
        body.collisionDetectionMode = CollisionDetectionMode2D.Continuous;

        var collider = go.AddComponent<CircleCollider2D>();
        collider.isTrigger = true;
        collider.radius = 0.15f;

        go.AddComponent<Projectile>();
        PrefabUtility.SaveAsPrefabAsset(go, ProjectilePath);
        Object.DestroyImmediate(go);
    }

    private static void BuildScene()
    {
        AssetDatabase.DeleteAsset(ScenePath);
        AssetDatabase.CopyAsset("Assets/Scenes/SampleScene.unity", ScenePath);
        var scene = EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);

        // Load from disk after the copy/open: references to objects created earlier in
        // this call were serialized as empty (fileID 0) on the first build.
        var stats = AssetDatabase.LoadAssetAtPath<PlayerStats>(StatsPath);
        var projectile = AssetDatabase.LoadAssetAtPath<GameObject>(ProjectilePath)?.GetComponent<Projectile>();
        if (stats == null || projectile == null)
            throw new System.InvalidOperationException("TestRoomBuilder: PlayerStats or Projectile prefab failed to load");

        var camera = Camera.main;
        camera.backgroundColor = new Color(0.08f, 0.06f, 0.07f);

        BuildRoom();

        var player = new GameObject("Player");
        var renderer = player.AddComponent<SpriteRenderer>();
        renderer.sprite = Tile(PlayerTile);
        renderer.sortingOrder = 10;

        var body = player.AddComponent<Rigidbody2D>();
        body.bodyType = RigidbodyType2D.Dynamic;
        body.gravityScale = 0f;
        body.freezeRotation = true;
        body.interpolation = RigidbodyInterpolation2D.Interpolate;
        body.collisionDetectionMode = CollisionDetectionMode2D.Continuous;

        var collider = player.AddComponent<CircleCollider2D>();
        collider.radius = 0.35f;

        var controller = player.AddComponent<PlayerController>();
        var serialized = new SerializedObject(controller);
        serialized.FindProperty("_stats").objectReferenceValue = stats;
        serialized.FindProperty("_projectilePrefab").objectReferenceValue = projectile;
        serialized.ApplyModifiedPropertiesWithoutUndo();
        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene);
    }

    private static void BuildRoom()
    {
        var room = new GameObject("Room");
        float left = -(RoomWidth - 1) / 2f;
        float bottom = -(RoomHeight - 1) / 2f;

        for (int x = 0; x < RoomWidth; x++)
        {
            for (int y = 0; y < RoomHeight; y++)
            {
                bool isWall = x == 0 || y == 0 || x == RoomWidth - 1 || y == RoomHeight - 1;
                var tile = new GameObject(isWall ? $"Wall_{x}_{y}" : $"Floor_{x}_{y}");
                tile.transform.SetParent(room.transform);
                tile.transform.position = new Vector3(left + x, bottom + y, 0f);
                var renderer = tile.AddComponent<SpriteRenderer>();
                renderer.sprite = Tile(isWall ? WallTile : FloorTile);
                renderer.sortingOrder = isWall ? 0 : -10;
            }
        }

        // One collider per side keeps the player inside the walls.
        float halfW = RoomWidth / 2f;
        float halfH = RoomHeight / 2f;
        AddWallCollider(room, "WallTop", new Vector2(0f, halfH - 0.5f), new Vector2(RoomWidth, 1f));
        AddWallCollider(room, "WallBottom", new Vector2(0f, -halfH + 0.5f), new Vector2(RoomWidth, 1f));
        AddWallCollider(room, "WallLeft", new Vector2(-halfW + 0.5f, 0f), new Vector2(1f, RoomHeight));
        AddWallCollider(room, "WallRight", new Vector2(halfW - 0.5f, 0f), new Vector2(1f, RoomHeight));
    }

    private static void AddWallCollider(GameObject room, string name, Vector2 center, Vector2 size)
    {
        var wall = new GameObject(name);
        wall.transform.SetParent(room.transform);
        wall.transform.position = center;
        wall.AddComponent<BoxCollider2D>().size = size;
    }

    private static void EnsureFolder(string parent, string name)
    {
        if (!AssetDatabase.IsValidFolder($"{parent}/{name}")) AssetDatabase.CreateFolder(parent, name);
    }
}
