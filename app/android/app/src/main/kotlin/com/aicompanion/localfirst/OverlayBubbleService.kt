package com.aicompanion.localfirst

import android.app.KeyguardManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.BaseAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/**
 * Foreground companion service hosting two real Android overlay windows:
 *
 * 1. a tiny draggable unread bubble;
 * 2. a native WindowManager chat panel backed by the persistent headless
 *    FlutterEngine.
 *
 * v0.13 intentionally does NOT put a FlutterView directly inside a Service
 * overlay. Flutter's current embedding documents FlutterView as Activity-owned
 * advanced integration. The native panel keeps TYPE_APPLICATION_OVERLAY fully
 * supported while all conversation/memory/Desire logic stays in Dart.
 */
class OverlayBubbleService : Service() {
    private lateinit var windowManager: WindowManager

    private var bubbleRoot: FrameLayout? = null
    private var badge: TextView? = null
    private lateinit var bubbleParams: WindowManager.LayoutParams

    private var chatRoot: FrameLayout? = null
    private var chatList: ListView? = null
    private var chatAdapter: NativeChatAdapter? = null
    private var chatInput: OverlayEditText? = null
    private var chatSend: Button? = null
    private var chatStatus: TextView? = null
    private var chatLoadOlder: Button? = null
    private var chatParams: WindowManager.LayoutParams? = null
    private var chatExpanded = false
    private var chatInputMode = false
    private var chatSending = false
    private var pendingShowAfterUnlock = false
    private var loadedMessages = mutableListOf<NativeChatMessage>()

    private var backgroundEngine: FlutterEngine? = null
    private var backgroundSystemBridge: BackgroundSystemBridge? = null
    private var backgroundTtsBridge: NativeTtsBridge? = null
    private var backgroundCommands: MethodChannel? = null
    private var pendingBrainWakeReason: String? = null
    private var brainWakeAttempt = 0
    private val pendingInlineReplies = mutableListOf<PendingInlineReply>()
    private var inlineReplyInFlight = false
    private var backgroundEngineStarting = false
    private var backgroundEngineStartAttempts = 0
    private var backgroundEngineRestartScheduled = false
    private var inputRecoveryScheduled = false
    private var inputRecoveryInProgress = false
    private var lastInputRecoveryAt = 0L

    private val mainHandler = Handler(Looper.getMainLooper())
    private var stateReceiverRegistered = false
    private var destroyReason = "service_destroyed"

    private val permissionWatch = object : Runnable {
        override fun run() {
            if (!CompanionRuntimeState.isOverlayUserEnabled(this@OverlayBubbleService)) {
                destroyReason = "user_disabled"
                stopSelf()
                return
            }
            if (!Settings.canDrawOverlays(this@OverlayBubbleService)) {
                NativeEventStore.addDeviceEvent(
                    this@OverlayBubbleService,
                    source = "system",
                    eventType = "overlay_permission_lost",
                    appPackage = packageName,
                    summary = "悬浮陪伴运行期间，系统悬浮窗权限被撤销。",
                )
                destroyReason = "overlay_permission_lost"
                stopSelf()
                return
            }
            ensureOverlayHealth("permission_watch")
            mainHandler.postDelayed(this, PERMISSION_WATCH_MS)
        }
    }

    private val deviceStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            val eventType = when (action) {
                Intent.ACTION_SCREEN_ON -> "screen_on"
                Intent.ACTION_SCREEN_OFF -> "screen_off"
                Intent.ACTION_USER_PRESENT -> "user_present"
                Intent.ACTION_POWER_CONNECTED -> "power_connected"
                Intent.ACTION_POWER_DISCONNECTED -> "power_disconnected"
                else -> return
            }
            val power = getSystemService(PowerManager::class.java)
            val keyguard = getSystemService(KeyguardManager::class.java)
            NativeEventStore.addDeviceEvent(
                this@OverlayBubbleService,
                source = "system",
                eventType = eventType,
                appPackage = packageName,
                summary = when (eventType) {
                    "screen_on" -> "屏幕亮起"
                    "screen_off" -> "屏幕熄灭"
                    "user_present" -> "设备已解锁并进入可交互状态"
                    "power_connected" -> "设备开始充电"
                    "power_disconnected" -> "设备停止充电"
                    else -> eventType
                },
                metadata = mapOf(
                    "interactive" to power.isInteractive,
                    "device_locked" to keyguard.isDeviceLocked,
                ),
            )

            when (action) {
                Intent.ACTION_SCREEN_OFF -> {
                    pendingShowAfterUnlock = false
                    collapseChatOverlay("screen_off")
                    bubbleRoot?.visibility = View.GONE
                }
                Intent.ACTION_SCREEN_ON -> {
                    if (keyguard.isDeviceLocked) bubbleRoot?.visibility = View.GONE
                }
                Intent.ACTION_USER_PRESENT -> {
                    if (pendingShowAfterUnlock) {
                        pendingShowAfterUnlock = false
                        showChatOverlay("unlock_pending")
                    } else if (!chatExpanded) {
                        bubbleRoot?.visibility = View.VISIBLE
                        CompanionRuntimeState.setOverlayVisible(true)
                        updateOverlayTouchHealth()
                    }
                    requestSignalBrainWake(this@OverlayBubbleService, "device_present")
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        if (!CompanionRuntimeState.isOverlayUserEnabled(this) || !Settings.canDrawOverlays(this)) {
            destroyReason = "startup_precondition_failed"
            stopSelf()
            return
        }

        val notification = CompanionNotification.buildOverlayForeground(this)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                CompanionNotification.OVERLAY_FOREGROUND_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(CompanionNotification.OVERLAY_FOREGROUND_ID, notification)
        }
        running = true
        CompanionRuntimeState.markServiceStarted(this, "service_created")

        windowManager = getSystemService(WindowManager::class.java)
        if (!createBubble()) {
            destroyReason = "overlay_window_create_failed"
            stopSelf()
            return
        }
        registerDeviceStateReceiver()
        startBackgroundBrain()
        mainHandler.postDelayed(permissionWatch, PERMISSION_WATCH_MS)

        val power = getSystemService(PowerManager::class.java)
        val keyguard = getSystemService(KeyguardManager::class.java)
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "companion_service_started",
            appPackage = packageName,
            summary = "常驻陪伴服务已启动。",
            metadata = mapOf(
                "interactive" to power.isInteractive,
                "device_locked" to keyguard.isDeviceLocked,
            ),
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!CompanionRuntimeState.isOverlayUserEnabled(this) || !Settings.canDrawOverlays(this)) {
            destroyReason = "start_command_precondition_failed"
            stopSelf(startId)
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_SET_UNREAD -> {
                setUnread(intent.getIntExtra(EXTRA_COUNT, 0))
                return START_STICKY
            }
            ACTION_INCREMENT_UNREAD -> {
                setUnread(readUnread() + 1)
                return START_STICKY
            }
            ACTION_CLEAR_UNREAD -> {
                setUnread(0)
                return START_STICKY
            }
            ACTION_SHOW_CHAT -> {
                showChatOverlay(intent.getStringExtra(EXTRA_REASON) ?: "service_action")
                return START_STICKY
            }
            ACTION_COLLAPSE_CHAT -> {
                collapseChatOverlay(intent.getStringExtra(EXTRA_REASON) ?: "service_action")
                return START_STICKY
            }
            ACTION_NOTIFICATION_REPLY -> {
                val text = intent.getStringExtra(EXTRA_REPLY_TEXT)?.trim().orEmpty()
                val replyId = intent.getStringExtra(EXTRA_REPLY_ID)?.trim().orEmpty()
                val sourceMessageId = intent.getStringExtra(EXTRA_REPLY_TO_MESSAGE_ID)?.trim().orEmpty()
                if (text.isNotEmpty() && replyId.isNotEmpty() &&
                    pendingInlineReplies.none { it.replyId == replyId }) {
                    pendingInlineReplies.add(
                        PendingInlineReply(
                            replyId = replyId,
                            text = text.take(6000),
                            sourceMessageId = sourceMessageId,
                        ),
                    )
                }
                setUnread(0)
                pendingBrainWakeReason = "notification_inline_reply"
                brainWakeAttempt = 0
                if (backgroundEngine == null) startBackgroundBrain()
                flushInlineReplies()
                signalBackgroundBrainWake()
                return START_REDELIVER_INTENT
            }
            ACTION_RECONCILE -> {
                val reconcileReason = intent.getStringExtra(EXTRA_REASON) ?: "service_reconcile"
                if (reconcileReason.startsWith("system_cover:")) {
                    scheduleInputChannelRecovery(
                        reason = reconcileReason,
                        delayMs = SYSTEM_COVER_RECOVERY_DELAY_MS,
                    )
                } else {
                    // A visible Activity is not proof that the overlay input channel
                    // is stale. v0.30.2 rebuilt on every resume and created a
                    // self-heal loop on HyperOS. Rebuild only when a prior cover
                    // transition explicitly marked the channel suspect.
                    ensureOverlayHealth(
                        "reconcile:$reconcileReason",
                        rebuildInputChannel = CompanionRuntimeState.consumeOverlayInputSuspect(),
                    )
                }
                return START_STICKY
            }
            ACTION_WAKE_BRAIN -> {
                val wakeReason = intent.getStringExtra(EXTRA_REASON) ?: "native_wake"
                pendingBrainWakeReason = wakeReason.take(120)
                // A previous wake may have exhausted its short delivery retry
                // window while the FlutterEngine itself was still starting. A
                // fresh native wake is new evidence, so give it a fresh budget.
                brainWakeAttempt = 0
                if (backgroundEngine == null) startBackgroundBrain()
                signalBackgroundBrainWake()
                return START_STICKY
            }
        }
        val reason = intent?.getStringExtra(EXTRA_REASON)
            ?: intent?.action
            ?: if (flags and START_FLAG_RETRY != 0) "system_retry" else "sticky_restart"
        CompanionRuntimeState.markServiceStarted(this, reason)
        return START_STICKY
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW) {
            backgroundEngine?.let { engine ->
                runCatching { engine.systemChannel.sendMemoryPressureWarning() }
                runCatching { engine.dartExecutor.notifyLowMemoryWarning() }
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        bubbleRoot?.let { view ->
            clampBubbleToSafeArea()
            persistBubblePosition()
            updateBubbleLayout(view)
        }
        if (chatExpanded) updateChatLayoutForScreen()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "app_task_removed",
            appPackage = packageName,
            summary = "完整 App 已从最近任务中移除，常驻陪伴保持开启。",
        )
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(permissionWatch)
        unregisterDeviceStateReceiver()
        running = false
        pendingShowAfterUnlock = false
        pendingBrainWakeReason = null
        brainWakeAttempt = 0
        backgroundEngineStarting = false
        backgroundEngineRestartScheduled = false
        inputRecoveryScheduled = false
        inputRecoveryInProgress = false
        CompanionRuntimeState.setOverlayRecoveryInProgress(false)
        CompanionRuntimeState.setOverlayVisible(false)
        CompanionRuntimeState.setOverlayChatExpanded(false)
        CompanionRuntimeState.setOverlayTouchHealth(
            bubbleAttached = false,
            bubbleTouchable = false,
            positionSafe = false,
            chatWindowAttached = false,
        )
        hideKeyboard()
        removeChatWindow()
        bubbleRoot?.let { runCatching { windowManager.removeView(it) } }
        bubbleRoot = null
        backgroundCommands?.setMethodCallHandler(null)
        backgroundCommands = null
        backgroundTtsBridge?.dispose()
        backgroundTtsBridge = null
        backgroundSystemBridge?.dispose()
        backgroundSystemBridge = null
        backgroundEngine?.destroy()
        backgroundEngine = null
        backgroundBrainReady = false
        CompanionRuntimeState.markServiceStopped(this, destroyReason)
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "companion_service_stopped",
            appPackage = packageName,
            summary = "常驻陪伴服务已停止：$destroyReason",
        )
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createBubble(): Boolean {
        val size = dp(BUBBLE_AVATAR_DP)
        val container = OverlayBubbleRoot(this).apply {
            clipChildren = false
            clipToPadding = false
        }
        val avatar = TextView(this).apply {
            text = "她"
            textSize = 17f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = rounded(Color.rgb(176, 130, 255), 999f)
            elevation = dp(6).toFloat()
        }
        container.addView(
            avatar,
            FrameLayout.LayoutParams(size, size).apply { gravity = Gravity.CENTER },
        )
        badge = TextView(this).apply {
            textSize = 10f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = rounded(Color.rgb(229, 69, 96), 999f)
            elevation = dp(12).toFloat()
            translationZ = dp(12).toFloat()
            visibility = View.GONE
        }
        container.addView(
            badge,
            FrameLayout.LayoutParams(dp(BUBBLE_BADGE_DP), dp(BUBBLE_BADGE_DP)).apply {
                gravity = Gravity.TOP or Gravity.END
            },
        )
        badge?.bringToFront()

        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val safeArea = bubbleSafeArea()
        val defaultX = (safeArea.right - dp(BUBBLE_WINDOW_DP)).coerceAtLeast(safeArea.left)
        val defaultY = (safeArea.top + (safeArea.height / 3)).coerceAtMost(
            (safeArea.bottom - dp(BUBBLE_WINDOW_DP)).coerceAtLeast(safeArea.top),
        )
        bubbleParams = WindowManager.LayoutParams(
            dp(BUBBLE_WINDOW_DP),
            dp(BUBBLE_WINDOW_DP),
            overlayWindowType(),
            bubbleModeFlags(),
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt(KEY_X, defaultX)
            y = prefs.getInt(KEY_Y, defaultY)
        }
        attachDrag(container)
        if (clampBubbleToSafeArea()) persistBubblePosition()
        return runCatching {
            bubbleRoot = container
            windowManager.addView(container, bubbleParams)
            val keyguard = getSystemService(KeyguardManager::class.java)
            container.visibility = if (keyguard.isDeviceLocked) View.GONE else View.VISIBLE
            CompanionRuntimeState.setOverlayVisible(container.visibility == View.VISIBLE)
            setUnread(readUnread())
            updateOverlayTouchHealth()
            true
        }.getOrElse { error ->
            bubbleRoot = null
            CompanionRuntimeState.setOverlayVisible(false)
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "overlay_window_create_failed",
                appPackage = packageName,
                summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
            )
            false
        }
    }

    private fun createChatWindow(): Boolean {
        if (chatRoot != null) return true
        val root = FrameLayout(this).apply {
            background = rounded(Color.rgb(31, 30, 36), 22f)
            elevation = dp(16).toFloat()
            setPadding(dp(8), dp(8), dp(8), dp(8))
            setOnTouchListener { _, event ->
                if (event.actionMasked == MotionEvent.ACTION_OUTSIDE && chatInputMode) {
                    hideKeyboard()
                    exitChatInputMode()
                }
                false
            }
        }
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        root.addView(
            column,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        column.addView(buildChatTopBar())

        chatLoadOlder = Button(this).apply {
            text = "更早的消息"
            textSize = 12f
            minHeight = 0
            setOnClickListener { loadOlderMessages() }
        }
        column.addView(
            chatLoadOlder,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(38)),
        )

        val adapter = NativeChatAdapter()
        chatAdapter = adapter
        chatList = ListView(this).apply {
            dividerHeight = dp(4)
            this.adapter = adapter
            transcriptMode = ListView.TRANSCRIPT_MODE_NORMAL
        }
        column.addView(
            chatList,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f),
        )

        chatStatus = TextView(this).apply {
            setTextColor(Color.rgb(192, 180, 212))
            textSize = 12f
            gravity = Gravity.CENTER_VERTICAL
            visibility = View.GONE
            setPadding(dp(8), dp(2), dp(8), dp(2))
        }
        column.addView(
            chatStatus,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(26)),
        )

        column.addView(buildComposer())

        val (screenWidth, screenHeight) = screenBounds()
        chatParams = WindowManager.LayoutParams(
            overlayChatWidth(screenWidth),
            overlayChatHeight(screenHeight),
            overlayWindowType(),
            readModeFlags(),
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            x = 0
            y = dp(12)
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
                WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN
        }

        return runCatching {
            chatRoot = root
            windowManager.addView(root, chatParams)
            root.visibility = View.GONE
            true
        }.getOrElse { error ->
            chatRoot = null
            chatParams = null
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "overlay_chat_window_create_failed",
                appPackage = packageName,
                summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
            )
            false
        }
    }

    private fun buildChatTopBar(): View {
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), 0, dp(2), 0)
        }
        bar.addView(
            TextView(this).apply {
                text = "她"
                textSize = 16f
                setTextColor(Color.WHITE)
            },
            LinearLayout.LayoutParams(0, dp(46), 1f).apply { gravity = Gravity.CENTER_VERTICAL },
        )
        bar.addView(smallButton("■") { stopSpeech() })
        bar.addView(smallButton("打开") { openFullApp() })
        bar.addView(smallButton("×") { collapseChatOverlay("user_close") })
        return bar
    }

    private fun buildComposer(): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.BOTTOM
            setPadding(dp(2), dp(4), dp(2), dp(2))
        }
        chatInput = OverlayEditText(this).apply {
            hint = "和她说点什么…"
            setHintTextColor(Color.rgb(150, 145, 160))
            setTextColor(Color.WHITE)
            textSize = 15f
            minLines = 1
            maxLines = 4
            inputType = InputType.TYPE_CLASS_TEXT or
                InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            background = rounded(Color.rgb(47, 45, 53), 14f)
            setPadding(dp(12), dp(8), dp(12), dp(8))
            setOnTouchListener { _, event ->
                if (event.actionMasked == MotionEvent.ACTION_DOWN && !chatInputMode) {
                    enterChatInputMode()
                }
                false
            }
            onImeBack = { mainHandler.postDelayed({ exitChatInputMode() }, 80L) }
        }
        row.addView(
            chatInput,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        chatSend = Button(this).apply {
            text = "发送"
            setOnClickListener { sendFromOverlay() }
        }
        row.addView(
            chatSend,
            LinearLayout.LayoutParams(dp(74), ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                marginStart = dp(6)
            },
        )
        return row
    }

    private fun smallButton(label: String, onClick: () -> Unit): Button = Button(this).apply {
        text = label
        textSize = 12f
        minWidth = 0
        minHeight = 0
        setPadding(dp(8), 0, dp(8), 0)
        setOnClickListener { onClick() }
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(40))
    }

    private fun showChatOverlay(reason: String) {
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (keyguard.isDeviceLocked) {
            pendingShowAfterUnlock = true
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "overlay_chat_deferred_until_unlock",
                appPackage = packageName,
                summary = "悬浮聊天请求已收到，设备解锁后显示。",
            )
            return
        }
        if (!createChatWindow()) return
        pendingShowAfterUnlock = false
        setUnread(0)
        bubbleRoot?.visibility = View.GONE
        chatRoot?.visibility = View.VISIBLE
        chatExpanded = true
        CompanionRuntimeState.setOverlayChatExpanded(true)
        chatInputMode = false
        chatParams?.let { params ->
            params.flags = readModeFlags()
            runCatching { windowManager.updateViewLayout(chatRoot, params) }
        }
        CompanionRuntimeState.setOverlayVisible(true)
        updateOverlayTouchHealth()
        refreshOverlayMessages(opened = true, attempt = 0)
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "overlay_chat_opened",
            appPackage = packageName,
            summary = "真悬浮聊天已展开：$reason",
        )
    }

    private fun collapseChatOverlay(reason: String) {
        if (!chatExpanded && chatRoot == null) {
            ensureOverlayHealth("collapse_no_chat:$reason")
            return
        }
        hideKeyboard()
        exitChatInputMode(updateWindow = false)
        removeChatWindow()
        val keyguard = getSystemService(KeyguardManager::class.java)
        bubbleRoot?.visibility = if (keyguard.isDeviceLocked) View.GONE else View.VISIBLE
        CompanionRuntimeState.setOverlayVisible(bubbleRoot?.visibility == View.VISIBLE)
        ensureOverlayHealth("collapse:$reason")
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "overlay_chat_collapsed",
            appPackage = packageName,
            summary = "真悬浮聊天已收起：$reason",
        )
    }

    private fun enterChatInputMode() {
        if (!chatExpanded || chatInputMode) return
        val root = chatRoot ?: return
        val params = chatParams ?: return
        chatInputMode = true
        params.flags = inputModeFlags()
        runCatching { windowManager.updateViewLayout(root, params) }
        chatInput?.post {
            chatInput?.requestFocus()
            val imm = getSystemService(InputMethodManager::class.java)
            imm.showSoftInput(chatInput, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    private fun exitChatInputMode(updateWindow: Boolean = true) {
        if (!chatInputMode && updateWindow) return
        chatInputMode = false
        chatInput?.clearFocus()
        if (updateWindow) {
            val root = chatRoot ?: return
            val params = chatParams ?: return
            params.flags = readModeFlags()
            runCatching { windowManager.updateViewLayout(root, params) }
        }
    }

    private fun hideKeyboard() {
        val input = chatInput ?: return
        runCatching {
            getSystemService(InputMethodManager::class.java)
                .hideSoftInputFromWindow(input.windowToken, 0)
        }
    }

    private fun refreshOverlayMessages(opened: Boolean, attempt: Int) {
        val channel = backgroundCommands
        if (channel == null) {
            retryRefresh(opened, attempt)
            return
        }
        channel.invokeMethod(
            if (opened) "overlayOpened" else "loadRecentMessages",
            if (opened) null else mapOf("limit" to OVERLAY_RECENT_LIMIT),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    mainHandler.post {
                        val parsed = parseMessageList(result)
                        if (parsed != null) {
                            loadedMessages = parsed.toMutableList()
                            chatAdapter?.notifyDataSetChanged()
                            chatLoadOlder?.visibility = if (parsed.size >= OVERLAY_RECENT_LIMIT) View.VISIBLE else View.GONE
                            scrollChatToBottom()
                            setChatStatus(null)
                        } else {
                            retryRefresh(opened, attempt)
                        }
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post {
                        if (attempt < 8) retryRefresh(opened, attempt)
                        else setChatStatus("暂时没能读到聊天记录。", true)
                    }
                }

                override fun notImplemented() {
                    mainHandler.post { retryRefresh(opened, attempt) }
                }
            },
        )
    }

    private fun retryRefresh(opened: Boolean, attempt: Int) {
        if (!chatExpanded || attempt >= 8) return
        mainHandler.postDelayed(
            { if (chatExpanded) refreshOverlayMessages(opened, attempt + 1) },
            180L + attempt * 120L,
        )
    }

    private fun loadOlderMessages() {
        if (loadedMessages.isEmpty()) return
        val oldest = loadedMessages.first().createdAt
        chatLoadOlder?.isEnabled = false
        backgroundCommands?.invokeMethod(
            "loadOlderMessages",
            mapOf("beforeMs" to oldest, "limit" to OVERLAY_OLDER_PAGE_LIMIT),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    mainHandler.post {
                        val older = parseMessageList(result).orEmpty()
                        if (older.isNotEmpty()) {
                            val seen = loadedMessages.mapTo(mutableSetOf()) { it.id }
                            loadedMessages.addAll(0, older.filter { seen.add(it.id) })
                            chatAdapter?.notifyDataSetChanged()
                            chatList?.setSelection(older.size.coerceAtMost(loadedMessages.lastIndex))
                        }
                        chatLoadOlder?.visibility = if (older.size >= OVERLAY_OLDER_PAGE_LIMIT) View.VISIBLE else View.GONE
                        chatLoadOlder?.isEnabled = true
                    }
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post {
                        chatLoadOlder?.isEnabled = true
                        setChatStatus("加载更早消息失败。", true)
                    }
                }
                override fun notImplemented() {
                    mainHandler.post { chatLoadOlder?.isEnabled = true }
                }
            },
        ) ?: run { chatLoadOlder?.isEnabled = true }
    }

    private fun sendFromOverlay() {
        if (chatSending) return
        val text = chatInput?.text?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return
        if (!backgroundBrainReady) {
            pendingBrainWakeReason = "overlay_connect"
            brainWakeAttempt = 0
            if (backgroundEngine == null) startBackgroundBrain()
            signalBackgroundBrainWake()
            setChatStatus("正在连接后台大脑…")
            return
        }
        val channel = backgroundCommands ?: run {
            setChatStatus("正在连接后台大脑…")
            return
        }
        chatSending = true
        chatSend?.isEnabled = false
        chatInput?.setText("")
        val optimistic = NativeChatMessage(
            id = "local:${System.currentTimeMillis()}",
            role = "user",
            content = text,
            reasoning = "",
            createdAt = System.currentTimeMillis(),
            proactive = false,
            proactiveIntent = "",
            proactiveDelivery = "",
        )
        loadedMessages.add(optimistic)
        chatAdapter?.notifyDataSetChanged()
        scrollChatToBottom()
        setChatStatus("她正在想…")

        channel.invokeMethod(
            "sendMessage",
            mapOf("text" to text),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    mainHandler.post {
                        chatSending = false
                        chatSend?.isEnabled = true
                        val map = result as? Map<*, *>
                        val messages = parseMessageList(map?.get("messages"))
                        if (messages != null) {
                            loadedMessages = messages.toMutableList()
                            chatAdapter?.notifyDataSetChanged()
                            scrollChatToBottom()
                        } else {
                            refreshOverlayMessages(opened = false, attempt = 0)
                        }
                        val ok = map?.get("ok") == true
                        val error = map?.get("error") as? String ?: ""
                        setChatStatus(if (ok) null else error.ifBlank { "发送失败。" }, !ok)
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post {
                        chatSending = false
                        chatSend?.isEnabled = true
                        setChatStatus("发送失败：${errorMessage ?: errorCode}", true)
                        refreshOverlayMessages(opened = false, attempt = 0)
                    }
                }

                override fun notImplemented() {
                    mainHandler.post {
                        chatSending = false
                        chatSend?.isEnabled = true
                        setChatStatus("她还在重新连接，请稍后再试。", true)
                        refreshOverlayMessages(opened = false, attempt = 0)
                    }
                }
            },
        )
    }

    private fun speakMessage(messageId: String) {
        backgroundCommands?.invokeMethod("speakMessage", mapOf("messageId" to messageId))
    }

    private fun stopSpeech() {
        backgroundCommands?.invokeMethod("stopSpeech", null)
    }

    private fun openFullApp() {
        // Do not collapse/rebuild WindowManager immediately before launching the
        // Activity. v0.30.2 could race the overlay self-heal with startActivity(),
        // making the visible “打开” tap appear to do nothing on HyperOS.
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        }
        runCatching { startActivity(launchIntent) }
            .onSuccess {
                NativeEventStore.addDeviceEvent(
                    this,
                    source = "system",
                    eventType = "overlay_open_full_app_requested",
                    appPackage = packageName,
                    summary = "用户从悬浮聊天请求打开完整 App。",
                )
                // MainActivity.onResume() owns the actual collapse. If Android
                // rejects/delays the Activity launch, leave the chat usable so the
                // user can retry instead of destroying the only working surface.
            }
            .onFailure { error ->
                setChatStatus("打开 App 失败：${error.message ?: error.javaClass.simpleName}", true)
                NativeEventStore.addDeviceEvent(
                    this,
                    source = "system",
                    eventType = "overlay_open_full_app_failed",
                    appPackage = packageName,
                    summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
                )
            }
    }

    private fun setChatStatus(text: String?, error: Boolean = false) {
        chatStatus?.apply {
            if (text.isNullOrBlank()) {
                visibility = View.GONE
                this.text = ""
            } else {
                visibility = View.VISIBLE
                this.text = text
                setTextColor(if (error) Color.rgb(255, 135, 145) else Color.rgb(192, 180, 212))
            }
        }
    }

    private fun scrollChatToBottom() {
        val count = loadedMessages.size
        if (count > 0) chatList?.post { chatList?.setSelection(count - 1) }
    }

    private fun parseMessageList(raw: Any?): List<NativeChatMessage>? {
        val list = raw as? List<*> ?: return null
        return list.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val id = map["id"] as? String ?: return@mapNotNull null
            val role = map["role"] as? String ?: return@mapNotNull null
            NativeChatMessage(
                id = id,
                role = role,
                content = map["content"] as? String ?: "",
                reasoning = map["reasoning_content"] as? String ?: "",
                createdAt = (map["created_at"] as? Number)?.toLong() ?: 0L,
                proactive = when (val value = map["is_proactive"]) {
                    is Boolean -> value
                    is Number -> value.toInt() == 1
                    else -> false
                },
                proactiveIntent = map["proactive_intent"] as? String ?: "",
                proactiveDelivery = map["proactive_delivery"] as? String ?: "",
            )
        }
    }

    private fun attachDrag(view: View) {
        var startX = 0
        var startY = 0
        var downX = 0f
        var downY = 0f
        var moved = false
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    CompanionRuntimeState.noteOverlayTouch("down")
                    startX = bubbleParams.x
                    startY = bubbleParams.y
                    downX = event.rawX
                    downY = event.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    CompanionRuntimeState.noteOverlayTouch("move")
                    val dx = (event.rawX - downX).toInt()
                    val dy = (event.rawY - downY).toInt()
                    if (abs(dx) > dp(4) || abs(dy) > dp(4)) moved = true
                    bubbleParams.x = startX + dx
                    bubbleParams.y = startY + dy
                    updateBubbleLayout(view)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    CompanionRuntimeState.noteOverlayTouch("up")
                    if (!moved) {
                        showChatOverlay("bubble_tap")
                    } else {
                        snapBubbleToSafeEdge()
                        persistBubblePosition()
                        updateBubbleLayout(view)
                    }
                    moved = false
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    CompanionRuntimeState.noteOverlayTouch("cancel")
                    moved = false
                    clampBubbleToSafeArea()
                    persistBubblePosition()
                    updateBubbleLayout(view)
                    true
                }
                else -> false
            }
        }
    }

    private fun persistBubblePosition() {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt(KEY_X, bubbleParams.x)
            .putInt(KEY_Y, bubbleParams.y)
            .apply()
    }

    private data class BubbleSafeArea(
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int,
    ) {
        val width: Int get() = (right - left).coerceAtLeast(0)
        val height: Int get() = (bottom - top).coerceAtLeast(0)
    }

    private fun bubbleSafeArea(): BubbleSafeArea {
        val margin = dp(BUBBLE_SAFE_MARGIN_DP)
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windowManager.currentWindowMetrics
            val bounds = metrics.bounds
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            val left = bounds.left + insets.left + margin
            val top = bounds.top + insets.top + margin
            val right = (bounds.right - insets.right - margin).coerceAtLeast(left)
            val bottom = (bounds.bottom - insets.bottom - margin).coerceAtLeast(top)
            return BubbleSafeArea(left, top, right, bottom)
        }
        @Suppress("DEPRECATION")
        val width = resources.displayMetrics.widthPixels
        @Suppress("DEPRECATION")
        val height = resources.displayMetrics.heightPixels
        return BubbleSafeArea(margin, margin, (width - margin).coerceAtLeast(margin), (height - margin).coerceAtLeast(margin))
    }

    private fun clampBubbleToSafeArea(): Boolean {
        val safe = bubbleSafeArea()
        val size = dp(BUBBLE_WINDOW_DP)
        val maxX = (safe.right - size).coerceAtLeast(safe.left)
        val maxY = (safe.bottom - size).coerceAtLeast(safe.top)
        val oldX = bubbleParams.x
        val oldY = bubbleParams.y
        bubbleParams.x = bubbleParams.x.coerceIn(safe.left, maxX)
        bubbleParams.y = bubbleParams.y.coerceIn(safe.top, maxY)
        return oldX != bubbleParams.x || oldY != bubbleParams.y
    }

    private fun isBubblePositionSafe(): Boolean {
        if (!::bubbleParams.isInitialized) return false
        val safe = bubbleSafeArea()
        val size = dp(BUBBLE_WINDOW_DP)
        val maxX = (safe.right - size).coerceAtLeast(safe.left)
        val maxY = (safe.bottom - size).coerceAtLeast(safe.top)
        return bubbleParams.x in safe.left..maxX && bubbleParams.y in safe.top..maxY
    }

    private fun snapBubbleToSafeEdge() {
        val safe = bubbleSafeArea()
        val size = dp(BUBBLE_WINDOW_DP)
        val maxX = (safe.right - size).coerceAtLeast(safe.left)
        val midpoint = safe.left + safe.width / 2
        bubbleParams.x = if (bubbleParams.x + size / 2 < midpoint) safe.left else maxX
        clampBubbleToSafeArea()
    }

    private fun bubbleModeFlags(): Int =
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

    private fun scheduleInputChannelRecovery(
        reason: String,
        delayMs: Long = SYSTEM_COVER_RECOVERY_DELAY_MS,
    ) {
        if (inputRecoveryScheduled || inputRecoveryInProgress) return
        val now = System.currentTimeMillis()
        val cooldownRemaining = if (lastInputRecoveryAt <= 0L) {
            0L
        } else {
            (INPUT_RECOVERY_MIN_GAP_MS - (now - lastInputRecoveryAt)).coerceAtLeast(0L)
        }
        // Coalesce a cover that occurs during cooldown instead of dropping it.
        // This preserves recovery after a genuine second file-picker round-trip
        // without allowing rapid rebuild loops.
        val effectiveDelay = maxOf(delayMs, cooldownRemaining)
        inputRecoveryScheduled = true
        mainHandler.postDelayed({
            inputRecoveryScheduled = false
            if (!running || chatExpanded || !Settings.canDrawOverlays(this)) return@postDelayed
            if (CompanionRuntimeState.isAppVisible()) {
                // MainActivity owns its own reconcile path; never let a stale
                // system-cover callback rebuild the bubble over the full app.
                return@postDelayed
            }
            lastInputRecoveryAt = System.currentTimeMillis()
            inputRecoveryInProgress = true
            CompanionRuntimeState.setOverlayRecoveryInProgress(true)
            try {
                ensureOverlayHealth(
                    "cover_recovery:${reason.take(100)}",
                    rebuildInputChannel = true,
                )
                CompanionRuntimeState.noteOverlayCoverRecovered(reason)
            } finally {
                // removeView/addView emits visibility callbacks on some OEMs.
                // Keep the re-entrancy guard alive briefly so our own rebuild
                // cannot schedule another rebuild.
                mainHandler.postDelayed({
                    inputRecoveryInProgress = false
                    CompanionRuntimeState.setOverlayRecoveryInProgress(false)
                }, INPUT_RECOVERY_SETTLE_MS)
            }
        }, effectiveDelay)
    }

    private fun updateOverlayTouchHealth() {
        val bubble = bubbleRoot
        val paramsTouchable = ::bubbleParams.isInitialized &&
            bubbleParams.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE == 0
        CompanionRuntimeState.setOverlayTouchHealth(
            bubbleAttached = bubble?.isAttachedToWindow == true,
            bubbleTouchable = bubble?.isAttachedToWindow == true && paramsTouchable && bubble.isEnabled,
            positionSafe = isBubblePositionSafe(),
            chatWindowAttached = chatRoot?.isAttachedToWindow == true,
        )
    }

    private fun ensureOverlayHealth(reason: String, rebuildInputChannel: Boolean = false) {
        if (!running || !Settings.canDrawOverlays(this)) return
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (chatExpanded) {
            updateOverlayTouchHealth()
            return
        }

        // A hidden TYPE_APPLICATION_OVERLAY chat window is unnecessary and on
        // some OEM builds can leave a stale input region. Remove it completely
        // whenever the UI is collapsed.
        if (chatRoot != null) removeChatWindow()

        var repaired = false
        var bubble = bubbleRoot
        if (bubble == null || !bubble.isAttachedToWindow || rebuildInputChannel) {
            bubble?.let { runCatching { windowManager.removeViewImmediate(it) } }
            bubbleRoot = null
            repaired = createBubble()
            bubble = bubbleRoot
        } else {
            val attachedBubble = requireNotNull(bubble)
            val expectedFlags = bubbleModeFlags()
            if (bubbleParams.flags != expectedFlags) {
                bubbleParams.flags = expectedFlags
                repaired = true
            }
            if (clampBubbleToSafeArea()) {
                persistBubblePosition()
                repaired = true
            }
            attachedBubble.isEnabled = true
            attachedBubble.visibility = if (keyguard.isDeviceLocked) View.GONE else View.VISIBLE
            CompanionRuntimeState.setOverlayVisible(attachedBubble.visibility == View.VISIBLE)
            runCatching { windowManager.updateViewLayout(attachedBubble, bubbleParams) }
                .onFailure { repaired = true }
        }

        if (repaired) {
            CompanionRuntimeState.noteOverlaySelfHeal(reason)
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "overlay_touch_self_healed",
                appPackage = packageName,
                summary = "悬浮球输入通道/位置已自动恢复：${reason.take(120)}",
            )
        }
        updateOverlayTouchHealth()
    }

    private fun updateBubbleLayout(view: View) {
        val changed = clampBubbleToSafeArea()
        if (changed) persistBubblePosition()
        runCatching { windowManager.updateViewLayout(view, bubbleParams) }
            .onSuccess { updateOverlayTouchHealth() }
            .onFailure { error ->
                updateOverlayTouchHealth()
                NativeEventStore.addDeviceEvent(
                    this,
                    source = "system",
                    eventType = "overlay_window_update_failed",
                    appPackage = packageName,
                    summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
                )
                if (!Settings.canDrawOverlays(this)) {
                    destroyReason = "overlay_permission_lost"
                    stopSelf()
                } else {
                    mainHandler.postDelayed(
                        { ensureOverlayHealth("update_failed", rebuildInputChannel = true) },
                        250L,
                    )
                }
            }
    }

    private fun updateChatLayoutForScreen() {
        val root = chatRoot ?: return
        val params = chatParams ?: return
        val (width, height) = screenBounds()
        params.width = overlayChatWidth(width)
        params.height = overlayChatHeight(height)
        runCatching { windowManager.updateViewLayout(root, params) }
    }

    private fun startBackgroundBrain() {
        if (backgroundEngine != null || backgroundEngineStarting) return
        backgroundEngineStarting = true
        var engine: FlutterEngine? = null
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val createdEngine = FlutterEngine(applicationContext)
            engine = createdEngine
            backgroundSystemBridge = BackgroundSystemBridge(applicationContext, createdEngine)
            backgroundTtsBridge = NativeTtsBridge(applicationContext, createdEngine)
            val commandChannel = MethodChannel(
                createdEngine.dartExecutor.binaryMessenger,
                BACKGROUND_COMMAND_CHANNEL,
            )
            backgroundCommands = commandChannel
            // "Engine object exists" is not the same as "Dart recovery loop is
            // alive". Wait for an explicit Dart-side handshake before exposing
            // backgroundBrainReady to diagnostics or consuming pending wakes.
            commandChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "backgroundDartReady" -> {
                        if (backgroundEngine === createdEngine && running) {
                            backgroundBrainReady = true
                            backgroundEngineStartAttempts = 0
                            backgroundEngineRestartScheduled = false
                            brainWakeAttempt = 0
                            result.success(true)
                            if (pendingBrainWakeReason != null) {
                                mainHandler.postDelayed({ signalBackgroundBrainWake() }, 250L)
                            }
                            if (pendingInlineReplies.isNotEmpty()) {
                                mainHandler.postDelayed({ flushInlineReplies() }, 300L)
                            }
                            if (chatExpanded) {
                                mainHandler.post { refreshOverlayMessages(opened = true, attempt = 0) }
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
            val entrypoint = DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "companionBackgroundMain",
            )
            // Publish the engine identity before Dart starts. The Dart entrypoint
            // installs its command handler immediately and can handshake back on
            // the same main-loop turn; assigning afterwards creates a real race
            // where a healthy isolate is rejected as "not our engine".
            backgroundEngine = createdEngine
            backgroundBrainReady = false
            createdEngine.dartExecutor.executeDartEntrypoint(entrypoint)
            // If Dart never reaches its MethodChannel handshake (for example a
            // startup exception before companionBackgroundMain finishes
            // installing handlers), do not leave a dead Engine looking healthy
            // forever. Recreate it with a bounded retry budget.
            mainHandler.postDelayed({
                restartBackgroundEngineIfUnready(createdEngine)
            }, BACKGROUND_READY_TIMEOUT_MS)
        } catch (error: Throwable) {
            backgroundCommands?.setMethodCallHandler(null)
            backgroundCommands = null
            backgroundTtsBridge?.dispose()
            backgroundTtsBridge = null
            backgroundSystemBridge?.dispose()
            backgroundSystemBridge = null
            runCatching { engine?.destroy() }
            backgroundEngine = null
            backgroundBrainReady = false
            backgroundEngineStartAttempts += 1
            NativeEventStore.addDeviceEvent(
                context = this,
                source = "system",
                eventType = "background_brain_start_failed",
                appPackage = packageName,
                summary = error.javaClass.simpleName + ": " + (error.message ?: "unknown"),
                metadata = mapOf("attempt" to backgroundEngineStartAttempts),
            )
            scheduleBackgroundEngineRestart()
        } finally {
            backgroundEngineStarting = false
        }
    }

    private fun restartBackgroundEngineIfUnready(expectedEngine: FlutterEngine) {
        if (!running || backgroundEngine !== expectedEngine || backgroundBrainReady) return
        NativeEventStore.addDeviceEvent(
            context = this,
            source = "system",
            eventType = "background_brain_ready_timeout",
            appPackage = packageName,
            summary = "后台 FlutterEngine 已创建，但 Dart 恢复循环未在时限内就绪，准备重建。",
        )
        backgroundCommands?.setMethodCallHandler(null)
        backgroundCommands = null
        backgroundTtsBridge?.dispose()
        backgroundTtsBridge = null
        backgroundSystemBridge?.dispose()
        backgroundSystemBridge = null
        runCatching { expectedEngine.destroy() }
        backgroundEngine = null
        backgroundBrainReady = false
        backgroundEngineStartAttempts += 1
        scheduleBackgroundEngineRestart()
    }

    private fun scheduleBackgroundEngineRestart() {
        if (!running || backgroundEngine != null || backgroundEngineRestartScheduled) return
        if (backgroundEngineStartAttempts >= 4) return
        backgroundEngineRestartScheduled = true
        val delay = when (backgroundEngineStartAttempts) {
            1 -> 5_000L
            2 -> 15_000L
            else -> 30_000L
        }
        mainHandler.postDelayed({
            backgroundEngineRestartScheduled = false
            if (!running) return@postDelayed
            if (!CompanionRuntimeState.isOverlayUserEnabled(this)) return@postDelayed
            if (!Settings.canDrawOverlays(this)) return@postDelayed
            startBackgroundBrain()
        }, delay)
    }

    private fun flushInlineReplies() {
        if (inlineReplyInFlight || !backgroundBrainReady) return
        val item = pendingInlineReplies.firstOrNull() ?: return
        val channel = backgroundCommands ?: return
        inlineReplyInFlight = true
        channel.invokeMethod(
            "notificationReply",
            mapOf(
                "text" to item.text,
                "replyId" to item.replyId,
                "sourceMessageId" to item.sourceMessageId,
            ),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    inlineReplyInFlight = false
                    val ok = (result as? Map<*, *>)?.get("ok") as? Boolean ?: true
                    if (ok) {
                        pendingInlineReplies.removeAll { it.replyId == item.replyId }
                        if (chatExpanded) refreshOverlayMessages(opened = false, attempt = 0)
                        flushInlineReplies()
                        return
                    }
                    val error = (result as? Map<*, *>)?.get("error") as? String ?: "unknown"
                    retryOrDropInlineReply(item, error)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    inlineReplyInFlight = false
                    retryOrDropInlineReply(item, "$errorCode: ${errorMessage ?: "unknown"}")
                }

                override fun notImplemented() {
                    inlineReplyInFlight = false
                    retryOrDropInlineReply(item, "background command not implemented")
                }
            },
        )
    }

    private fun retryOrDropInlineReply(item: PendingInlineReply, error: String) {
        val index = pendingInlineReplies.indexOfFirst { it.replyId == item.replyId }
        if (index < 0) return
        val nextAttempts = pendingInlineReplies[index].attempts + 1
        if (nextAttempts >= INLINE_REPLY_MAX_ATTEMPTS) {
            pendingInlineReplies.removeAt(index)
            NativeEventStore.addDeviceEvent(
                context = this,
                source = "system",
                eventType = "notification_inline_reply_delivery_failed",
                appPackage = packageName,
                summary = error.take(240),
                metadata = mapOf(
                    "reply_id" to item.replyId,
                    "source_message_id" to item.sourceMessageId,
                ),
            )
            return
        }
        pendingInlineReplies[index] = pendingInlineReplies[index].copy(attempts = nextAttempts)
        val delayMs = when (nextAttempts) {
            1 -> 5_000L
            2 -> 15_000L
            3 -> 30_000L
            else -> 60_000L
        }
        mainHandler.postDelayed({ flushInlineReplies() }, delayMs)
    }

    private fun signalBackgroundBrainWake() {
        val reason = pendingBrainWakeReason ?: return
        val channel = backgroundCommands
        if (channel == null) {
            scheduleBackgroundWakeRetry()
            return
        }
        channel.invokeMethod(
            "wakeBackground",
            mapOf("reason" to reason),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (pendingBrainWakeReason == reason) {
                        pendingBrainWakeReason = null
                        brainWakeAttempt = 0
                    }
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    scheduleBackgroundWakeRetry()
                }
                override fun notImplemented() {
                    scheduleBackgroundWakeRetry()
                }
            },
        )
    }

    private fun scheduleBackgroundWakeRetry() {
        if (!running || pendingBrainWakeReason == null) return
        if (brainWakeAttempt >= 4) {
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "background_brain_wake_deferred",
                appPackage = packageName,
                summary = "后台大脑唤醒信号暂未送达，保留给下一次服务事件处理。",
            )
            return
        }
        brainWakeAttempt += 1
        val delay = when (brainWakeAttempt) {
            1 -> 500L
            2 -> 1_200L
            3 -> 2_500L
            else -> 5_000L
        }
        mainHandler.postDelayed({ signalBackgroundBrainWake() }, delay)
    }

    private fun registerDeviceStateReceiver() {
        if (stateReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(deviceStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION") registerReceiver(deviceStateReceiver, filter)
        }
        stateReceiverRegistered = true
    }

    private fun unregisterDeviceStateReceiver() {
        if (!stateReceiverRegistered) return
        runCatching { unregisterReceiver(deviceStateReceiver) }
        stateReceiverRegistered = false
    }

    private fun removeChatWindow() {
        chatRoot?.let { runCatching { windowManager.removeViewImmediate(it) } }
        chatRoot = null
        chatList = null
        chatAdapter = null
        chatInput = null
        chatSend = null
        chatStatus = null
        chatLoadOlder = null
        chatParams = null
        chatExpanded = false
        CompanionRuntimeState.setOverlayChatExpanded(false)
        chatInputMode = false
        updateOverlayTouchHealth()
    }

    private fun setUnread(count: Int) {
        var safe = count.coerceAtLeast(0)
        if (chatExpanded && safe > 0) {
            safe = 0
            mainHandler.postDelayed(
                { if (chatExpanded) refreshOverlayMessages(opened = false, attempt = 0) },
                120L,
            )
        }
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putInt(KEY_UNREAD, safe).apply()
        badge?.apply {
            visibility = if (safe == 0) View.GONE else View.VISIBLE
            text = if (safe > 99) "99+" else safe.toString()
        }
    }

    private fun readUnread(): Int =
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY_UNREAD, 0)

    private fun overlayWindowType(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    } else {
        @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
    }

    private fun readModeFlags(): Int =
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

    private fun inputModeFlags(): Int =
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

    private fun screenBounds(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= 30) {
            val bounds = windowManager.currentWindowMetrics.bounds
            return bounds.width() to bounds.height()
        }
        @Suppress("DEPRECATION")
        return resources.displayMetrics.widthPixels to resources.displayMetrics.heightPixels
    }

    private fun overlayChatWidth(screenWidth: Int): Int {
        val max = (screenWidth - dp(8)).coerceAtLeast(dp(220)).coerceAtMost(dp(620))
        val min = dp(280).coerceAtMost(max)
        return (screenWidth * 0.94f).toInt().coerceIn(min, max)
    }

    private fun overlayChatHeight(screenHeight: Int): Int {
        val max = (screenHeight - dp(24)).coerceAtLeast(dp(300)).coerceAtMost(dp(760))
        val min = dp(360).coerceAtMost(max)
        return (screenHeight * 0.72f).toInt().coerceIn(min, max)
    }

    private fun rounded(color: Int, radiusDp: Float): GradientDrawable = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dpF(radiusDp)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun dpF(value: Float): Float = value * resources.displayMetrics.density

    private data class PendingInlineReply(
        val replyId: String,
        val text: String,
        val sourceMessageId: String,
        val attempts: Int = 0,
    )

    private data class NativeChatMessage(
        val id: String,
        val role: String,
        val content: String,
        val reasoning: String,
        val createdAt: Long,
        val proactive: Boolean,
        val proactiveIntent: String,
        val proactiveDelivery: String,
    )

    private inner class NativeChatAdapter : BaseAdapter() {
        private val expandedReasoning = mutableSetOf<String>()

        override fun getCount(): Int = loadedMessages.size
        override fun getItem(position: Int): Any = loadedMessages[position]
        override fun getItemId(position: Int): Long = loadedMessages[position].id.hashCode().toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val message = loadedMessages[position]
            val outer = LinearLayout(this@OverlayBubbleService).apply {
                orientation = LinearLayout.VERTICAL
                gravity = if (message.role == "user") Gravity.END else Gravity.START
                setPadding(dp(6), dp(3), dp(6), dp(3))
            }
            val bubble = LinearLayout(this@OverlayBubbleService).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(11), dp(8), dp(11), dp(8))
                background = rounded(
                    if (message.role == "user") Color.rgb(83, 62, 115) else Color.rgb(53, 51, 60),
                    14f,
                )
            }
            val label = if (message.role == "user") {
                "你"
            } else if (message.proactive) {
                "她 · ${proactiveIntentLabel(message.proactiveIntent)}"
            } else {
                "她"
            }
            bubble.addView(TextView(this@OverlayBubbleService).apply {
                text = label
                textSize = 11f
                setTextColor(Color.rgb(188, 169, 220))
            })
            if (message.role == "assistant" && message.reasoning.isNotBlank()) {
                bubble.addView(smallInlineAction("🧠 思考") {
                    if (!expandedReasoning.add(message.id)) expandedReasoning.remove(message.id)
                    notifyDataSetChanged()
                })
                if (expandedReasoning.contains(message.id)) {
                    bubble.addView(TextView(this@OverlayBubbleService).apply {
                        text = message.reasoning
                        textSize = 12f
                        setTextColor(Color.rgb(190, 185, 202))
                        setPadding(0, dp(4), 0, dp(5))
                    })
                }
            }
            bubble.addView(TextView(this@OverlayBubbleService).apply {
                text = message.content
                textSize = 15f
                setTextColor(Color.WHITE)
                setPadding(0, dp(3), 0, 0)
            })
            if (message.role == "assistant") {
                val actions = LinearLayout(this@OverlayBubbleService).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.END
                }
                actions.addView(smallInlineAction("🔊") { speakMessage(message.id) })
                bubble.addView(actions)
            }
            outer.addView(
                bubble,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ).apply {
                    width = (overlayChatWidth(screenBounds().first) * 0.88f).toInt()
                },
            )
            return outer
        }

        private fun smallInlineAction(label: String, onClick: () -> Unit): TextView =
            TextView(this@OverlayBubbleService).apply {
                text = label
                textSize = 14f
                setTextColor(Color.rgb(210, 195, 235))
                setPadding(dp(9), dp(4), dp(9), dp(2))
                setOnClickListener { onClick() }
            }
    }

    private fun proactiveIntentLabel(intent: String): String = when (intent) {
        "gentle_ping" -> "轻轻找你"
        "miss_you" -> "想你"
        "followup" -> "续上次的话"
        "share_thought" -> "分享念头"
        "curiosity" -> "好奇"
        "social_share" -> "随手分享"
        "intimacy_invitation" -> "亲密邀约"
        "emotional_reach" -> "想靠近你"
        else -> "轻轻找你"
    }

    private inner class OverlayBubbleRoot(context: Context) : FrameLayout(context) {
        private var visibilityWasSuppressed = false

        override fun onWindowVisibilityChanged(visibility: Int) {
            super.onWindowVisibilityChanged(visibility)
            CompanionRuntimeState.noteOverlayWindowVisibility(visibility)
            if (inputRecoveryInProgress || inputRecoveryScheduled) return
            if (visibility != View.VISIBLE) {
                visibilityWasSuppressed = true
                CompanionRuntimeState.noteOverlaySystemCover("window_visibility_suppressed")
                return
            }
            if (!visibilityWasSuppressed) return
            visibilityWasSuppressed = false
            if (!running || chatExpanded || CompanionRuntimeState.isAppVisible()) return
            val keyguard = getSystemService(KeyguardManager::class.java)
            if (!keyguard.isDeviceLocked) {
                scheduleInputChannelRecovery("window_visibility_restored")
            }
        }
    }

    private inner class OverlayEditText(context: Context) : EditText(context) {
        var onImeBack: (() -> Unit)? = null

        override fun onKeyPreIme(keyCode: Int, event: KeyEvent): Boolean {
            if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                onImeBack?.invoke()
            }
            return super.onKeyPreIme(keyCode, event)
        }
    }

    companion object {
        const val ACTION_SET_UNREAD = "com.aicompanion.localfirst.SET_UNREAD"
        const val ACTION_INCREMENT_UNREAD = "com.aicompanion.localfirst.INCREMENT_UNREAD"
        const val ACTION_CLEAR_UNREAD = "com.aicompanion.localfirst.CLEAR_UNREAD"
        const val ACTION_SHOW_CHAT = "com.aicompanion.localfirst.SHOW_CHAT"
        const val ACTION_COLLAPSE_CHAT = "com.aicompanion.localfirst.COLLAPSE_CHAT"
        const val ACTION_WAKE_BRAIN = "com.aicompanion.localfirst.WAKE_BRAIN"
        const val ACTION_NOTIFICATION_REPLY = "com.aicompanion.localfirst.NOTIFICATION_REPLY"
        private const val INLINE_REPLY_MAX_ATTEMPTS = 5
        private const val BUBBLE_WINDOW_DP = 62
        private const val BUBBLE_AVATAR_DP = 50
        private const val BUBBLE_BADGE_DP = 20
        private const val OVERLAY_RECENT_LIMIT = 8
        private const val OVERLAY_OLDER_PAGE_LIMIT = 24
        private const val ACTION_RECONCILE = "com.aicompanion.localfirst.RECONCILE"
        private const val EXTRA_REASON = "reason"
        const val EXTRA_COUNT = "count"
        const val EXTRA_REPLY_TEXT = "reply_text"
        const val EXTRA_REPLY_ID = "reply_id"
        const val EXTRA_REPLY_TO_MESSAGE_ID = "reply_to_message_id"
        const val PREFS = "overlay_state"
        const val KEY_UNREAD = "unread"
        private const val KEY_X = "bubble_x"
        private const val KEY_Y = "bubble_y"
        private const val PERMISSION_WATCH_MS = 30_000L
        private const val BUBBLE_SAFE_MARGIN_DP = 6
        private const val BACKGROUND_COMMAND_CHANNEL = "ai_companion/background_commands"
        private const val BACKGROUND_READY_TIMEOUT_MS = 12_000L
        private const val KEY_LAST_SIGNAL_WAKE_AT = "last_signal_wake_at"
        private const val SIGNAL_WAKE_MIN_INTERVAL_MS = 90_000L
        private const val SYSTEM_COVER_RECOVERY_DELAY_MS = 650L
        private const val INPUT_RECOVERY_MIN_GAP_MS = 8_000L
        private const val INPUT_RECOVERY_SETTLE_MS = 700L
        private const val SYSTEM_COVER_REQUEST_MIN_GAP_MS = 4_000L
        @Volatile private var lastSystemCoverRecoveryRequestAt = 0L

        @Volatile var running: Boolean = false
            private set

        @Volatile var backgroundBrainReady: Boolean = false
            private set

        fun startUserEnabled(context: Context) {
            CompanionRuntimeState.setOverlayUserEnabled(context, true)
            startPersistent(context, "user_enabled")
        }

        fun stopUserEnabled(context: Context) {
            CompanionRuntimeState.setOverlayUserEnabled(context, false)
            context.stopService(Intent(context, OverlayBubbleService::class.java))
        }

        fun stopForStandby(context: Context) {
            // Ownership transfer must stop the old device immediately without
            // erasing the user's per-device overlay preference. If this device
            // later becomes Active Brain again, reconcile can restore it.
            context.stopService(Intent(context, OverlayBubbleService::class.java))
        }

        fun reconcileFromVisibleActivity(context: Context) {
            if (!CompanionRuntimeState.isOverlayUserEnabled(context)) return
            if (!Settings.canDrawOverlays(context)) return
            if (running) {
                runCatching {
                    context.startService(
                        Intent(context, OverlayBubbleService::class.java)
                            .setAction(ACTION_RECONCILE)
                            .putExtra(EXTRA_REASON, "visible_activity_reconcile"),
                    )
                }
                return
            }
            startPersistent(context, "visible_activity_reconcile")
        }

        fun collapseChatFromVisibleActivity(context: Context) {
            if (!running) return
            runCatching {
                context.startService(
                    Intent(context, OverlayBubbleService::class.java)
                        .setAction(ACTION_COLLAPSE_CHAT)
                        .putExtra(EXTRA_REASON, "full_activity_visible"),
                )
            }
        }

        fun showChatFromUserAction(context: Context, reason: String) {
            if (!CompanionRuntimeState.isOverlayUserEnabled(context)) return
            if (!NativeEventStore.isActiveBrain(context)) return
            if (!Settings.canDrawOverlays(context)) return
            val intent = Intent(context, OverlayBubbleService::class.java)
                .setAction(ACTION_SHOW_CHAT)
                .putExtra(EXTRA_REASON, reason.take(120))
            runCatching { context.startService(intent) }
                .onFailure { startPersistent(context, "show_chat_recover") }
        }

        @Synchronized
        fun requestSystemCoverRecovery(context: Context, reason: String = "window_transition"): Boolean {
            if (!CompanionRuntimeState.isOverlayUserEnabled(context)) return false
            if (!NativeEventStore.isActiveBrain(context)) return false
            if (!Settings.canDrawOverlays(context)) return false
            val now = System.currentTimeMillis()
            if (now - lastSystemCoverRecoveryRequestAt < SYSTEM_COVER_REQUEST_MIN_GAP_MS) {
                return false
            }
            lastSystemCoverRecoveryRequestAt = now
            val safeReason = "system_cover:${reason.take(60)}"
            CompanionRuntimeState.noteOverlaySystemCover(safeReason)
            val intent = Intent(context, OverlayBubbleService::class.java)
                .setAction(ACTION_RECONCILE)
                .putExtra(EXTRA_REASON, safeReason)
            return runCatching {
                if (running) {
                    context.startService(intent)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            }.getOrDefault(false)
        }

        fun requestBrainWake(context: Context, reason: String): Boolean {
            if (!CompanionRuntimeState.isOverlayUserEnabled(context)) return false
            if (!NativeEventStore.isActiveBrain(context)) return false
            if (!Settings.canDrawOverlays(context)) return false
            val intent = Intent(context, OverlayBubbleService::class.java)
                .setAction(ACTION_WAKE_BRAIN)
                .putExtra(EXTRA_REASON, reason.take(120))
            return runCatching {
                if (running) {
                    context.startService(intent)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            }.getOrElse { error ->
                NativeEventStore.addDeviceEvent(
                    context,
                    source = "system",
                    eventType = "background_brain_wake_failed",
                    appPackage = context.packageName,
                    summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
                )
                false
            }
        }

        @Synchronized
        fun requestSignalBrainWake(context: Context, reason: String): Boolean {
            val now = System.currentTimeMillis()
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val last = prefs.getLong(KEY_LAST_SIGNAL_WAKE_AT, 0L)
            if (last > 0L && now - last < SIGNAL_WAKE_MIN_INTERVAL_MS) return false
            val sent = requestBrainWake(context, "signal:${reason.take(80)}")
            if (sent) prefs.edit().putLong(KEY_LAST_SIGNAL_WAKE_AT, now).apply()
            return sent
        }

        fun startPersistent(context: Context, reason: String) {
            if (!CompanionRuntimeState.isOverlayUserEnabled(context)) return
            if (!NativeEventStore.isActiveBrain(context)) return
            if (!Settings.canDrawOverlays(context)) return
            val intent = Intent(context, OverlayBubbleService::class.java)
                .setAction(ACTION_RECONCILE)
                .putExtra(EXTRA_REASON, reason.take(120))
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            }.onFailure { error ->
                CompanionRuntimeState.markServiceStopped(
                    context,
                    "start_failed:${error.javaClass.simpleName}",
                )
                NativeEventStore.addDeviceEvent(
                    context,
                    source = "system",
                    eventType = "companion_service_start_failed",
                    appPackage = context.packageName,
                    summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
                )
            }
        }
    }
}
