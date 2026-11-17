using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace Qofeno.Editor
{
    // In batch mode omit -quit. The asynchronous Play mode transition exits the editor itself.
    [InitializeOnLoad]
    public static class SceneSmoke
    {
        const string ScenePath = "Assets/Scenes/Harbor.unity";
        const string Running = "Qofeno.Smoke.Isolated";
        const string EnteredPlay = "Qofeno.Smoke.EnteredPlay";
        const string OldScene = "Qofeno.Smoke.PreviousStartScene";
        const string Started = "Qofeno.Smoke.Started";
        const string Outcome = "Qofeno.Smoke.Outcome";
        const string SaveKey = "harbor-market.smoke.v1";
        static string startupError;
        static int readyFrame;

        static SceneSmoke()
        {
            EditorApplication.playModeStateChanged += ChangedMode;
            if (SessionState.GetBool(Running, false)) WatchStartup();
        }

        [MenuItem("Qofeno/Check Harbor Scene in Play Mode")]
        public static void Run()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode || SessionState.GetBool(Running, false))
                throw new InvalidOperationException("Start the Harbor check from Edit mode.");

            var scene = AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath);
            if (!scene) throw new InvalidOperationException("Cannot find " + ScenePath);
            var prior = EditorSceneManager.playModeStartScene;
            SessionState.SetString(OldScene, prior ? AssetDatabase.GetAssetPath(prior) : "");
            SessionState.SetString(Outcome, "");
            SessionState.SetBool(EnteredPlay, false);
            SessionState.SetFloat(Started, (float)EditorApplication.timeSinceStartup);
            SessionState.SetBool(Running, true);
            PlayerPrefs.DeleteKey(SaveKey);
            try
            {
                EditorSceneManager.playModeStartScene = scene;
                WatchStartup();
                EditorApplication.EnterPlaymode();
            }
            catch
            {
                Cleanup();
                throw;
            }
        }

        static void WatchStartup()
        {
            startupError = null;
            readyFrame = -1;
            Application.logMessageReceived += RecordError;
            EditorApplication.update += CheckWhenPlaying;
        }

        static void RecordError(string message, string stack, LogType type)
        {
            if (startupError == null && Application.isPlaying &&
                (type == LogType.Exception || type == LogType.Error || type == LogType.Assert))
                startupError = message + "\n" + stack;
        }

        static void CheckWhenPlaying()
        {
            if (!SessionState.GetBool(Running, false) || SessionState.GetString(Outcome, "") != "") return;
            if (startupError != null)
            {
                Finish(startupError);
                return;
            }
            if (EditorApplication.timeSinceStartup - SessionState.GetFloat(Started, 0) > 90)
            {
                Finish("Timed out waiting for the playable Harbor market.");
                return;
            }
            if (!SessionState.GetBool(EnteredPlay, false) || !Application.isPlaying || Time.frameCount < 1) return;
            try
            {
                Ensure(SceneManager.GetActiveScene().path == ScenePath, "Harbor is the active scene");
                var market = Object.FindFirstObjectByType<MarketSession>();
                Ensure(market && market.gameObject.scene == SceneManager.GetActiveScene(), "Harbor contains its startup session");
                var camera = Camera.main;
                Ensure(camera && camera.isActiveAndEnabled, "a main camera is active during startup");
                if (!market.IsReady) return;
                if (readyFrame < 0) readyFrame = Time.frameCount;
                if (Time.frameCount == readyFrame) return;

                Ensure(market.Shift != null && market.Walker && market.Walker.enabled,
                    "the retail shift and player controller started");
                Ensure(camera.transform.IsChildOf(market.Walker.transform) && camera.targetTexture == null,
                    "the shopkeeper camera renders to the display");
                var surfaceShader = AssetDatabase.LoadAssetAtPath<Shader>(HarborStartupCheck.SurfaceShaderPath);
                Ensure(surfaceShader && (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null || surfaceShader.isSupported),
                    "the Harbor surface shader is available");
                var view = GeometryUtility.CalculateFrustumPlanes(camera);
                bool stationInView = false;
                foreach (var name in new[] { "Shelf", "Checkout" })
                {
                    var station = market.transform.Find(name);
                    Ensure(station && station.GetComponent<BoxCollider>(), name + " has a solid collider");
                    var mesh = station.GetComponent<MeshFilter>();
                    var renderer = station.GetComponent<MeshRenderer>();
                    Ensure(mesh && mesh.sharedMesh && mesh.sharedMesh.vertexCount > 0 &&
                        renderer && renderer.enabled && renderer.gameObject.activeInHierarchy, name + " has drawable geometry");
                    var material = renderer.sharedMaterial;
                    Ensure(material && material.shader == surfaceShader && material.mainTexture,
                        name + " uses the printed Harbor surface");
                    if ((camera.cullingMask & (1 << station.gameObject.layer)) != 0 &&
                        GeometryUtility.TestPlanesAABB(view, renderer.bounds)) stationInView = true;
                }
                Ensure(stationInView, "a shop station is in view at spawn");
                var customer = market.transform.Find("Customer");
                Ensure(customer && customer.GetComponentInChildren<MeshRenderer>(true), "the shopper has a visible model");
                var canvas = market.Interface ? market.Interface.GetComponentInChildren<Canvas>() : null;
                Ensure(canvas && canvas.isActiveAndEnabled && canvas.GetComponent<GraphicRaycaster>() &&
                    EventSystem.current, "the touch HUD and event system started");
                Ensure(Array.Exists(canvas.GetComponentsInChildren<Text>(), label =>
                    label.isActiveAndEnabled && label.text.StartsWith("Day 1 ", StringComparison.Ordinal)),
                    "the shift clock is visible and populated");
                if (SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null) CheckRenderedWorld(camera);
                Finish(startupError ?? "passed");
            }
            catch (Exception exception)
            {
                Finish(exception.Message);
            }
        }

        // Compare the player's real view with its sky/clear pass. This also catches a black world hidden by a valid HUD.
        static void CheckRenderedWorld(Camera camera)
        {
            var target = RenderTexture.GetTemporary(64, 36, 24, RenderTextureFormat.ARGB32);
            var pixels = new Texture2D(target.width, target.height, TextureFormat.RGB24, false);
            var priorActive = RenderTexture.active;
            var priorTarget = camera.targetTexture;
            int priorMask = camera.cullingMask;
            try
            {
                camera.targetTexture = target;
                Color32[] ReadView()
                {
                    camera.Render();
                    RenderTexture.active = target;
                    pixels.ReadPixels(new Rect(0, 0, target.width, target.height), 0, 0, false);
                    return pixels.GetPixels32();
                }
                var world = ReadView();
                camera.cullingMask = 0;
                var sky = ReadView();
                int litWorldPixels = 0;
                int shaderErrorPixels = 0;
                for (int i = 0; i < world.Length; i++)
                {
                    var a = world[i];
                    var b = sky[i];
                    // Unity renders missing or unsupported shader passes in bright magenta.
                    if (a.r > 210 && a.b > 210 && a.g < 40) shaderErrorPixels++;
                    if ((a.r > 12 || a.g > 12 || a.b > 12) &&
                        (Math.Abs(a.r - b.r) + Math.Abs(a.g - b.g) + Math.Abs(a.b - b.b) > 24)) litWorldPixels++;
                }
                Ensure(litWorldPixels > world.Length / 100, "the camera draws lit shop geometry over its background");
                Ensure(shaderErrorPixels < world.Length / 20, "shop surfaces render without the shader error color");
            }
            finally
            {
                camera.cullingMask = priorMask;
                camera.targetTexture = priorTarget;
                RenderTexture.active = priorActive;
                RenderTexture.ReleaseTemporary(target);
                Object.DestroyImmediate(pixels);
            }
        }

        static void Ensure(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException("Harbor check failed: " + message);
        }

        static void Finish(string result)
        {
            SessionState.SetString(Outcome, result);
            EditorApplication.update -= CheckWhenPlaying;
            if (EditorApplication.isPlayingOrWillChangePlaymode) EditorApplication.ExitPlaymode();
            else Complete();
        }

        static void ChangedMode(PlayModeStateChange mode)
        {
            if (!SessionState.GetBool(Running, false)) return;
            if (mode == PlayModeStateChange.EnteredPlayMode) SessionState.SetBool(EnteredPlay, true);
            if (mode == PlayModeStateChange.EnteredEditMode) Complete();
        }

        static void Complete()
        {
            string result = SessionState.GetString(Outcome, "");
            Cleanup();
            bool passed = result == "passed";
            if (passed) Debug.Log("Harbor scene passed. The player camera, shop geometry, shift clock and touch HUD are live.");
            else Debug.LogError(string.IsNullOrEmpty(result) ? "Harbor check stopped before verification." : result);
            if (Application.isBatchMode) EditorApplication.Exit(passed ? 0 : 1);
        }

        static void Cleanup()
        {
            EditorApplication.update -= CheckWhenPlaying;
            Application.logMessageReceived -= RecordError;
            string path = SessionState.GetString(OldScene, "");
            EditorSceneManager.playModeStartScene = string.IsNullOrEmpty(path) ? null : AssetDatabase.LoadAssetAtPath<SceneAsset>(path);
            PlayerPrefs.DeleteKey(SaveKey);
            PlayerPrefs.Save();
            SessionState.EraseBool(Running);
            SessionState.EraseBool(EnteredPlay);
            SessionState.EraseString(OldScene);
            SessionState.EraseString(Outcome);
            SessionState.EraseFloat(Started);
        }
    }
}
