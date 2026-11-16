using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Qofeno.Editor
{
    public static class AndroidBuild
    {
        private const string EntryScene = "Assets/Scenes/Harbor.unity";

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
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
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
}
