using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

/// <summary>
/// Builds the test room from code: pixel-art import settings for the sprite
/// packs, the data assets, the projectile and goblin prefabs and
/// Assets/Scenes/TestRoom.unity (a copy of SampleScene, which brings the
/// orthographic camera and the Global Light 2D the URP 2D renderer needs).
/// Run from the menu, or headless:
/// Unity -batchmode -quit -projectPath . -executeMethod TestRoomBuilder.Build
/// </summary>
public static class TestRoomBuilder
{
    private const string KenneyTiles = "Assets/Art/Sprites/TinyDungeon/Tiles";
    private const string Frames0x72 = "Assets/Art/Sprites/0x72/frames";
    private const string ScenePath = "Assets/Scenes/TestRoom.unity";
    private const string PlayerStatsPath = "Assets/Data/PlayerStats.asset";
    private const string GoblinStatsPath = "Assets/Data/GoblinStats.asset";
    private const string ProjectilePath = "Assets/Prefabs/Projectile.prefab";
    private const string GoblinPath = "Assets/Prefabs/Goblin.prefab";

    private const int ProjectileTile = 102;   // Kenney stone; 0x72 has no projectile sprite

    // Room size in tiles, walls included.
    private const int RoomWidth = 15;
    private const int RoomHeight = 9;
    private const float CameraSize = 5.5f;
    private const int FloorSeed = 7;
    private const float PlainFloorShare = 0.9f;
    // Heavier than the goblins (mass 1) so chasing enemies cannot shove the player around.
    private const float PlayerMass = 10f;

    private static readonly Vector2[] GoblinSpawns = { new Vector2(5f, 2.5f), new Vector2(5f, -2.5f), new Vector2(-5f, 2.5f) };

    /// <summary>Creates or rebuilds every test-room asset and the scene.</summary>
    [MenuItem("Basement Run/Build Test Room")]
    public static void Build()
    {
        ConfigurePixelArtImport(KenneyTiles);
        ConfigurePixelArtImport(Frames0x72);
        EnsureFolder("Assets", "Data");
        EnsureFolder("Assets", "Prefabs");

        EnsureAsset<PlayerStats>(PlayerStatsPath);
        EnsureAsset<EnemyStats>(GoblinStatsPath);
        BuildProjectilePrefab();
        AssetDatabase.SaveAssets();
        BuildGoblinPrefab();
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

    private static void ConfigurePixelArtImport(string folder)
    {
        foreach (string guid in AssetDatabase.FindAssets("t:Texture2D", new[] { folder }))
        {
            var importer = (TextureImporter)AssetImporter.GetAtPath(AssetDatabase.GUIDToAssetPath(guid));
            if (importer.textureType == TextureImporterType.Sprite && importer.spritePixelsPerUnit == 16
                && importer.filterMode == FilterMode.Point) continue;
            importer.textureType = TextureImporterType.Sprite;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.spritePixelsPerUnit = 16;
            importer.filterMode = FilterMode.Point;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.mipmapEnabled = false;
            importer.SaveAndReimport();
        }
    }

    private static Sprite Kenney(int index) =>
        AssetDatabase.LoadAssetAtPath<Sprite>($"{KenneyTiles}/tile_{index:D4}.png");

    private static Sprite Frame(string name)
    {
        var sprite = AssetDatabase.LoadAssetAtPath<Sprite>($"{Frames0x72}/{name}.png");
        if (sprite == null) throw new System.InvalidOperationException($"TestRoomBuilder: missing sprite {name}");
        return sprite;
    }

    private static Sprite[] Frames(string prefix, int count)
    {
        var frames = new Sprite[count];
        for (int i = 0; i < count; i++) frames[i] = Frame($"{prefix}_f{i}");
        return frames;
    }

    private static void BuildProjectilePrefab()
    {
        var go = new GameObject("Projectile");
        var renderer = go.AddComponent<SpriteRenderer>();
        renderer.sprite = Kenney(ProjectileTile);
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

    private static void BuildGoblinPrefab()
    {
        var go = new GameObject("Goblin");
        var renderer = go.AddComponent<SpriteRenderer>();
        renderer.sprite = Frame("goblin_idle_anim_f0");
        renderer.sortingOrder = 9;

        var animator = go.AddComponent<SpriteFrameAnimator>();
        SetSprites(animator, "_idleFrames", Frames("goblin_idle_anim", 4));
        SetSprites(animator, "_runFrames", Frames("goblin_run_anim", 4));

        var body = go.AddComponent<Rigidbody2D>();
        body.bodyType = RigidbodyType2D.Dynamic;
        body.gravityScale = 0f;
        body.freezeRotation = true;
        body.interpolation = RigidbodyInterpolation2D.Interpolate;

        go.AddComponent<CircleCollider2D>().radius = 0.4f;

        var enemy = go.AddComponent<ChaserEnemy>();
        SetRefs(enemy,
            ("_stats", AssetDatabase.LoadAssetAtPath<EnemyStats>(GoblinStatsPath)),
            ("_renderer", renderer),
            ("_animator", animator));

        PrefabUtility.SaveAsPrefabAsset(go, GoblinPath);
        Object.DestroyImmediate(go);
    }

    private static void BuildScene()
    {
        AssetDatabase.DeleteAsset(ScenePath);
        AssetDatabase.CopyAsset("Assets/Scenes/SampleScene.unity", ScenePath);
        var scene = EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);

        // Load from disk after the copy/open: references to objects created earlier in
        // the same call were serialized as empty (fileID 0) on the first build.
        var playerStats = AssetDatabase.LoadAssetAtPath<PlayerStats>(PlayerStatsPath);
        var projectile = AssetDatabase.LoadAssetAtPath<GameObject>(ProjectilePath)?.GetComponent<Projectile>();
        var goblinPrefab = AssetDatabase.LoadAssetAtPath<GameObject>(GoblinPath);
        if (playerStats == null || projectile == null || goblinPrefab == null)
            throw new System.InvalidOperationException("TestRoomBuilder: a data asset or prefab failed to load");

        var camera = Camera.main;
        camera.backgroundColor = new Color(0.09f, 0.07f, 0.1f);
        camera.orthographicSize = CameraSize;

        BuildRoom();

        var run = new GameObject("Run").AddComponent<RunController>();
        GameObject player = BuildPlayer(playerStats, projectile, run);

        var hud = new GameObject("HUD").AddComponent<HeartsHud>();
        SetRefs(hud,
            ("_player", player.GetComponent<PlayerHealth>()),
            ("_fullHeart", Frame("ui_heart_full")),
            ("_halfHeart", Frame("ui_heart_half")),
            ("_emptyHeart", Frame("ui_heart_empty")));

        foreach (Vector2 spawn in GoblinSpawns)
        {
            var goblin = (GameObject)PrefabUtility.InstantiatePrefab(goblinPrefab);
            goblin.transform.position = spawn;
            SetRefs(goblin.GetComponent<ChaserEnemy>(), ("_target", player.transform));
        }

        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene);
    }

    private static GameObject BuildPlayer(PlayerStats stats, Projectile projectile, RunController run)
    {
        var player = new GameObject("Player");
        var renderer = player.AddComponent<SpriteRenderer>();
        renderer.sprite = Frame("knight_m_idle_anim_f0");
        renderer.sortingOrder = 10;

        var animator = player.AddComponent<SpriteFrameAnimator>();
        SetSprites(animator, "_idleFrames", Frames("knight_m_idle_anim", 4));
        SetSprites(animator, "_runFrames", Frames("knight_m_run_anim", 4));

        var body = player.AddComponent<Rigidbody2D>();
        body.bodyType = RigidbodyType2D.Dynamic;
        body.gravityScale = 0f;
        body.freezeRotation = true;
        body.interpolation = RigidbodyInterpolation2D.Interpolate;
        body.collisionDetectionMode = CollisionDetectionMode2D.Continuous;
        body.mass = PlayerMass;

        // The knight is 28 px tall; keep the collider on his lower body.
        var collider = player.AddComponent<CircleCollider2D>();
        collider.radius = 0.35f;
        collider.offset = new Vector2(0f, -0.4f);

        var controller = player.AddComponent<PlayerController>();
        SetRefs(controller, ("_stats", stats), ("_projectilePrefab", projectile), ("_animator", animator));

        var health = player.AddComponent<PlayerHealth>();
        SetRefs(health, ("_stats", stats), ("_run", run), ("_renderer", renderer));
        return player;
    }

    private static void BuildRoom()
    {
        var room = new GameObject("Room");
        float left = -(RoomWidth - 1) / 2f;
        float bottom = -(RoomHeight - 1) / 2f;
        var random = new System.Random(FloorSeed);

        for (int x = 0; x < RoomWidth; x++)
        {
            for (int y = 0; y < RoomHeight; y++)
            {
                bool isWall = x == 0 || y == 0 || x == RoomWidth - 1 || y == RoomHeight - 1;
                Sprite sprite = isWall ? Frame("wall_mid") : Frame(FloorVariant(random));
                AddTile(room, isWall ? $"Wall_{x}_{y}" : $"Floor_{x}_{y}", new Vector2(left + x, bottom + y), sprite, isWall ? 0 : -10);
            }

            // Cap row above the top wall gives the 0x72 walls their top edge.
            AddTile(room, $"WallTop_{x}", new Vector2(left + x, bottom + RoomHeight), Frame("wall_top_mid"), 1);
        }

        // One collider per side keeps everything inside the walls.
        float halfW = RoomWidth / 2f;
        float halfH = RoomHeight / 2f;
        AddWallCollider(room, "WallTop", new Vector2(0f, halfH - 0.5f), new Vector2(RoomWidth, 1f));
        AddWallCollider(room, "WallBottom", new Vector2(0f, -halfH + 0.5f), new Vector2(RoomWidth, 1f));
        AddWallCollider(room, "WallLeft", new Vector2(-halfW + 0.5f, 0f), new Vector2(1f, RoomHeight));
        AddWallCollider(room, "WallRight", new Vector2(halfW - 0.5f, 0f), new Vector2(1f, RoomHeight));
    }

    // Mostly plain floor, with the cracked and dirty variants sprinkled in.
    private static string FloorVariant(System.Random random)
    {
        return random.NextDouble() < PlainFloorShare ? "floor_1" : $"floor_{random.Next(2, 9)}";
    }

    private static void AddTile(GameObject parent, string name, Vector2 position, Sprite sprite, int order)
    {
        var tile = new GameObject(name);
        tile.transform.SetParent(parent.transform);
        tile.transform.position = position;
        var renderer = tile.AddComponent<SpriteRenderer>();
        renderer.sprite = sprite;
        renderer.sortingOrder = order;
    }

    private static void AddWallCollider(GameObject room, string name, Vector2 center, Vector2 size)
    {
        var wall = new GameObject(name);
        wall.transform.SetParent(room.transform);
        wall.transform.position = center;
        wall.AddComponent<BoxCollider2D>().size = size;
    }

    private static void SetRefs(Object target, params (string field, Object value)[] refs)
    {
        var serialized = new SerializedObject(target);
        foreach (var (field, value) in refs)
        {
            SerializedProperty property = serialized.FindProperty(field)
                ?? throw new System.InvalidOperationException($"TestRoomBuilder: {target.GetType().Name} has no field {field}");
            property.objectReferenceValue = value;
        }
        serialized.ApplyModifiedPropertiesWithoutUndo();
    }

    private static void SetSprites(Object target, string field, Sprite[] sprites)
    {
        var serialized = new SerializedObject(target);
        SerializedProperty array = serialized.FindProperty(field);
        array.arraySize = sprites.Length;
        for (int i = 0; i < sprites.Length; i++) array.GetArrayElementAtIndex(i).objectReferenceValue = sprites[i];
        serialized.ApplyModifiedPropertiesWithoutUndo();
    }

    private static void EnsureAsset<T>(string path) where T : ScriptableObject
    {
        if (AssetDatabase.LoadAssetAtPath<T>(path) == null)
            AssetDatabase.CreateAsset(ScriptableObject.CreateInstance<T>(), path);
    }

    private static void EnsureFolder(string parent, string name)
    {
        if (!AssetDatabase.IsValidFolder($"{parent}/{name}")) AssetDatabase.CreateFolder(parent, name);
    }
}
