using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Qofeno.Editor
{
    public static class AndroidBuild
    {
        internal const string EntryScene = "Assets/Scenes/Harbor.unity";

        [MenuItem("Qofeno/Build Android APK")]
        public static void BuildApk()
        {
            if (!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Android, BuildTarget.Android))
                throw new BuildFailedException("Install Android Build Support for this Unity Editor in Unity Hub.");

            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.Android &&
                !EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android))
                throw new BuildFailedException("Could not switch to Android. In batch mode pass -buildTarget Android.");

            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.qofeno.simulation.unity");
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64 | AndroidArchitecture.X86_64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel25;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            EditorUserBuildSettings.buildAppBundle = false;
            EditorUserBuildSettings.exportAsGoogleAndroidProject = false;

            string directory = Path.GetFullPath(Path.Combine(Application.dataPath, "../Builds/Android"));
            Directory.CreateDirectory(directory);
            var request = new BuildPlayerOptions
            {
                scenes = new[] { EntryScene },
                target = BuildTarget.Android,
                locationPathName = Path.Combine(directory, "Qofeno-Harbor-Market.apk"),
                options = BuildOptions.StrictMode
            };
            BuildReport report = BuildPipeline.BuildPlayer(request);
            if (report.summary.result != BuildResult.Succeeded)
                throw new BuildFailedException($"Android build {report.summary.result}, {report.summary.totalErrors} errors.");

            Debug.Log($"Wrote Android APK to {report.summary.outputPath}");
        }
    }

    // Runs for both the Unity Cloud target and the local Android build command.
    sealed class HarborStartupCheck : IProcessSceneWithReport
    {
        internal const string SurfaceShaderPath = "Assets/Qofeno/HarborSurface.shader";
        public int callbackOrder => 0;

        public void OnProcessScene(Scene scene, BuildReport report)
        {
            if (report == null || report.summary.platform != BuildTarget.Android || scene.path != AndroidBuild.EntryScene)
                return;

            int activeSessions = 0;
            foreach (var root in scene.GetRootGameObjects())
                foreach (var session in root.GetComponentsInChildren<MarketSession>())
                    if (session.isActiveAndEnabled) activeSessions++;
            if (activeSessions != 1)
                throw new BuildFailedException("Harbor needs exactly one enabled MarketSession at launch.");

            var surface = AssetDatabase.LoadAssetAtPath<Material>("Assets/Resources/MarketSurface.mat");
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(SurfaceShaderPath);
            if (!surface || !shader || surface.shader != shader)
                throw new BuildFailedException("MarketSurface.mat must reference " + SurfaceShaderPath + ".");
            if (ShaderUtil.ShaderHasError(shader))
                throw new BuildFailedException("The Harbor surface shader has compiler errors. See the shader import log.");
            foreach (string path in new[] {
                "Assets/Resources/HarborMaterials/harbor-provision-prints.png",
                "Assets/Resources/ShopModels/coastal-prints.png" })
                if (!AssetDatabase.LoadAssetAtPath<Texture2D>(path))
                    throw new BuildFailedException("Missing Harbor print artwork at " + path);
        }
    }
}
