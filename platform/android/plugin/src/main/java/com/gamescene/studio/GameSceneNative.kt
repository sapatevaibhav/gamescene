package com.gamescene.studio

import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * GameScene Studio's phone helpers, as the Godot singleton "GameSceneNative"
 * (wrapped by src/io/native.gd):
 *
 * - share(paths, title): the system share sheet.
 * - save_to_gallery(path, album): copies a video or picture into the gallery.
 * - take_opened_file(): a project file another app opened us with (also the
 *   "file_opened" signal).
 * - enc_open / enc_frame / enc_close: an H.264 encoder (MediaCodec) writing
 *   one MP4 segment from RGBA frames.
 * - mux_start / mux_state: joins segments and adds a WAV soundtrack as AAC,
 *   on a background thread.
 *
 * Nothing here touches the network.
 */
class GameSceneNative(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName() = "GameSceneNative"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(SignalInfo("file_opened", String::class.java))

    // ------------------------------------------------------------ device

    @UsedByGodot
    fun sdk_int(): Int = Build.VERSION.SDK_INT

    // ------------------------------------------------------------ back

    /** Back on the home screen: hide the app like other apps do, without closing it. */
    @UsedByGodot
    fun go_background() {
        val act = activity ?: return
        act.runOnUiThread { act.moveTaskToBack(true) }
    }

    // ------------------------------------------------------------ refresh rate

    /**
     * Asks for the display's refresh rate closest to `hz` (0 = the highest it
     * has). Android shows apps at 60 Hz unless they ask. Returns the rate
     * chosen.
     */
    @UsedByGodot
    fun set_refresh_rate(hz: Float): Float {
        val act = activity ?: return 0f
        val display = if (Build.VERSION.SDK_INT >= 30) act.display else @Suppress("DEPRECATION") act.windowManager.defaultDisplay
        display ?: return 0f
        val mode = display.mode
        val rates = ArrayList<Float>()
        rates.add(mode.refreshRate)
        if (Build.VERSION.SDK_INT >= 31) rates.addAll(mode.alternativeRefreshRates.toList())
        for (m in display.supportedModes) {
            if (m.physicalWidth == mode.physicalWidth && m.physicalHeight == mode.physicalHeight) rates.add(m.refreshRate)
        }
        val best = if (hz <= 0f) rates.max() else rates.filter { it <= hz + 0.5f }.maxOrNull() ?: rates.min()
        val modeId = display.supportedModes.firstOrNull {
            it.physicalWidth == mode.physicalWidth && it.physicalHeight == mode.physicalHeight && kotlin.math.abs(it.refreshRate - best) < 0.5f
        }?.modeId ?: 0
        act.runOnUiThread {
            val lp = act.window.attributes
            lp.preferredRefreshRate = best
            if (modeId != 0) lp.preferredDisplayModeId = modeId
            act.window.attributes = lp
        }
        return best
    }

    // ------------------------------------------------------------ share

    @UsedByGodot
    fun share(paths: Array<String>, title: String): Boolean {
        val act = activity ?: return false
        return try {
            val uris = ArrayList<Uri>()
            for (p in paths) {
                val f = File(p)
                if (f.isFile) uris.add(FileProvider.getUriForFile(act, act.packageName + FileProviderAuthority, f))
            }
            if (uris.isEmpty()) return false
            val send = if (uris.size == 1) {
                Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
            } else {
                Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            }
            send.type = commonMime(paths)
            val clip = ClipData.newRawUri(title, uris[0])
            for (u in uris.drop(1)) clip.addItem(ClipData.Item(u))
            send.clipData = clip
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val chooser = Intent.createChooser(send, title)
            chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            act.runOnUiThread { act.startActivity(chooser) }
            true
        } catch (e: Exception) {
            Log.w(TAG, "share failed", e)
            false
        }
    }

    // ------------------------------------------------------------ gallery

    /**
     * Copies a video or picture into Movies/<album> or Pictures/<album>, in the
     * background (a long video takes a moment). Returns "started", or "".
     */
    @UsedByGodot
    fun save_to_gallery(path: String, album: String): String {
        if (activity == null || !File(path).isFile) return ""
        Thread { copyToGallery(path, album) }.start()
        return "started"
    }

    private fun copyToGallery(path: String, album: String): String {
        val act = activity ?: return ""
        val f = File(path)
        if (!f.isFile) return ""
        val mime = mimeOf(path)
        val video = mime.startsWith("video/")
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val coll = if (video) MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                else MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                val cv = ContentValues()
                cv.put(MediaStore.MediaColumns.DISPLAY_NAME, f.name)
                cv.put(MediaStore.MediaColumns.MIME_TYPE, mime)
                cv.put(MediaStore.MediaColumns.RELATIVE_PATH, (if (video) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES) + "/" + album)
                cv.put(MediaStore.MediaColumns.IS_PENDING, 1)
                val res = act.contentResolver
                val uri = res.insert(coll, cv) ?: return ""
                res.openOutputStream(uri).use { out -> f.inputStream().use { it.copyTo(out!!) } }
                cv.clear()
                cv.put(MediaStore.MediaColumns.IS_PENDING, 0)
                res.update(uri, cv, null, null)
                uri.toString()
            } else {
                @Suppress("DEPRECATION")
                val dir = File(Environment.getExternalStoragePublicDirectory(if (video) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES), album)
                dir.mkdirs()
                val dest = File(dir, f.name)
                f.copyTo(dest, true)
                MediaScannerConnection.scanFile(act, arrayOf(dest.path), arrayOf(mime), null)
                dest.path
            }
        } catch (e: Exception) {
            Log.w(TAG, "save_to_gallery failed", e)
            ""
        }
    }

    // ------------------------------------------------------------ thumbnails

    /** Saves one frame of a video (half a second in) as a PNG `width` pixels wide. */
    @UsedByGodot
    fun video_thumbnail(path: String, out: String, width: Int): Boolean {
        val r = android.media.MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val frame = r.getFrameAtTime(500_000L, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC) ?: return false
            val h = maxOf(1, frame.height * width / maxOf(1, frame.width))
            val small = android.graphics.Bitmap.createScaledBitmap(frame, width, h, true)
            File(out).parentFile?.mkdirs()
            File(out).outputStream().use { small.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
            true
        } catch (e: Exception) {
            Log.w(TAG, "video_thumbnail failed", e)
            false
        } finally {
            r.release()
        }
    }

    // ------------------------------------------------------------ opened files

    private var opened = ""
    private var seenIntent: Intent? = null

    override fun onMainResume() {
        checkIntent()
    }

    /** A file another app opened us with since the last call (copied into the cache), or "". */
    @UsedByGodot
    fun take_opened_file(): String {
        checkIntent()
        val p = opened
        opened = ""
        return p
    }

    @Synchronized
    private fun checkIntent() {
        val act = activity ?: return
        val intent = act.intent ?: return
        if (intent === seenIntent) return
        seenIntent = intent
        val uri: Uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        } ?: return
        val path = copyIn(uri) ?: return
        opened = path
        emitSignal("file_opened", path)
    }

    private fun copyIn(uri: Uri): String? {
        val act = activity ?: return null
        return try {
            var name = uri.lastPathSegment?.substringAfterLast('/') ?: "opened.json"
            if (uri.scheme == "content") {
                act.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                    if (c.moveToFirst() && !c.isNull(0)) name = c.getString(0)
                }
            }
            name = name.replace(Regex("[^A-Za-z0-9._ -]"), "_").ifBlank { "opened.json" }
            val dir = File(act.cacheDir, "opened")
            dir.mkdirs()
            val dest = File(dir, name)
            act.contentResolver.openInputStream(uri)!!.use { inp -> dest.outputStream().use { inp.copyTo(it) } }
            dest.path
        } catch (e: Exception) {
            Log.w(TAG, "couldn't read the opened file", e)
            null
        }
    }

    // ------------------------------------------------------------ video encoder

    private val encoders = HashMap<Int, VideoEncoder>()
    private var nextEnc = 1

    /** True when the phone has an H.264 encoder. */
    @UsedByGodot
    fun can_encode(): Boolean {
        return try {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { ci ->
                ci.isEncoder && ci.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, true) }
            }
        } catch (e: Exception) {
            false
        }
    }

    /** Starts an MP4 segment; returns an id for enc_frame / enc_close, or -1. */
    @UsedByGodot
    fun enc_open(path: String, width: Int, height: Int, fps: Int, bitrate: Int): Int {
        return try {
            val e = VideoEncoder(path, width, height, fps, bitrate)
            val id = nextEnc++
            encoders[id] = e
            id
        } catch (e: Exception) {
            Log.w(TAG, "enc_open failed", e)
            -1
        }
    }

    /** One RGBA8 frame (width * height * 4 bytes). */
    @UsedByGodot
    fun enc_frame(id: Int, rgba: ByteArray): Boolean {
        val e = encoders[id] ?: return false
        return try {
            e.frame(rgba)
        } catch (ex: Exception) {
            Log.w(TAG, "enc_frame failed", ex)
            false
        }
    }

    /** Finishes the segment file. */
    @UsedByGodot
    fun enc_close(id: Int): Boolean {
        val e = encoders.remove(id) ?: return false
        return e.close()
    }

    // ------------------------------------------------------------ joining

    @Volatile
    private var muxState = ""

    /** Joins MP4 segments (in order) and adds the WAV soundtrack, in the background. Poll mux_state(). */
    @UsedByGodot
    fun mux_start(segments: Array<String>, wav: String, out: String, fps: Int): Boolean {
        if (muxState == "running" || segments.isEmpty()) return false
        muxState = "running"
        Thread {
            muxState = try {
                Joiner.join(segments, wav, out, fps)
                "ok"
            } catch (e: Throwable) {
                Log.w(TAG, "joining failed", e)
                File(out).delete()
                "error: " + (e.message ?: e.javaClass.simpleName)
            }
        }.start()
        return true
    }

    /** "" (never started), "running", "ok" or "error: ...". */
    @UsedByGodot
    fun mux_state(): String = muxState

    companion object {
        const val TAG = "GameSceneNative"
        const val FileProviderAuthority = ".gamescene.files"

        fun mimeOf(path: String): String {
            val ext = path.substringAfterLast('.', "").lowercase()
            if (ext == "json") return "application/json"
            return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
        }

        fun commonMime(paths: Array<String>): String {
            val mimes = paths.map { mimeOf(it) }.toSet()
            if (mimes.size == 1) return mimes.first()
            val tops = mimes.map { it.substringBefore('/') }.toSet()
            return if (tops.size == 1) tops.first() + "/*" else "*/*"
        }
    }
}


/** Our own FileProvider class, so it never clashes with one the engine declares. */
class GameSceneFileProvider : FileProvider()


/**
 * One H.264 MP4 file from RGBA frames: converted to YUV 4:2:0 (BT.709,
 * limited range) straight into the encoder's input image.
 */
private class VideoEncoder(path: String, val w: Int, val h: Int, val fps: Int, bitrate: Int) {
    private val codec: MediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private val info = MediaCodec.BufferInfo()
    private var track = -1
    private var started = false
    private var n = 0L
    private val yRow = ByteArray(w)
    private val uRow = ByteArray(w / 2)
    private val vRow = ByteArray(w / 2)
    private val pair = ByteArray(w)
    private val wantBitrate = bitrate

    init {
        try {
            codec.configure(format(true), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        } catch (e: Exception) {
            // Some encoders refuse the High profile: fall back to their default.
            codec.reset()
            codec.configure(format(false), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }
        codec.start()
    }

    private fun format(high: Boolean): MediaFormat {
        val f = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h)
        f.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
        f.setInteger(MediaFormat.KEY_BIT_RATE, bitrateOr(w, h, fps))
        f.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        f.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        f.setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
        f.setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
        f.setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        if (high) {
            f.setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileHigh)
            f.setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel41)
        }
        return f
    }

    private fun bitrateOr(w: Int, h: Int, fps: Int): Int {
        if (wantBitrate > 0) return wantBitrate
        return (w.toLong() * h * fps / 5).coerceIn(2_000_000L, 40_000_000L).toInt()
    }

    private fun now() = System.currentTimeMillis()

    private fun inputIndex(): Int {
        val t0 = now()
        while (true) {
            val i = codec.dequeueInputBuffer(10_000)
            if (i >= 0) return i
            drain(false)
            if (now() - t0 > 5000) return -1
        }
    }

    fun frame(rgba: ByteArray): Boolean {
        if (rgba.size < w * h * 4) return false
        val idx = inputIndex()
        if (idx < 0) return false
        val cap = codec.getInputBuffer(idx)!!.capacity()
        val img = codec.getInputImage(idx) ?: return false
        fill(img, rgba)
        codec.queueInputBuffer(idx, 0, cap, n * 1_000_000L / fps, 0)
        n++
        drain(false)
        return true
    }

    private fun fill(img: android.media.Image, s: ByteArray) {
        val pl = img.planes
        val yb = pl[0].buffer
        val yrs = pl[0].rowStride
        val yps = pl[0].pixelStride
        for (y in 0 until h) {
            var si = y * w * 4
            for (x in 0 until w) {
                val r = s[si].toInt() and 255
                val g = s[si + 1].toInt() and 255
                val b = s[si + 2].toInt() and 255
                yRow[x] = (((47 * r + 157 * g + 16 * b + 128) shr 8) + 16).toByte()
                si += 4
            }
            val off = y * yrs
            if (yps == 1) {
                yb.position(off)
                yb.put(yRow, 0, minOf(w, yb.limit() - off))
            } else {
                for (x in 0 until w) yb.put(off + x * yps, yRow[x])
            }
        }
        val ub = pl[1].buffer
        val vb = pl[2].buffer
        val cw = w / 2
        val ch = h / 2
        val row = w * 4
        for (cy in 0 until ch) {
            var si = cy * 2 * row
            for (cx in 0 until cw) {
                val r = ((s[si].toInt() and 255) + (s[si + 4].toInt() and 255) + (s[si + row].toInt() and 255) + (s[si + row + 4].toInt() and 255)) shr 2
                val g = ((s[si + 1].toInt() and 255) + (s[si + 5].toInt() and 255) + (s[si + row + 1].toInt() and 255) + (s[si + row + 5].toInt() and 255)) shr 2
                val b = ((s[si + 2].toInt() and 255) + (s[si + 6].toInt() and 255) + (s[si + row + 2].toInt() and 255) + (s[si + row + 6].toInt() and 255)) shr 2
                uRow[cx] = (((-26 * r - 87 * g + 112 * b + 128) shr 8) + 128).coerceIn(0, 255).toByte()
                vRow[cx] = (((112 * r - 102 * g - 10 * b + 128) shr 8) + 128).coerceIn(0, 255).toByte()
                si += 8
            }
            plane(ub, cy * pl[1].rowStride, pl[1].pixelStride, uRow, vRow, cw)
            plane(vb, cy * pl[2].rowStride, pl[2].pixelStride, vRow, uRow, cw)
        }
    }

    /**
     * One chroma row. With a pixel stride of 2 the U and V planes are usually
     * one interleaved buffer seen from two starting points, so the other
     * plane's values go in between (correct when they overlap, harmless
     * padding when they don't).
     */
    private fun plane(buf: ByteBuffer, off: Int, ps: Int, a: ByteArray, b: ByteArray, n: Int) {
        if (off >= buf.limit()) return
        when (ps) {
            1 -> {
                buf.position(off)
                buf.put(a, 0, minOf(n, buf.limit() - off))
            }
            2 -> {
                for (i in 0 until n) {
                    pair[2 * i] = a[i]
                    pair[2 * i + 1] = b[i]
                }
                buf.position(off)
                buf.put(pair, 0, minOf(2 * n, buf.limit() - off))
            }
            else -> for (i in 0 until n) {
                val p = off + i * ps
                if (p < buf.limit()) buf.put(p, a[i])
            }
        }
    }

    private fun drain(eos: Boolean): Boolean {
        val t0 = now()
        while (true) {
            val i = codec.dequeueOutputBuffer(info, if (eos) 10_000 else 0)
            if (i == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!eos) return true
                if (now() - t0 > 10_000) return false
            } else if (i == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                track = muxer.addTrack(codec.outputFormat)
                muxer.start()
                started = true
            } else if (i >= 0) {
                val buf = codec.getOutputBuffer(i)!!
                if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                if (info.size > 0 && started) {
                    buf.position(info.offset)
                    buf.limit(info.offset + info.size)
                    muxer.writeSampleData(track, buf, info)
                }
                codec.releaseOutputBuffer(i, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return true
            }
        }
    }

    fun close(): Boolean {
        var ok = n > 0
        try {
            val idx = inputIndex()
            if (idx >= 0) {
                codec.queueInputBuffer(idx, 0, 0, n * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                ok = drain(true) && ok
            } else {
                ok = false
            }
        } catch (e: Exception) {
            Log.w(GameSceneNative.TAG, "closing the encoder failed", e)
            ok = false
        }
        try {
            codec.stop()
        } catch (_: Exception) {
        }
        codec.release()
        try {
            if (started) muxer.stop()
        } catch (e: Exception) {
            ok = false
        }
        muxer.release()
        return ok && started
    }
}


/** Joins H.264 segments into one MP4 and adds a WAV soundtrack as AAC. */
private object Joiner {
    private class Sample(val data: ByteArray, val pts: Long, val flags: Int)
    private class Aac(val format: MediaFormat, val samples: List<Sample>)

    fun join(segments: Array<String>, wav: String, out: String, fps: Int) {
        val audio = if (wav != "" && File(wav).isFile) encodeAac(wav) else null
        val first = MediaExtractor()
        first.setDataSource(segments[0])
        val vfmt = first.getTrackFormat(videoTrack(first))
        first.release()
        val maxIn = if (vfmt.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) vfmt.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE) else 0
        val buf = ByteBuffer.allocateDirect(maxOf(maxIn, 16 shl 20))
        File(out).delete()
        val muxer = MediaMuxer(out, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            val vOut = muxer.addTrack(vfmt)
            val aOut = if (audio != null) muxer.addTrack(audio.format) else -1
            muxer.start()
            val info = MediaCodec.BufferInfo()
            val frameUs = 1_000_000L / maxOf(1, fps)
            var offset = 0L
            var ai = 0
            fun writeAudio(upTo: Long) {
                if (audio == null) return
                while (ai < audio.samples.size && audio.samples[ai].pts <= upTo) {
                    val s = audio.samples[ai++]
                    info.set(0, s.data.size, s.pts, s.flags)
                    muxer.writeSampleData(aOut, ByteBuffer.wrap(s.data), info)
                }
            }
            for (seg in segments) {
                val ex = MediaExtractor()
                ex.setDataSource(seg)
                ex.selectTrack(videoTrack(ex))
                var last = -frameUs
                while (true) {
                    buf.clear()
                    val size = ex.readSampleData(buf, 0)
                    if (size < 0) break
                    val pts = ex.sampleTime + offset
                    writeAudio(pts)
                    val flags = if (ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
                    info.set(0, size, pts, flags)
                    muxer.writeSampleData(vOut, buf, info)
                    last = maxOf(last, ex.sampleTime)
                    ex.advance()
                }
                ex.release()
                offset += last + frameUs
            }
            // The rest of the sound, up to the end of the picture.
            writeAudio(offset - 1)
            muxer.stop()
        } finally {
            muxer.release()
        }
    }

    private fun videoTrack(ex: MediaExtractor): Int {
        for (i in 0 until ex.trackCount) {
            if (ex.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true) return i
        }
        throw IllegalStateException("no video in a segment")
    }

    /** 16-bit PCM WAV -> AAC-LC samples in memory (a few MB for a long film). */
    private fun encodeAac(path: String): Aac? {
        val bytes = File(path).readBytes()
        val le = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var p = 12
        var channels = 1
        var rate = 44100
        var bits = 16
        var dataStart = -1
        var dataLen = 0
        while (p + 8 <= bytes.size) {
            val id = String(bytes, p, 4, Charsets.US_ASCII)
            val len = le.getInt(p + 4)
            if (id == "fmt ") {
                channels = le.getShort(p + 10).toInt()
                rate = le.getInt(p + 12)
                bits = le.getShort(p + 22).toInt()
            } else if (id == "data") {
                dataStart = p + 8
                dataLen = minOf(len, bytes.size - dataStart)
                break
            }
            p += 8 + len + (len and 1)
        }
        if (dataStart < 0 || bits != 16 || channels < 1) return null
        val frameBytes = channels * 2
        val fmt = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, rate, channels)
        fmt.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        fmt.setInteger(MediaFormat.KEY_BIT_RATE, if (channels > 1) 192_000 else 128_000)
        fmt.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        codec.configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        val info = MediaCodec.BufferInfo()
        val out = ArrayList<Sample>()
        var outFmt: MediaFormat? = null
        var pos = 0
        var inputDone = false
        try {
            while (true) {
                if (!inputDone) {
                    val i = codec.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val ib = codec.getInputBuffer(i)!!
                        ib.clear()
                        var n = minOf(ib.remaining(), dataLen - pos)
                        n -= n % frameBytes
                        ib.put(bytes, dataStart + pos, n)
                        val pts = (pos / frameBytes).toLong() * 1_000_000L / rate
                        pos += n
                        inputDone = dataLen - pos < frameBytes || n == 0
                        codec.queueInputBuffer(i, 0, n, pts, if (inputDone) MediaCodec.BUFFER_FLAG_END_OF_STREAM else 0)
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10_000)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    outFmt = codec.outputFormat
                } else if (o >= 0) {
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && info.size > 0) {
                        val ob = codec.getOutputBuffer(o)!!
                        ob.position(info.offset)
                        val data = ByteArray(info.size)
                        ob.get(data)
                        out.add(Sample(data, info.presentationTimeUs, 0))
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }
        } finally {
            codec.stop()
            codec.release()
        }
        return if (outFmt != null && out.isNotEmpty()) Aac(outFmt, out) else null
    }
}
