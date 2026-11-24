package com.qofeno.drive;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;
import android.speech.tts.TextToSpeech;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONObject;
import java.io.File;
import java.io.FileInputStream;
import java.security.MessageDigest;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Sideload channel only. Android always owns installation consent. */
public final class QofenoUpdater extends GodotPlugin {
    private static final String PACKAGE = "com.qofeno.drive";
    private static final String RELEASE_PATH = "/SohailKhan0525/simulationgame/releases/download/";
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile String verification = "";
    private volatile String lastError = "";
    private volatile long verifiedId = -1;
    private volatile long verifyingId = -1;
    private volatile boolean installPending = false;
    private TextToSpeech speech;
    private boolean speechReady;
    private String pendingSpeech = "";

    public QofenoUpdater(Godot godot) { super(godot); }

    @Override public String getPluginName() { return "QofenoUpdater"; }

    private Activity activity() {
        Activity result = getActivity();
        if (result == null) throw new IllegalStateException("Android activity is unavailable.");
        return result;
    }

    private SharedPreferences preferences() {
        return activity().getSharedPreferences("qofeno_updates", Context.MODE_PRIVATE);
    }

    private DownloadManager manager() {
        return (DownloadManager) activity().getSystemService(Context.DOWNLOAD_SERVICE);
    }

    @SuppressWarnings("deprecation")
    private PackageInfo installedPackage() throws PackageManager.NameNotFoundException {
        int flags = Build.VERSION.SDK_INT >= 28
            ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
        return activity().getPackageManager().getPackageInfo(PACKAGE, flags);
    }

    @SuppressWarnings("deprecation")
    private static long versionCode(PackageInfo info) {
        return Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
    }

    /** Returns "started" or an error; an existing identical download is resumed. */
    @UsedByGodot public synchronized String start_download(String url, String sha256, int version) {
        try {
            Uri uri = Uri.parse(url);
            if (!"https".equals(uri.getScheme()) || !"github.com".equals(uri.getHost())
                    || uri.getPort() != -1 || uri.getUserInfo() != null
                    || uri.getQuery() != null || uri.getFragment() != null
                    || uri.getPath() == null || !uri.getPath().startsWith(RELEASE_PATH)
                    || !uri.getPath().endsWith(".apk") || uri.getPath().contains(".."))
                return "Update URL is not an official Qofeno Drive release.";
            if (sha256 == null || !sha256.matches("[A-Fa-f0-9]{64}"))
                return "Update checksum is invalid.";
            if (version <= versionCode(installedPackage()))
                return "This update is not newer than the installed game.";
            SharedPreferences prefs = preferences();
            long previous = prefs.getLong("download_id", -1);
            if (previous >= 0 && !"failed".equals(verification) && url.equals(prefs.getString("url", ""))
                    && sha256.equalsIgnoreCase(prefs.getString("sha256", ""))) {
                try (Cursor cursor = manager().query(new DownloadManager.Query().setFilterById(previous))) {
                    if (cursor != null && cursor.moveToFirst()
                            && cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                            != DownloadManager.STATUS_FAILED) return "started";
                }
            }
            if (verifyingId >= 0 || installPending) return "Please wait for update verification.";
            if (previous >= 0) manager().remove(previous);
            String filename = "qofeno-update-" + version + ".apk";
            File target = new File(activity().getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), filename);
            if (target.exists() && !target.delete()) return "Unable to replace the previous update file.";
            DownloadManager.Request request = new DownloadManager.Request(uri)
                .setTitle("Qofeno Drive update")
                .setDescription("Downloading in the background. Open Qofeno Drive to install.")
                .setMimeType("application/vnd.android.package-archive")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(false)
                .setDestinationInExternalFilesDir(activity(), Environment.DIRECTORY_DOWNLOADS, filename);
            long id = manager().enqueue(request);
            prefs.edit().putLong("download_id", id).putString("url", url)
                .putString("sha256", sha256.toLowerCase(Locale.ROOT)).putInt("version_code", version)
                .putString("filename", filename).apply();
            verifiedId = -1;
            verification = "";
            lastError = "";
            return "started";
        } catch (Exception exception) {
            lastError = "Could not start update: " + exception.getMessage();
            return lastError;
        }
    }

    @UsedByGodot public synchronized String get_status() {
        JSONObject result = new JSONObject();
        try {
            result.put("state", "idle").put("progress", 0.0).put("bytes", 0)
                .put("total", 0).put("error", lastError);
            long id = preferences().getLong("download_id", -1);
            if (id < 0) return result.toString();
            if (preferences().getInt("version_code", -1) <= versionCode(installedPackage())) {
                // A successful replacement preserves preferences. Retire its downloaded APK.
                manager().remove(id);
                preferences().edit().clear().apply();
                verifiedId = -1;
                verification = "";
                lastError = "";
                return result.put("error", "").toString();
            }
            try (Cursor cursor = manager().query(new DownloadManager.Query().setFilterById(id))) {
                if (cursor == null || !cursor.moveToFirst()) {
                    return result.put("state", "failed").put("error", "Download no longer exists. Download again.").toString();
                }
                long bytes = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR));
                long total = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES));
                result.put("bytes", Math.max(0, bytes)).put("total", Math.max(0, total))
                    .put("progress", total > 0 ? Math.min(1.0, (double) bytes / total) : 0.0);
                int state = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
                if (state == DownloadManager.STATUS_SUCCESSFUL) {
                    if (verifiedId == id) result.put("state", "ready").put("progress", 1.0);
                    else if ("failed".equals(verification)) result.put("state", "failed").put("error", lastError);
                    else {
                        result.put("state", "verifying").put("progress", 1.0);
                        queueVerification(id, false);
                    }
                } else if (state == DownloadManager.STATUS_FAILED) {
                    int reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON));
                    result.put("state", "failed").put("error", "Android download failed (" + reason + "). Retry when connected.");
                } else if (state == DownloadManager.STATUS_PAUSED) {
                    result.put("state", "paused").put("error", "Download is waiting for network or Android to resume.");
                } else result.put("state", "downloading");
            }
        } catch (Exception exception) {
            try { result.put("state", "failed").put("error", exception.getMessage()); }
            catch (Exception ignored) { /* JSON primitive values do not fail here. */ }
        }
        return result.toString();
    }

    private synchronized void queueVerification(final long id, final boolean installAfter) {
        if (verifyingId >= 0) return;
        verifyingId = id;
        verification = "verifying";
        installPending = installAfter;
        final String expectedHash = preferences().getString("sha256", "");
        final int expectedVersion = preferences().getInt("version_code", -1);
        final String filename = preferences().getString("filename", "");
        final File file = new File(activity().getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), filename);
        worker.execute(() -> {
            try {
                verify(file, expectedHash, expectedVersion);
                synchronized (QofenoUpdater.this) {
                    if (preferences().getLong("download_id", -1) != id) return;
                    verifiedId = id;
                    verification = "ready";
                    lastError = "";
                }
                if (installAfter) activity().runOnUiThread(() -> launchInstaller(id));
            } catch (Exception exception) {
                verifiedId = -1;
                verification = "failed";
                lastError = "Update verification failed: " + exception.getMessage();
                installPending = false;
            } finally {
                verifyingId = -1;
            }
        });
    }

    @SuppressWarnings("deprecation")
    private void verify(File file, String expectedHash, int expectedVersion) throws Exception {
        if (!file.isFile() || file.length() <= 0) throw new IllegalStateException("APK is missing.");
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream stream = new FileInputStream(file)) {
            byte[] buffer = new byte[65536];
            int length;
            while ((length = stream.read(buffer)) != -1) digest.update(buffer, 0, length);
        }
        if (!hex(digest.digest()).equalsIgnoreCase(expectedHash))
            throw new SecurityException("APK checksum differs from the release manifest.");
        int flags = Build.VERSION.SDK_INT >= 28
            ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
        PackageInfo candidate = activity().getPackageManager().getPackageArchiveInfo(file.getAbsolutePath(), flags);
        PackageInfo current = installedPackage();
        if (candidate == null || !PACKAGE.equals(candidate.packageName))
            throw new SecurityException("APK has the wrong package name.");
        if (versionCode(candidate) != expectedVersion || versionCode(candidate) <= versionCode(current))
            throw new SecurityException("APK version does not match the newer release.");
        Set<String> currentSigners = signatures(current);
        Set<String> candidateSigners = signatures(candidate);
        if (currentSigners.isEmpty() || !currentSigners.equals(candidateSigners))
            throw new SecurityException("APK was not signed with this game's signing key.");
    }

    @SuppressWarnings("deprecation")
    private static Set<String> signatures(PackageInfo info) throws Exception {
        Signature[] signatures = Build.VERSION.SDK_INT >= 28 && info.signingInfo != null
            ? info.signingInfo.getApkContentsSigners() : info.signatures;
        Set<String> hashes = new HashSet<>();
        if (signatures != null) {
            for (Signature signature : signatures) {
                hashes.add(hex(MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())));
            }
        }
        return hashes;
    }

    private static String hex(byte[] data) {
        StringBuilder value = new StringBuilder(data.length * 2);
        for (byte item : data) value.append(String.format(Locale.ROOT, "%02x", item & 0xff));
        return value.toString();
    }

    /** Call from an explicit Install button. Permission/settings and installer are Android UI. */
    @UsedByGodot public synchronized String install_update() {
        try {
            long id = preferences().getLong("download_id", -1);
            if (id < 0 || verifiedId != id) return "Wait until the update is downloaded and verified.";
            if (installPending || verifyingId >= 0) return "verifying";
            if (Build.VERSION.SDK_INT >= 26 && !activity().getPackageManager().canRequestPackageInstalls()) {
                activity().runOnUiThread(() -> {
                    try {
                        activity().startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:" + PACKAGE)));
                    } catch (Exception exception) { lastError = "Open Android Settings to allow updates from Qofeno Drive."; }
                });
                return "permission_required";
            }
            // Rehash before every install attempt, rather than trusting a stale ready state.
            queueVerification(id, true);
            return "verifying";
        } catch (Exception exception) {
            lastError = exception.getMessage();
            return "Unable to open installer: " + lastError;
        }
    }

    private void launchInstaller(long id) {
        try {
            Uri content = manager().getUriForDownloadedFile(id);
            if (content == null || !"content".equals(content.getScheme()))
                throw new IllegalStateException("Android cannot access the downloaded APK.");
            Intent installer = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(content, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity().startActivity(installer);
        } catch (Exception exception) {
            lastError = "Unable to open Android installer: " + exception.getMessage();
        } finally { installPending = false; }
    }

    @UsedByGodot public void speak(String text) {
        if (text == null || text.isEmpty()) return;
        final String message = text.substring(0, Math.min(text.length(), 1000));
        activity().runOnUiThread(() -> {
            if (speech == null) {
                pendingSpeech = message;
                speech = new TextToSpeech(activity().getApplicationContext(), status -> {
                    speechReady = status == TextToSpeech.SUCCESS;
                    if (speechReady && speech != null) {
                        speech.setLanguage(Locale.US);
                        speech.setPitch(1.12f);
                        speech.setSpeechRate(1.08f);
                        if (!pendingSpeech.isEmpty())
                            speech.speak(pendingSpeech, TextToSpeech.QUEUE_FLUSH, null, "qofeno-voice");
                        pendingSpeech = "";
                    }
                });
            } else if (speechReady) {
                speech.speak(message, TextToSpeech.QUEUE_FLUSH, null, "qofeno-voice");
            } else pendingSpeech = message;
        });
    }

    @UsedByGodot public void stop_speech() {
        activity().runOnUiThread(() -> {
            pendingSpeech = "";
            if (speech != null) speech.stop();
        });
    }

    @Override public void onMainDestroy() {
        if (speech != null) { speech.stop(); speech.shutdown(); speech = null; }
        worker.shutdownNow();
        super.onMainDestroy();
    }
}
