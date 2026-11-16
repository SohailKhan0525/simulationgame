using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
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

        static SceneSmoke()
        {
            EditorApplication.playModeStateChanged += ChangedMode;
            if (SessionState.GetBool(Running, false)) EditorApplication.update += CheckWhenPlaying;
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
                EditorApplication.update += CheckWhenPlaying;
                EditorApplication.EnterPlaymode();
            }
            catch
            {
                Cleanup();
                throw;
            }
        }

        static void CheckWhenPlaying()
        {
            if (!SessionState.GetBool(Running, false) || SessionState.GetString(Outcome, "") != "") return;
            if (EditorApplication.timeSinceStartup - SessionState.GetFloat(Started, 0) > 90)
            {
                Finish("Timed out entering Harbor Play mode.");
                return;
            }
            if (!SessionState.GetBool(EnteredPlay, false) || !Application.isPlaying || Time.frameCount < 3) return;
            try
            {
                Ensure(SceneManager.GetActiveScene().path == ScenePath, "Harbor is the active scene");
                var market = Object.FindFirstObjectByType<MarketSession>();
                Ensure(market && market.Shift != null && market.Walker && market.Walker.enabled,
                    "the retail shift and player controller started");
                Ensure(Camera.main && Camera.main.isActiveAndEnabled, "the player's camera is live");
                foreach (var name in new[] { "Shelf", "Checkout" })
                {
                    var station = market.transform.Find(name);
                    Ensure(station && station.GetComponent<BoxCollider>(), name + " has a solid collider");
                }
                var customer = market.transform.Find("Customer");
                Ensure(customer && customer.GetComponentInChildren<MeshRenderer>(true), "the shopper has a visible model");
                var canvas = market.Interface ? market.Interface.GetComponentInChildren<Canvas>() : null;
                Ensure(canvas && canvas.isActiveAndEnabled && canvas.GetComponent<GraphicRaycaster>() &&
                    EventSystem.current, "the touch HUD and event system started");
                Finish("passed");
            }
            catch (Exception exception)
            {
                Finish(exception.Message);
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
            if (passed) Debug.Log("Harbor scene passed. Camera, retail shift, customer, station colliders and touch HUD are live.");
            else Debug.LogError(string.IsNullOrEmpty(result) ? "Harbor check stopped before verification." : result);
            if (Application.isBatchMode) EditorApplication.Exit(passed ? 0 : 1);
        }

        static void Cleanup()
        {
            EditorApplication.update -= CheckWhenPlaying;
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
