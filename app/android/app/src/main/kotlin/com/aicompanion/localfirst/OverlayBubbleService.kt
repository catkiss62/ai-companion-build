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
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.text.InputType
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.view.inputmethod.InputMethodManager
import android.widget.BaseAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.ScrollView
import android.widget.TextView
import com.aicompanion.localfirst.pet.PetConversationPolicy
import com.aicompanion.localfirst.pet.PetOverlayWindow
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.hypot

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
    private var petOverlayWindow: PetOverlayWindow? = null
    private var bubbleOptionsRoot: View? = null
    private var bubbleOptionsParams: WindowManager.LayoutParams? = null
    private var bubbleLastTapAtMs = 0L
    private var bubbleLastTapRawX = 0f
    private var bubbleLastTapRawY = 0f
    private var pendingBubbleSingleTap: Runnable? = null

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
    private var overlaySubmitCommandPending = false
    private var overlayCancelling = false
    private var overlayGenerationPhase = "idle"
    private var generationPollEpoch = 0
    private var ttsPollEpoch = 0
    private var petAutonomyPollEpoch = 0
    private var overlayTtsPhase = "idle"
    private var overlayTtsMessageId = ""
    private var appGenerationActive = false
    private var appGenerationPhase = "idle"
    private var appTtsPhase = "idle"
    private var petTtsDiscoveryUntilMs = 0L
    private var streamingAssistantMessageId = ""
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
    private var scheduledRecoverySessionId = 0
    private var scheduledRecoveryAttempt = 0
    private var coverWindowMutationInProgress = false

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
            if (!CompanionRuntimeState.isOverlaySystemCoverActive()) {
                if (CompanionRuntimeState.overlayInputSuspect) {
                    if (CompanionRuntimeState.overlayCoverState != "failed" &&
                        CompanionRuntimeState.overlayCoverRecoveryAttempt < COVER_RECOVERY_MAX_ATTEMPTS
                    ) {
                        scheduleCoverRecovery(
                            sessionId = CompanionRuntimeState.currentOverlayCoverSessionId(),
                            attempt = (CompanionRuntimeState.overlayCoverRecoveryAttempt + 1)
                                .coerceAtLeast(1),
                            reason = "suspect_watchdog",
                            delayMs = COVER_RECOVERY_WATCHDOG_DELAY_MS,
                        )
                    } else {
                        // A failed bounded session stays observable for manual
                        // diagnostics; permissionWatch must not become an
                        // unbounded fourth/fifth/... recovery loop.
                        updateOverlayTouchHealth()
                    }
                } else {
                    ensureOverlayHealth("permission_watch")
                }
            }
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
                    closeBubbleOptions()
                    collapseChatOverlay("screen_off")
                    petOverlayWindow?.setVisible(false) ?: run {
                        bubbleRoot?.visibility = View.GONE
                    }
                }
                Intent.ACTION_SCREEN_ON -> {
                    if (keyguard.isDeviceLocked) {
                        closeBubbleOptions()
                        petOverlayWindow?.setVisible(false) ?: run {
                            bubbleRoot?.visibility = View.GONE
                        }
                    }
                }
                Intent.ACTION_USER_PRESENT -> {
                    if (pendingShowAfterUnlock) {
                        pendingShowAfterUnlock = false
                        showChatOverlay("unlock_pending")
                    } else if (!chatExpanded) {
                        petOverlayWindow?.setVisible(true) ?: run {
                            bubbleRoot?.visibility = View.VISIBLE
                        }
                        CompanionRuntimeState.setOverlayVisible(true)
                        updateOverlayTouchHealth()
                    }
                    if (CompanionRuntimeState.overlayInputSuspect &&
                        !CompanionRuntimeState.isOverlaySystemCoverActive()
                    ) {
                        scheduleCoverRecovery(
                            sessionId = CompanionRuntimeState.currentOverlayCoverSessionId(),
                            attempt = 1,
                            reason = "device_present_after_cover",
                            delayMs = 250L,
                        )
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
            ACTION_SET_PET_CONVERSATION -> {
                appGenerationActive = intent.getBooleanExtra(EXTRA_GENERATION_ACTIVE, false)
                appGenerationPhase = intent.getStringExtra(EXTRA_GENERATION_PHASE)
                    ?.takeIf { it in setOf("idle", "thinking", "answering", "cancelling") }
                    ?: "idle"
                appTtsPhase = intent.getStringExtra(EXTRA_TTS_PHASE)
                    ?.takeIf { it in setOf("idle", "synthesizing", "playing") }
                    ?: "idle"
                if (appGenerationActive && (chatExpanded || petOverlayWindow != null)) {
                    beginGenerationPolling()
                } else if (!appGenerationActive && !chatSending) {
                    stopGenerationPolling()
                    removeStreamingMessage(notify = true)
                    if (chatExpanded) {
                        refreshOverlayMessages(opened = false, attempt = 0)
                    }
                }
                updatePetConversationCue()
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
            ACTION_SET_ENTRY_MODE -> {
                switchEntryMode(
                    normalizeEntryMode(intent.getStringExtra(EXTRA_ENTRY_MODE)),
                    intent.getStringExtra(EXTRA_REASON) ?: "service_action",
                )
                return START_STICKY
            }
            ACTION_SET_PET_SIZE -> {
                val size = PetOverlayWindow.normalizedSize(
                    intent.getStringExtra(EXTRA_PET_SIZE),
                )
                getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putString(PetOverlayWindow.KEY_PET_SIZE, size)
                    .apply()
                petOverlayWindow?.resize(size)
                return START_STICKY
            }
            ACTION_RECONCILE -> {
                val reconcileReason = intent.getStringExtra(EXTRA_REASON) ?: "service_reconcile"
                if (reconcileReason == "visible_activity_reconcile" &&
                    (CompanionRuntimeState.isOverlaySystemCoverActive() ||
                        CompanionRuntimeState.overlayInputSuspect)
                ) {
                    handleSystemCoverExited("visible_activity_reconcile")
                } else if (CompanionRuntimeState.isOverlaySystemCoverActive()) {
                    updateOverlayTouchHealth()
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
            ACTION_SYSTEM_COVER_ENTER -> {
                handleSystemCoverEntered(
                    reason = intent.getStringExtra(EXTRA_REASON) ?: "system_cover_enter",
                    detachBubble = intent.getBooleanExtra(EXTRA_DETACH_BUBBLE, true),
                )
                return START_STICKY
            }
            ACTION_SYSTEM_COVER_EXIT -> {
                handleSystemCoverExited(
                    intent.getStringExtra(EXTRA_REASON) ?: "system_cover_exit",
                )
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
        CompanionRuntimeState.noteServiceCommand(this, reason)
        return START_STICKY
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        CompanionRuntimeState.noteTrimMemory(this, level)
        if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW) {
            backgroundEngine?.let { engine ->
                runCatching { engine.systemChannel.sendMemoryPressureWarning() }
                runCatching { engine.dartExecutor.notifyLowMemoryWarning() }
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        petOverlayWindow?.onConfigurationChanged() ?: bubbleRoot?.let { view ->
            clampBubbleToSafeArea()
            persistBubblePosition()
            updateBubbleLayout(view)
            if (bubbleOptionsRoot != null) repositionBubbleOptions()
        }
        if (chatExpanded) updateChatLayoutForScreen()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        CompanionRuntimeState.noteTaskRemoved(this)
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
        stopPetAutonomyPolling()
        unregisterDeviceStateReceiver()
        running = false
        pendingShowAfterUnlock = false
        pendingBrainWakeReason = null
        brainWakeAttempt = 0
        backgroundEngineStarting = false
        backgroundEngineRestartScheduled = false
        inputRecoveryScheduled = false
        inputRecoveryInProgress = false
        scheduledRecoverySessionId = 0
        scheduledRecoveryAttempt = 0
        coverWindowMutationInProgress = false
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
        closeBubbleOptions()
        pendingBubbleSingleTap?.let(mainHandler::removeCallbacks)
        pendingBubbleSingleTap = null
        removeChatWindow()
        val pet = petOverlayWindow
        petOverlayWindow = null
        if (pet != null) {
            pet.release(removeRoot = true)
        } else {
            bubbleRoot?.let { runCatching { windowManager.removeView(it) } }
        }
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
        if (entryMode(this) == ENTRY_MODE_PET) return createPetEntry()
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

    private fun createPetEntry(): Boolean {
        val host = PetOverlayWindow(
            context = this,
            windowManager = windowManager,
            overlayWindowType = overlayWindowType(),
            onOpenChat = { showChatOverlay("pet_double_tap_menu") },
            onSwitchToBubble = {
                switchEntryMode(ENTRY_MODE_BUBBLE, "pet_double_tap_menu")
            },
            onTouchActivity = CompanionRuntimeState::noteOverlayTouch,
        )
        if (!host.attach()) {
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "pet_overlay_window_create_failed",
                appPackage = packageName,
                summary = "桌宠悬浮窗口创建失败。",
            )
            return false
        }
        petOverlayWindow = host
        bubbleRoot = host.root
        bubbleParams = requireNotNull(host.params)
        badge = host.badge
        val keyguard = getSystemService(KeyguardManager::class.java)
        host.setVisible(!keyguard.isDeviceLocked)
        updatePetConversationCue()
        if (backgroundBrainReady) beginPetAutonomyPolling()
        CompanionRuntimeState.setOverlayVisible(!keyguard.isDeviceLocked)
        setUnread(readUnread())
        updateOverlayTouchHealth()
        return true
    }

    private fun switchEntryMode(mode: String, reason: String) {
        val normalized = normalizeEntryMode(mode)
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_ENTRY_MODE, normalized)
            .apply()
        val alreadyPet = petOverlayWindow != null
        if ((normalized == ENTRY_MODE_PET) == alreadyPet && bubbleRoot?.isAttachedToWindow == true) {
            updateOverlayTouchHealth()
            return
        }

        hideKeyboard()
        closeBubbleOptions()
        removeChatWindow()
        val pet = petOverlayWindow
        stopPetAutonomyPolling()
        petOverlayWindow = null
        if (pet != null) {
            pet.release(removeRoot = true)
        } else {
            bubbleRoot?.let { runCatching { windowManager.removeViewImmediate(it) } }
        }
        bubbleRoot = null
        badge = null

        if (!createBubble()) {
            destroyReason = "entry_mode_switch_failed:$normalized"
            stopSelf()
            return
        }
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "overlay_entry_mode_changed",
            appPackage = packageName,
            summary = "悬浮入口已切换为${if (normalized == ENTRY_MODE_PET) "桌宠" else "悬浮球"}。",
            metadata = mapOf(
                "mode" to normalized,
                "reason" to reason.take(120),
            ),
        )
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
            text = when {
                overlayCancelling -> "停止中"
                chatSending -> "停止"
                else -> "发送"
            }
            isEnabled = !overlayCancelling
            setOnClickListener {
                if (chatSending) cancelGenerationFromOverlay() else sendFromOverlay()
            }
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
        closeBubbleOptions()
        pendingShowAfterUnlock = false
        setUnread(0)
        chatExpanded = true
        CompanionRuntimeState.setOverlayChatExpanded(true)
        if (petOverlayWindow == null) {
            bubbleRoot?.visibility = View.GONE
        }
        chatRoot?.visibility = View.VISIBLE
        scrollChatToBottom()
        chatInputMode = false
        chatParams?.let { params ->
            params.flags = readModeFlags()
            runCatching { windowManager.updateViewLayout(chatRoot, params) }
        }
        keepPetAboveChat("chat_open")
        CompanionRuntimeState.setOverlayVisible(true)
        updateOverlayTouchHealth()
        refreshOverlayMessages(opened = true, attempt = 0)
        if (chatSending) beginGenerationPolling()
        beginTtsPolling()
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
        val visible = !keyguard.isDeviceLocked
        petOverlayWindow?.setVisible(visible) ?: run {
            bubbleRoot?.visibility = if (visible) View.VISIBLE else View.GONE
        }
        CompanionRuntimeState.setOverlayVisible(visible && bubbleRoot != null)
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
            keepPetAboveChat("chat_input_enter")
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
            keepPetAboveChat("chat_input_exit")
        }
    }

    private fun keepPetAboveChat(reason: String) {
        val pet = petOverlayWindow ?: return
        pet.setVisible(true)
        if (!pet.bringToFront()) {
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "pet_overlay_bring_to_front_failed",
                appPackage = packageName,
                summary = "桌宠置顶重挂载失败：${reason.take(80)}。",
            )
        }
        updatePetConversationCue()
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
        overlaySubmitCommandPending = true
        setComposerGenerationState(sending = true)
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
        beginGenerationPolling()

        channel.invokeMethod(
            "sendMessage",
            mapOf("text" to text),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    mainHandler.post {
                        overlaySubmitCommandPending = false
                        stopGenerationPolling()
                        setComposerGenerationState(sending = false)
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
                        val cancelled = map?.get("cancelled") == true
                        val error = map?.get("error") as? String ?: ""
                        if (ok && chatExpanded) setUnread(0)
                        setChatStatus(
                            when {
                                cancelled -> "已停止这轮回复。"
                                ok -> null
                                else -> error.ifBlank { "发送失败。" }
                            },
                            !ok && !cancelled,
                        )
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post {
                        overlaySubmitCommandPending = false
                        stopGenerationPolling()
                        setComposerGenerationState(sending = false)
                        setChatStatus("发送失败：${errorMessage ?: errorCode}", true)
                        refreshOverlayMessages(opened = false, attempt = 0)
                    }
                }

                override fun notImplemented() {
                    mainHandler.post {
                        overlaySubmitCommandPending = false
                        stopGenerationPolling()
                        setComposerGenerationState(sending = false)
                        setChatStatus("她还在重新连接，请稍后再试。", true)
                        refreshOverlayMessages(opened = false, attempt = 0)
                    }
                }
            },
        )
    }

    private fun cancelGenerationFromOverlay() {
        if (!chatSending || overlayCancelling) return
        val channel = backgroundCommands ?: run {
            setChatStatus("后台大脑尚未连接，暂时无法停止。", true)
            return
        }
        setComposerGenerationState(sending = true, cancelling = true)
        setChatStatus("正在停止…")
        channel.invokeMethod(
            "cancelGeneration",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    mainHandler.post {
                        overlaySubmitCommandPending = false
                        stopGenerationPolling()
                        removeStreamingMessage()
                        setComposerGenerationState(sending = false)
                        setChatStatus("已停止这轮回复。")
                        refreshOverlayMessages(opened = false, attempt = 0)
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post {
                        setComposerGenerationState(sending = true)
                        setChatStatus("停止失败：${errorMessage ?: errorCode}", true)
                        beginGenerationPolling()
                    }
                }

                override fun notImplemented() {
                    mainHandler.post {
                        setComposerGenerationState(sending = true)
                        setChatStatus("当前后台还不支持停止，请稍后重试。", true)
                        beginGenerationPolling()
                    }
                }
            },
        )
    }

    private fun setComposerGenerationState(sending: Boolean, cancelling: Boolean = false) {
        val wasSending = chatSending
        chatSending = sending
        overlayCancelling = cancelling
        overlayGenerationPhase = when {
            !sending -> "idle"
            cancelling -> "cancelling"
            !wasSending || overlayGenerationPhase in setOf("idle", "cancelling") -> "thinking"
            else -> overlayGenerationPhase
        }
        if (sending) {
            petTtsDiscoveryUntilMs = 0L
        } else if (wasSending && petOverlayWindow != null) {
            petTtsDiscoveryUntilMs = SystemClock.uptimeMillis() + PET_TTS_DISCOVERY_MS
            beginTtsPolling()
        }
        chatSend?.apply {
            text = when {
                cancelling -> "停止中"
                sending -> "停止"
                else -> "发送"
            }
            isEnabled = !cancelling
        }
        updatePetConversationCue()
    }

    private fun beginGenerationPolling() {
        val epoch = ++generationPollEpoch
        pollGenerationState(epoch)
    }

    private fun stopGenerationPolling() {
        generationPollEpoch++
    }

    private fun pollGenerationState(epoch: Int) {
        if (epoch != generationPollEpoch || !shouldPollGeneration()) return
        val channel = backgroundCommands
        if (channel == null) {
            scheduleGenerationPoll(epoch)
            return
        }
        channel.invokeMethod(
            "generationSnapshot",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    mainHandler.post {
                        if (epoch != generationPollEpoch || !shouldPollGeneration()) {
                            return@post
                        }
                        applyGenerationSnapshot(result)
                        scheduleGenerationPoll(epoch)
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post { scheduleGenerationPoll(epoch) }
                }

                override fun notImplemented() {
                    mainHandler.post { scheduleGenerationPoll(epoch) }
                }
            },
        )
    }

    private fun scheduleGenerationPoll(epoch: Int) {
        if (epoch != generationPollEpoch || !shouldPollGeneration()) return
        mainHandler.postDelayed({ pollGenerationState(epoch) }, GENERATION_POLL_MS)
    }

    // Historical v0.35.8 validator token: (chatSending || appGenerationActive)
    private fun shouldPollGeneration(): Boolean =
        (chatSending || overlaySubmitCommandPending || appGenerationActive) &&
            (chatExpanded || petOverlayWindow != null)

    private fun beginTtsPolling() {
        val epoch = ++ttsPollEpoch
        pollTtsState(epoch)
    }

    private fun stopTtsPolling() {
        ttsPollEpoch++
    }

    private fun pollTtsState(epoch: Int) {
        if (epoch != ttsPollEpoch || !shouldPollTts()) return
        val channel = backgroundCommands
        if (channel == null) {
            scheduleTtsPoll(epoch)
            return
        }
        channel.invokeMethod(
            "ttsSnapshot",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    mainHandler.post {
                        if (epoch != ttsPollEpoch || !shouldPollTts()) return@post
                        val map = result as? Map<*, *>
                        val phase = map?.get("phase") as? String ?: "idle"
                        val messageId = map?.get("message_id") as? String ?: ""
                        if (phase != overlayTtsPhase || messageId != overlayTtsMessageId) {
                            overlayTtsPhase = phase
                            overlayTtsMessageId = messageId
                            chatAdapter?.notifyDataSetChanged()
                            updatePetConversationCue()
                        }
                        scheduleTtsPoll(epoch)
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post { scheduleTtsPoll(epoch) }
                }

                override fun notImplemented() {
                    mainHandler.post { scheduleTtsPoll(epoch) }
                }
            },
        )
    }

    private fun scheduleTtsPoll(epoch: Int) {
        if (epoch != ttsPollEpoch || !shouldPollTts()) return
        mainHandler.postDelayed({ pollTtsState(epoch) }, TTS_POLL_MS)
    }

    private fun shouldPollTts(): Boolean = chatExpanded ||
        (petOverlayWindow != null && (
            chatSending ||
                overlayTtsPhase != "idle" ||
                SystemClock.uptimeMillis() < petTtsDiscoveryUntilMs
            ))

    private fun applyGenerationSnapshot(result: Any?) {
        val map = result as? Map<*, *> ?: return
        val sharedSending = map["sending"] == true
        val composerSending = sharedSending || overlaySubmitCommandPending
        if (!overlayCancelling && chatSending != composerSending) {
            setComposerGenerationState(sending = composerSending)
        }
        val reasoning = map["reasoning"] as? String ?: ""
        val content = map["content"] as? String ?: ""
        val phase = map["phase"] as? String ?: "thinking"
        val statusText = map["status_text"] as? String ?: ""
        overlayGenerationPhase = phase
        updatePetConversationCue()
        streamingAssistantMessageId = map["assistant_message_id"] as? String ?: ""
        removeStreamingMessage(notify = false)
        if (sharedSending) {
            setChatStatus(statusText.takeIf { it.isNotBlank() } ?: when (phase) {
                "answering" -> "正在回复…"
                "cancelling" -> "正在停止…"
                else -> "正在想…"
            })
            loadedMessages.add(
                NativeChatMessage(
                    id = STREAMING_MESSAGE_ID,
                    role = "assistant",
                    content = content,
                    reasoning = reasoning,
                    createdAt = System.currentTimeMillis(),
                    proactive = false,
                    proactiveIntent = "",
                    proactiveDelivery = "",
                ),
            )
        }
        chatAdapter?.notifyDataSetChanged()
        scrollChatToBottom()
        if (!sharedSending) setChatStatus(null)
    }

    private fun removeStreamingMessage(notify: Boolean = true) {
        val removed = loadedMessages.removeAll { it.id == STREAMING_MESSAGE_ID }
        if (removed && notify) chatAdapter?.notifyDataSetChanged()
    }

    private fun speakMessage(messageId: String) {
        if (overlayTtsMessageId == messageId) {
            when (overlayTtsPhase) {
                "playing" -> {
                    stopSpeech()
                    return
                }
                "synthesizing" -> return
            }
        }
        applyTtsState("synthesizing", messageId)
        backgroundCommands?.invokeMethod(
            "speakMessage",
            mapOf("messageId" to messageId),
            object : MethodChannel.Result {
                override fun success(result: Any?) = Unit
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post { applyTtsState("idle", "") }
                }
                override fun notImplemented() {
                    mainHandler.post { applyTtsState("idle", "") }
                }
            },
        ) ?: applyTtsState("idle", "")
    }

    private fun stopSpeech() {
        applyTtsState("idle", "")
        backgroundCommands?.invokeMethod("stopSpeech", null)
    }

    private fun applyTtsState(phase: String, messageId: String) {
        if (phase == overlayTtsPhase && messageId == overlayTtsMessageId) return
        overlayTtsPhase = phase
        overlayTtsMessageId = messageId
        chatAdapter?.notifyDataSetChanged()
        updatePetConversationCue()
        if (phase != "idle" && petOverlayWindow != null) beginTtsPolling()
    }

    private fun updatePetConversationCue() {
        val generationActive = chatSending || appGenerationActive
        val generationPhase = if (chatSending) overlayGenerationPhase else appGenerationPhase
        val ttsPhase = when {
            overlayTtsPhase == "playing" -> overlayTtsPhase
            appTtsPhase == "playing" -> appTtsPhase
            overlayTtsPhase == "synthesizing" -> overlayTtsPhase
            else -> appTtsPhase
        }
        val cue = PetConversationPolicy.cueFor(
            generationActive = generationActive,
            generationPhase = generationPhase,
            ttsPhase = ttsPhase,
        )
        petOverlayWindow?.apply {
            setConversationCue(cue)
            // Synthesis intentionally has no TALKING action; it also pauses
            // autonomous flourishes so the pet remains visually quiet until
            // real playback begins.
            setAutonomySuppressed(
                chatExpanded || generationActive || ttsPhase != "idle",
            )
        }
    }

    private fun beginPetAutonomyPolling() {
        if (!running || petOverlayWindow == null || !backgroundBrainReady) return
        val epoch = ++petAutonomyPollEpoch
        pollPetAutonomy(epoch)
    }

    private fun stopPetAutonomyPolling() {
        petAutonomyPollEpoch++
        petOverlayWindow?.setAutonomySnapshot(null)
    }

    private fun pollPetAutonomy(epoch: Int) {
        if (epoch != petAutonomyPollEpoch || !shouldPollPetAutonomy()) return
        val channel = backgroundCommands ?: return schedulePetAutonomyPoll(epoch)
        channel.invokeMethod(
            "petAutonomySnapshot",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    mainHandler.post {
                        if (epoch != petAutonomyPollEpoch || !shouldPollPetAutonomy()) return@post
                        petOverlayWindow?.setAutonomySnapshot(result)
                        schedulePetAutonomyPoll(epoch)
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    mainHandler.post { schedulePetAutonomyPoll(epoch) }
                }

                override fun notImplemented() {
                    mainHandler.post { schedulePetAutonomyPoll(epoch) }
                }
            },
        )
    }

    private fun schedulePetAutonomyPoll(epoch: Int) {
        if (epoch != petAutonomyPollEpoch || !shouldPollPetAutonomy()) return
        mainHandler.postDelayed({ pollPetAutonomy(epoch) }, PET_AUTONOMY_POLL_MS)
    }

    private fun shouldPollPetAutonomy(): Boolean =
        running && petOverlayWindow != null && backgroundBrainReady

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
                clearAnimation()
                visibility = View.GONE
                this.text = ""
            } else {
                visibility = View.VISIBLE
                this.text = text
                setTextColor(if (error) Color.rgb(255, 135, 145) else Color.rgb(192, 180, 212))
                if (error) {
                    clearAnimation()
                } else if (animation == null) {
                    startAnimation(AlphaAnimation(0.52f, 1f).apply {
                        duration = 900L
                        repeatMode = Animation.REVERSE
                        repeatCount = Animation.INFINITE
                    })
                }
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
            val attachments = (map["attachments"] as? List<*>)
                ?.mapNotNull attachmentLoop@{ rawAttachment ->
                    val attachment = rawAttachment as? Map<*, *> ?: return@attachmentLoop null
                    val path = attachment["thumbnail_path"] as? String ?: return@attachmentLoop null
                    if (path.isBlank()) return@attachmentLoop null
                    NativeAttachment(
                        id = attachment["id"] as? String ?: path,
                        kind = attachment["kind"] as? String ?: "",
                        thumbnailPath = path,
                        width = (attachment["width"] as? Number)?.toInt() ?: 0,
                        height = (attachment["height"] as? Number)?.toInt() ?: 0,
                    )
                }.orEmpty()
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
                attachments = attachments,
            )
        }
    }

    private fun attachDrag(view: View) {
        var startX = 0
        var startY = 0
        var downX = 0f
        var downY = 0f
        var moved = false
        var doubleTapCandidate = false
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    CompanionRuntimeState.noteOverlayTouch("down")
                    closeBubbleOptions()
                    startX = bubbleParams.x
                    startY = bubbleParams.y
                    downX = event.rawX
                    downY = event.rawY
                    moved = false
                    val now = SystemClock.uptimeMillis()
                    doubleTapCandidate = bubbleLastTapAtMs > 0L &&
                        now - bubbleLastTapAtMs <= ViewConfiguration.getDoubleTapTimeout() &&
                        hypot(
                            event.rawX - bubbleLastTapRawX,
                            event.rawY - bubbleLastTapRawY,
                        ) <= dp(BUBBLE_DOUBLE_TAP_SLOP_DP)
                    if (doubleTapCandidate) {
                        pendingBubbleSingleTap?.let(mainHandler::removeCallbacks)
                        pendingBubbleSingleTap = null
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    CompanionRuntimeState.noteOverlayTouch("move")
                    val dx = (event.rawX - downX).toInt()
                    val dy = (event.rawY - downY).toInt()
                    if (abs(dx) > dp(4) || abs(dy) > dp(4)) {
                        moved = true
                        doubleTapCandidate = false
                        bubbleLastTapAtMs = 0L
                        pendingBubbleSingleTap?.let(mainHandler::removeCallbacks)
                        pendingBubbleSingleTap = null
                        setBubbleRetracted(false)
                    }
                    bubbleParams.x = startX + dx
                    bubbleParams.y = startY + dy
                    updateBubbleLayout(view)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    CompanionRuntimeState.noteOverlayTouch("up")
                    if (moved) {
                        snapBubbleToSafeEdge()
                        persistBubblePosition()
                        updateBubbleLayout(view)
                    } else if (doubleTapCandidate) {
                        bubbleLastTapAtMs = 0L
                        doubleTapCandidate = false
                        showBubbleOptions()
                    } else {
                        scheduleBubbleSingleTap(event.rawX, event.rawY)
                    }
                    moved = false
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    CompanionRuntimeState.noteOverlayTouch("cancel")
                    moved = false
                    doubleTapCandidate = false
                    clampBubbleToSafeArea()
                    persistBubblePosition()
                    updateBubbleLayout(view)
                    true
                }
                else -> false
            }
        }
    }

    private fun scheduleBubbleSingleTap(rawX: Float, rawY: Float) {
        val now = SystemClock.uptimeMillis()
        bubbleLastTapAtMs = now
        bubbleLastTapRawX = rawX
        bubbleLastTapRawY = rawY
        val task = Runnable {
            if (bubbleLastTapAtMs != now) return@Runnable
            bubbleLastTapAtMs = 0L
            if (isBubbleRetracted()) {
                expandBubbleFromLeft()
            } else {
                showChatOverlay("bubble_tap")
            }
        }
        pendingBubbleSingleTap = task
        mainHandler.postDelayed(task, ViewConfiguration.getDoubleTapTimeout().toLong())
    }

    private fun showBubbleOptions() {
        if (bubbleOptionsRoot != null) {
            closeBubbleOptions()
            return
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
            addView(bubbleMenuHeader("悬浮球选项") { closeBubbleOptions() })
            addView(bubbleOptionButton("打开聊天") {
                closeBubbleOptions()
                showChatOverlay("bubble_double_tap_menu")
            })
            addView(bubbleOptionButton("切换为桌宠") {
                closeBubbleOptions()
                switchEntryMode(ENTRY_MODE_PET, "bubble_double_tap_menu")
            })
            addView(bubbleOptionButton("缩进左侧") {
                closeBubbleOptions()
                retractBubbleToLeft()
            })
        }
        val panel = ScrollView(this).apply {
            isFillViewport = false
            clipToOutline = true
            clipChildren = true
            background = rounded(Color.rgb(38, 35, 44), 16f)
            elevation = dp(10).toFloat()
            addView(
                content,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                ),
            )
        }
        val layout = WindowManager.LayoutParams(
            dp(BUBBLE_MENU_DP),
            dp(BUBBLE_MENU_DP),
            overlayWindowType(),
            bubbleModeFlags(),
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }
        bubbleOptionsRoot = panel
        bubbleOptionsParams = layout
        repositionBubbleOptions()
        runCatching { windowManager.addView(panel, layout) }.onFailure {
            bubbleOptionsRoot = null
            bubbleOptionsParams = null
        }
    }

    private fun bubbleMenuHeader(title: String, action: () -> Unit): LinearLayout =
        LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(TextView(this@OverlayBubbleService).apply {
                text = title
                textSize = 13f
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
            }, LinearLayout.LayoutParams(0, dp(34), 1f))
            addView(TextView(this@OverlayBubbleService).apply {
                text = "×"
                textSize = 19f
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
                background = rounded(Color.rgb(82, 77, 91), 999f)
                setOnClickListener { action() }
            }, LinearLayout.LayoutParams(dp(30), dp(30)))
        }

    private fun bubbleOptionButton(label: String, action: () -> Unit): Button = Button(this).apply {
        text = label
        textSize = 11f
        isAllCaps = false
        minWidth = 0
        minHeight = 0
        setPadding(dp(4), 0, dp(4), 0)
        setOnClickListener { action() }
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(42))
    }

    private fun repositionBubbleOptions() {
        val panel = bubbleOptionsRoot ?: return
        val menu = bubbleOptionsParams ?: return
        val safe = bubbleSafeArea()
        menu.x = if (bubbleParams.x + bubbleParams.width + menu.width <= safe.right) {
            (bubbleParams.x + bubbleParams.width).coerceAtLeast(safe.left)
        } else {
            (bubbleParams.x - menu.width).coerceAtLeast(safe.left)
        }
        menu.x = menu.x.coerceIn(safe.left, (safe.right - menu.width).coerceAtLeast(safe.left))
        menu.y = bubbleParams.y.coerceIn(
            safe.top,
            (safe.bottom - menu.height).coerceAtLeast(safe.top),
        )
        if (panel.isAttachedToWindow) runCatching { windowManager.updateViewLayout(panel, menu) }
    }

    private fun closeBubbleOptions() {
        bubbleOptionsRoot?.let { runCatching { windowManager.removeViewImmediate(it) } }
        bubbleOptionsRoot = null
        bubbleOptionsParams = null
    }

    private fun retractBubbleToLeft() {
        setBubbleRetracted(true)
        clampBubbleToSafeArea()
        persistBubblePosition()
        bubbleRoot?.let(::updateBubbleLayout)
    }

    private fun expandBubbleFromLeft() {
        setBubbleRetracted(false)
        val safe = bubbleSafeArea()
        bubbleParams.x = safe.left
        clampBubbleToSafeArea()
        persistBubblePosition()
        bubbleRoot?.let(::updateBubbleLayout)
    }

    private fun setBubbleRetracted(value: Boolean) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_BUBBLE_RETRACTED, value)
            .apply()
    }

    private fun isBubbleRetracted(): Boolean =
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_BUBBLE_RETRACTED, false)

    private fun persistBubblePosition() {
        petOverlayWindow?.let {
            it.persistCurrentPosition()
            return
        }
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
        val width = bubbleParams.width.coerceAtLeast(1)
        val height = bubbleParams.height.coerceAtLeast(1)
        val maxX = (safe.right - width).coerceAtLeast(safe.left)
        val maxY = (safe.bottom - height).coerceAtLeast(safe.top)
        val oldX = bubbleParams.x
        val oldY = bubbleParams.y
        bubbleParams.x = if (isBubbleRetracted()) retractedBubbleX(width) else
            bubbleParams.x.coerceIn(safe.left, maxX)
        bubbleParams.y = bubbleParams.y.coerceIn(safe.top, maxY)
        return oldX != bubbleParams.x || oldY != bubbleParams.y
    }

    private fun isBubblePositionSafe(): Boolean {
        if (!::bubbleParams.isInitialized) return false
        val safe = bubbleSafeArea()
        val maxX = (safe.right - bubbleParams.width.coerceAtLeast(1)).coerceAtLeast(safe.left)
        val maxY = (safe.bottom - bubbleParams.height.coerceAtLeast(1)).coerceAtLeast(safe.top)
        val xSafe = if (isBubbleRetracted()) {
            bubbleParams.x == retractedBubbleX(bubbleParams.width.coerceAtLeast(1))
        } else {
            bubbleParams.x in safe.left..maxX
        }
        return xSafe && bubbleParams.y in safe.top..maxY
    }

    private fun snapBubbleToSafeEdge() {
        setBubbleRetracted(false)
        val safe = bubbleSafeArea()
        val width = bubbleParams.width.coerceAtLeast(1)
        val maxX = (safe.right - width).coerceAtLeast(safe.left)
        val midpoint = safe.left + safe.width / 2
        bubbleParams.x = if (bubbleParams.x + width / 2 < midpoint) safe.left else maxX
        clampBubbleToSafeArea()
    }

    private fun retractedBubbleX(width: Int): Int {
        val physicalLeft = if (Build.VERSION.SDK_INT >= 30) {
            windowManager.currentWindowMetrics.bounds.left
        } else {
            0
        }
        return physicalLeft - (width - dp(BUBBLE_RETRACTED_VISIBLE_DP)).coerceAtLeast(0)
    }

    private fun bubbleModeFlags(): Int =
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

    private fun handleSystemCoverEntered(reason: String, detachBubble: Boolean) {
        if (!running || !Settings.canDrawOverlays(this)) return

        // A new enter after exit_pending invalidates every callback belonging to
        // the earlier session. Repeated Accessibility events while the same
        // picker remains on top stay in the same session and do no extra work.
        val alreadyCovered = CompanionRuntimeState.isOverlaySystemCoverActive()
        var detached = false
        if (detachBubble && bubbleRoot != null && !chatExpanded) {
            detached = retireBubbleForSystemCover()
        }
        val sessionId = CompanionRuntimeState.noteOverlayCoverEntered(reason, detached)
        if (!alreadyCovered) {
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "overlay_system_cover_entered",
                appPackage = packageName,
                summary = "检测到系统安全页面，已隔离旧悬浮输入通道。",
                metadata = mapOf(
                    "session" to sessionId,
                    "detached" to detached,
                ),
            )
        }
    }

    private fun retireBubbleForSystemCover(): Boolean {
        val bubble = bubbleRoot ?: return false
        closeBubbleOptions()
        // Clear ownership before removeViewImmediate: OEMs may dispatch a late
        // visibility callback for the retired root. It must not start a second
        // cover session or recreate itself while the picker is still on top.
        bubbleRoot = null
        badge = null
        petOverlayWindow?.release(removeRoot = false)
        petOverlayWindow = null
        coverWindowMutationInProgress = true
        val removed = runCatching {
            windowManager.removeViewImmediate(bubble)
            true
        }.getOrDefault(false)
        coverWindowMutationInProgress = false
        CompanionRuntimeState.setOverlayVisible(false)
        updateOverlayTouchHealth()
        return removed
    }

    private fun handleSystemCoverExited(reason: String) {
        if (!running || !Settings.canDrawOverlays(this)) return
        val sessionId = CompanionRuntimeState.currentOverlayCoverSessionId()
        if (sessionId <= 0 ||
            (!CompanionRuntimeState.isOverlaySystemCoverActive() &&
                !CompanionRuntimeState.overlayInputSuspect)
        ) return

        CompanionRuntimeState.noteOverlayCoverExited(reason, sessionId)
        scheduleCoverRecovery(
            sessionId = sessionId,
            attempt = 1,
            reason = reason,
            delayMs = COVER_EXIT_STABLE_DELAY_MS,
        )
    }

    private fun scheduleCoverRecovery(
        sessionId: Int,
        attempt: Int,
        reason: String,
        delayMs: Long,
    ) {
        if (sessionId <= 0 || attempt > COVER_RECOVERY_MAX_ATTEMPTS) return
        if (!CompanionRuntimeState.overlayInputSuspect ||
            CompanionRuntimeState.overlayCoverState == "settled" ||
            CompanionRuntimeState.overlayCoverState == "failed"
        ) return
        if (inputRecoveryInProgress) {
            mainHandler.postDelayed({
                scheduleCoverRecovery(sessionId, attempt, reason, delayMs)
            }, INPUT_RECOVERY_SETTLE_MS + 100L)
            return
        }
        if (inputRecoveryScheduled && scheduledRecoverySessionId == sessionId) return

        inputRecoveryScheduled = true
        scheduledRecoverySessionId = sessionId
        scheduledRecoveryAttempt = attempt
        CompanionRuntimeState.noteOverlayCoverRecoveryScheduled(sessionId, attempt, reason)
        mainHandler.postDelayed({
            if (scheduledRecoverySessionId == sessionId && scheduledRecoveryAttempt == attempt) {
                inputRecoveryScheduled = false
            }
            if (sessionId != CompanionRuntimeState.currentOverlayCoverSessionId()) {
                return@postDelayed
            }
            if (!CompanionRuntimeState.overlayInputSuspect ||
                CompanionRuntimeState.overlayCoverState == "settled" ||
                CompanionRuntimeState.overlayCoverState == "failed"
            ) return@postDelayed
            if (CompanionRuntimeState.isOverlaySystemCoverActive()) {
                // Never re-add an overlay beneath a still-active system picker.
                return@postDelayed
            }
            if (!running || !Settings.canDrawOverlays(this)) {
                CompanionRuntimeState.noteOverlayCoverRecoveryFailed(
                    sessionId,
                    attempt,
                    "service_or_permission_unavailable",
                )
                return@postDelayed
            }

            val keyguard = getSystemService(KeyguardManager::class.java)
            val power = getSystemService(PowerManager::class.java)
            if (chatExpanded || keyguard.isDeviceLocked || !power.isInteractive) {
                // Sleeping/locked time is not a failed input rebind attempt.
                // Defer without consuming the three real recovery attempts;
                // ACTION_USER_PRESENT or the bounded suspect watchdog resumes it.
                CompanionRuntimeState.noteOverlayCoverRecoveryDeferred(
                    sessionId,
                    "device_not_ready",
                )
                return@postDelayed
            }

            inputRecoveryInProgress = true
            CompanionRuntimeState.setOverlayRecoveryInProgress(true)
            ensureOverlayHealth(
                "bounded_cover_recovery:${reason.take(90)}:attempt_$attempt",
                rebuildInputChannel = true,
            )
            // WindowManager.addView() returns before isAttachedToWindow becomes
            // reliable on some HyperOS builds. The old code sampled attachment
            // synchronously and therefore treated a healthy replacement as
            // failed, rebuilding it up to three times per picker visit. Verify
            // only after one settle window; keep recoveryInProgress true so no
            // watchdog/Activity callback can start a competing rebuild.
            mainHandler.postDelayed({
                if (sessionId != CompanionRuntimeState.currentOverlayCoverSessionId()) {
                    inputRecoveryInProgress = false
                    CompanionRuntimeState.setOverlayRecoveryInProgress(false)
                    return@postDelayed
                }
                updateOverlayTouchHealth()
                val healthy = bubbleRoot?.isAttachedToWindow == true &&
                    CompanionRuntimeState.overlayBubbleTouchable
                CompanionRuntimeState.noteOverlayCoverRecoveryResult(
                    sessionId = sessionId,
                    attempt = attempt,
                    success = healthy,
                    reason = reason,
                )
                if (!healthy) {
                    scheduleCoverRecoveryRetry(sessionId, attempt, reason, "reattach_not_healthy")
                } else {
                    NativeEventStore.addDeviceEvent(
                        this,
                        source = "system",
                        eventType = "overlay_system_cover_recovered",
                        appPackage = packageName,
                        summary = "系统页面退出后，悬浮输入通道已重新建立。",
                        metadata = mapOf("session" to sessionId, "attempt" to attempt),
                    )
                }
                inputRecoveryInProgress = false
                CompanionRuntimeState.setOverlayRecoveryInProgress(false)
            }, INPUT_RECOVERY_SETTLE_MS)
        }, delayMs)
    }

    private fun scheduleCoverRecoveryRetry(
        sessionId: Int,
        completedAttempt: Int,
        reason: String,
        failure: String,
    ) {
        val nextAttempt = completedAttempt + 1
        if (nextAttempt > COVER_RECOVERY_MAX_ATTEMPTS) {
            CompanionRuntimeState.noteOverlayCoverRecoveryFailed(
                sessionId,
                completedAttempt,
                failure,
            )
            return
        }
        val retryDelay = COVER_RECOVERY_RETRY_DELAYS_MS[nextAttempt - 2]
        mainHandler.postDelayed({
            scheduleCoverRecovery(sessionId, nextAttempt, "$reason:$failure", retryDelay)
        }, INPUT_RECOVERY_SETTLE_MS + 100L)
    }

    private fun updateOverlayTouchHealth() {
        val bubble = bubbleRoot
        val paramsTouchable = ::bubbleParams.isInitialized &&
            bubbleParams.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE == 0
        CompanionRuntimeState.setOverlayTouchHealth(
            bubbleAttached = bubble?.isAttachedToWindow == true,
            bubbleTouchable = bubble?.isAttachedToWindow == true && paramsTouchable && bubble.isEnabled,
            positionSafe = petOverlayWindow?.isPositionSafeForHealth() ?: isBubblePositionSafe(),
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
            petOverlayWindow?.release(removeRoot = false)
            petOverlayWindow = null
            bubble?.let { runCatching { windowManager.removeViewImmediate(it) } }
            bubbleRoot = null
            repaired = createBubble()
            bubble = bubbleRoot
        } else {
            val attachedBubble = requireNotNull(bubble)
            val expectedFlags = bubbleModeFlags()
            var layoutUpdateRequired = false
            if (bubbleParams.flags != expectedFlags) {
                bubbleParams.flags = expectedFlags
                repaired = true
                layoutUpdateRequired = true
            }
            val petHost = petOverlayWindow
            if (petHost != null) {
                // PetOverlayWindow and the legacy bubble share bubbleParams.
                // Applying the bubble safe-area clamp here periodically moved a
                // docked pet inward while leaving its dockedEdge state intact.
                if (petHost.reconcileHealthPosition()) repaired = true
            } else if (clampBubbleToSafeArea()) {
                persistBubblePosition()
                repaired = true
            }
            attachedBubble.isEnabled = true
            val visible = !keyguard.isDeviceLocked
            petOverlayWindow?.setVisible(visible) ?: run {
                attachedBubble.visibility = if (visible) View.VISIBLE else View.GONE
            }
            CompanionRuntimeState.setOverlayVisible(visible)
            // Avoid periodic no-op relayouts for the pet. Some OEM WindowManager
            // implementations re-resolve negative overscan coordinates on each
            // relayout even when x/y did not change.
            if (petHost == null || layoutUpdateRequired) {
                runCatching { windowManager.updateViewLayout(attachedBubble, bubbleParams) }
                    .onFailure { repaired = true }
            }
        }

        if (repaired) {
            CompanionRuntimeState.noteOverlaySelfHeal(reason)
            NativeEventStore.addDeviceEvent(
                this,
                source = "system",
                eventType = "overlay_touch_self_healed",
                appPackage = packageName,
                summary = "悬浮入口输入通道/位置已自动恢复：${reason.take(120)}",
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
                            CompanionRuntimeState.noteBackgroundBrainReady(this)
                            backgroundEngineStartAttempts = 0
                            backgroundEngineRestartScheduled = false
                            brainWakeAttempt = 0
                            result.success(true)
                            if (petOverlayWindow != null) {
                                mainHandler.post { beginPetAutonomyPolling() }
                            }
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
            CompanionRuntimeState.noteBackgroundBrainFailure(
                this,
                "start_failed:${error.javaClass.simpleName}",
            )
            stopPetAutonomyPolling()
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
        CompanionRuntimeState.noteBackgroundBrainFailure(this, "ready_timeout")
        stopPetAutonomyPolling()
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
        if (!running || petOverlayWindow == null || !chatSending) stopGenerationPolling()
        if (!running || petOverlayWindow == null ||
            (overlayTtsPhase == "idle" && !chatSending)
        ) {
            stopTtsPolling()
        }
        updatePetConversationCue()
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

    private fun formatMessageTime(createdAt: Long): String {
        if (createdAt <= 0L) return ""
        return runCatching {
            SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(createdAt))
        }.getOrDefault("")
    }

    private fun sameLocalDay(first: Long, second: Long): Boolean {
        if (first <= 0L || second <= 0L) return false
        val format = SimpleDateFormat("yyyyMMdd", Locale.getDefault())
        return format.format(Date(first)) == format.format(Date(second))
    }

    private fun formatDateSeparator(createdAt: Long): String {
        if (createdAt <= 0L) return ""
        return runCatching {
            val target = Calendar.getInstance().apply { timeInMillis = createdAt }
            val today = Calendar.getInstance()
            val yesterday = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }
            val weekday = SimpleDateFormat("EEE", Locale.CHINA).format(target.time)
            when {
                sameLocalDay(target.timeInMillis, today.timeInMillis) -> "今天 · $weekday"
                sameLocalDay(target.timeInMillis, yesterday.timeInMillis) -> "昨天 · $weekday"
                target.get(Calendar.YEAR) == today.get(Calendar.YEAR) ->
                    "${target.get(Calendar.MONTH) + 1}月${target.get(Calendar.DAY_OF_MONTH)}日 · $weekday"
                else -> "${target.get(Calendar.YEAR)}年${target.get(Calendar.MONTH) + 1}月${target.get(Calendar.DAY_OF_MONTH)}日 · $weekday"
            }
        }.getOrDefault("")
    }

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
        val attachments: List<NativeAttachment> = emptyList(),
    )

    private data class NativeAttachment(
        val id: String,
        val kind: String,
        val thumbnailPath: String,
        val width: Int,
        val height: Int,
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
                gravity = when (message.role) {
                    "user" -> Gravity.END
                    "system_notice" -> Gravity.CENTER_HORIZONTAL
                    else -> Gravity.START
                }
                setPadding(dp(6), dp(3), dp(6), dp(3))
            }
            if (position == 0 || !sameLocalDay(
                    message.createdAt,
                    loadedMessages[position - 1].createdAt,
                )
            ) {
                outer.addView(TextView(this@OverlayBubbleService).apply {
                    text = formatDateSeparator(message.createdAt)
                    textSize = 11f
                    gravity = Gravity.CENTER
                    setTextColor(Color.rgb(176, 169, 188))
                    setPadding(dp(8), dp(7), dp(8), dp(4))
                })
            }
            if (message.role == "system_notice") {
                outer.addView(TextView(this@OverlayBubbleService).apply {
                    text = message.content
                    textSize = 11f
                    gravity = Gravity.CENTER
                    setTextColor(Color.rgb(176, 169, 188))
                    setPadding(dp(8), dp(5), dp(8), dp(5))
                })
                return outer
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
            val messageTime = formatMessageTime(message.createdAt)
            bubble.addView(TextView(this@OverlayBubbleService).apply {
                text = if (messageTime.isBlank()) label else "$label · $messageTime"
                textSize = 11f
                setTextColor(Color.rgb(188, 169, 220))
            })
            message.attachments.filter { it.kind == "image" }.forEach { attachment ->
                val bitmap = runCatching {
                    BitmapFactory.decodeFile(
                        attachment.thumbnailPath,
                        BitmapFactory.Options().apply { inSampleSize = 2 },
                    )
                }.getOrNull()
                if (bitmap != null) {
                    bubble.addView(ImageView(this@OverlayBubbleService).apply {
                        setImageBitmap(bitmap)
                        scaleType = ImageView.ScaleType.CENTER_CROP
                        adjustViewBounds = true
                        contentDescription = "聊天图片"
                    }, LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        dp(180),
                    ).apply {
                        topMargin = dp(6)
                        bottomMargin = dp(4)
                    })
                }
            }
            if (message.role == "assistant" && message.reasoning.isNotBlank()) {
                val live = message.id == STREAMING_MESSAGE_ID
                bubble.addView(smallInlineAction(if (live) "🧠 思考中" else "🧠 思考") {
                    if (!live) {
                        if (!expandedReasoning.add(message.id)) expandedReasoning.remove(message.id)
                        notifyDataSetChanged()
                    }
                })
                if (live || expandedReasoning.contains(message.id)) {
                    bubble.addView(TextView(this@OverlayBubbleService).apply {
                        text = message.reasoning
                        textSize = 12f
                        setTextColor(Color.rgb(190, 185, 202))
                        setPadding(0, dp(4), 0, dp(5))
                    })
                }
            }
            if (message.content.isNotEmpty() || message.id != STREAMING_MESSAGE_ID) {
                bubble.addView(TextView(this@OverlayBubbleService).apply {
                    text = if (message.role == "assistant") {
                        actionTintedText(message.content)
                    } else {
                        message.content
                    }
                    textSize = 15f
                    setTextColor(Color.WHITE)
                    setPadding(0, dp(3), 0, 0)
                })
            }
            if (message.role == "assistant") {
                val actions = LinearLayout(this@OverlayBubbleService).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.END
                }
                val streaming = message.id == STREAMING_MESSAGE_ID
                val ownsSpeech = overlayTtsMessageId.isNotEmpty() &&
                    overlayTtsMessageId == if (streaming) streamingAssistantMessageId else message.id
                val speechPhase = if (ownsSpeech) overlayTtsPhase else "idle"
                if (!streaming || speechPhase != "idle") {
                    actions.addView(speechAction(message.id, speechPhase, streaming))
                }
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

        private fun actionTintedText(value: String): CharSequence {
            val result = SpannableString(value)
            Regex("""（[^（）\n]*）|\([^()\n]*\)""").findAll(value).forEach { match ->
                result.setSpan(
                    ForegroundColorSpan(Color.rgb(216, 177, 255)),
                    match.range.first,
                    match.range.last + 1,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
            return result
        }

        private fun smallInlineAction(label: String, onClick: () -> Unit): TextView =
            TextView(this@OverlayBubbleService).apply {
                text = label
                textSize = 13f
                setTextColor(Color.rgb(210, 195, 235))
                gravity = Gravity.CENTER_VERTICAL
                background = rounded(Color.rgb(44, 41, 50), 9f)
                setPadding(dp(10), 0, dp(10), 0)
                minHeight = dp(30)
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(30),
                ).apply {
                    topMargin = dp(4)
                    bottomMargin = dp(2)
                }
                setOnClickListener { onClick() }
            }

        private fun speechAction(
            messageId: String,
            phase: String,
            streaming: Boolean,
        ): TextView = TextView(this@OverlayBubbleService).apply {
            gravity = Gravity.CENTER
            textSize = if (phase == "synthesizing") 20f else 15f
            setTextColor(Color.rgb(210, 195, 235))
            setPadding(dp(9), dp(4), dp(9), dp(2))
            minWidth = dp(34)
            minHeight = dp(30)
            when (phase) {
                "synthesizing" -> {
                    text = "…"
                    isEnabled = false
                }
                "playing" -> {
                    text = "■"
                    setOnClickListener { stopSpeech() }
                }
                else -> {
                    text = ""
                    setCompoundDrawablesWithIntrinsicBounds(
                        R.drawable.ic_volume_up_outlined,
                        0,
                        0,
                        0,
                    )
                    if (!streaming) {
                        setOnClickListener { speakMessage(messageId) }
                    }
                }
            }
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
            if (this !== bubbleRoot || coverWindowMutationInProgress ||
                inputRecoveryInProgress || inputRecoveryScheduled
            ) return
            if (visibility != View.VISIBLE) {
                if (!running || chatExpanded) return
                val power = getSystemService(PowerManager::class.java)
                val keyguard = getSystemService(KeyguardManager::class.java)
                if (!power.isInteractive || keyguard.isDeviceLocked) return
                visibilityWasSuppressed = true
                // Keep this root attached until it becomes visible again. This
                // is the fallback exit signal on devices where Accessibility
                // never identifies the picker package.
                handleSystemCoverEntered(
                    reason = "window_visibility_suppressed",
                    detachBubble = false,
                )
                return
            }
            if (!visibilityWasSuppressed) return
            visibilityWasSuppressed = false
            if (!running || chatExpanded) return
            val keyguard = getSystemService(KeyguardManager::class.java)
            if (!keyguard.isDeviceLocked) {
                handleSystemCoverExited("window_visibility_restored")
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
        const val ACTION_SET_PET_CONVERSATION =
            "com.aicompanion.localfirst.SET_PET_CONVERSATION"
        const val ACTION_SHOW_CHAT = "com.aicompanion.localfirst.SHOW_CHAT"
        const val ACTION_COLLAPSE_CHAT = "com.aicompanion.localfirst.COLLAPSE_CHAT"
        const val ACTION_WAKE_BRAIN = "com.aicompanion.localfirst.WAKE_BRAIN"
        const val ACTION_NOTIFICATION_REPLY = "com.aicompanion.localfirst.NOTIFICATION_REPLY"
        const val ACTION_SET_ENTRY_MODE = "com.aicompanion.localfirst.SET_ENTRY_MODE"
        const val ACTION_SET_PET_SIZE = "com.aicompanion.localfirst.SET_PET_SIZE"
        private const val ACTION_SYSTEM_COVER_ENTER =
            "com.aicompanion.localfirst.SYSTEM_COVER_ENTER"
        private const val ACTION_SYSTEM_COVER_EXIT =
            "com.aicompanion.localfirst.SYSTEM_COVER_EXIT"
        private const val INLINE_REPLY_MAX_ATTEMPTS = 5
        private const val BUBBLE_WINDOW_DP = 62
        private const val BUBBLE_AVATAR_DP = 50
        private const val BUBBLE_BADGE_DP = 20
        private const val BUBBLE_MENU_DP = 190
        private const val BUBBLE_RETRACTED_VISIBLE_DP = 24
        private const val BUBBLE_DOUBLE_TAP_SLOP_DP = 28
        private const val OVERLAY_RECENT_LIMIT = 8
        private const val OVERLAY_OLDER_PAGE_LIMIT = 24
        private const val ACTION_RECONCILE = "com.aicompanion.localfirst.RECONCILE"
        private const val EXTRA_REASON = "reason"
        private const val EXTRA_DETACH_BUBBLE = "detach_bubble"
        private const val EXTRA_ENTRY_MODE = "entry_mode"
        private const val EXTRA_PET_SIZE = "pet_size"
        const val EXTRA_COUNT = "count"
        const val EXTRA_GENERATION_ACTIVE = "generation_active"
        const val EXTRA_GENERATION_PHASE = "generation_phase"
        const val EXTRA_TTS_PHASE = "tts_phase"
        const val EXTRA_REPLY_TEXT = "reply_text"
        const val EXTRA_REPLY_ID = "reply_id"
        const val EXTRA_REPLY_TO_MESSAGE_ID = "reply_to_message_id"
        const val PREFS = "overlay_state"
        const val KEY_UNREAD = "unread"
        const val KEY_ENTRY_MODE = "entry_mode"
        const val ENTRY_MODE_BUBBLE = "bubble"
        const val ENTRY_MODE_PET = "pet"
        private const val KEY_X = "bubble_x"
        private const val KEY_Y = "bubble_y"
        private const val KEY_BUBBLE_RETRACTED = "bubble_retracted_left"
        private const val PERMISSION_WATCH_MS = 30_000L
        private const val BUBBLE_SAFE_MARGIN_DP = 6
        private const val BACKGROUND_COMMAND_CHANNEL = "ai_companion/background_commands"
        private const val BACKGROUND_READY_TIMEOUT_MS = 12_000L
        private const val GENERATION_POLL_MS = 140L
        private const val TTS_POLL_MS = 160L
        private const val PET_AUTONOMY_POLL_MS = 30_000L
        private const val PET_TTS_DISCOVERY_MS = 3_000L
        private const val STREAMING_MESSAGE_ID = "overlay:streaming"
        private const val KEY_LAST_SIGNAL_WAKE_AT = "last_signal_wake_at"
        private const val SIGNAL_WAKE_MIN_INTERVAL_MS = 90_000L
        private const val COVER_EXIT_STABLE_DELAY_MS = 1_100L
        private const val COVER_RECOVERY_WATCHDOG_DELAY_MS = 1_600L
        private const val COVER_RECOVERY_MAX_ATTEMPTS = 3
        private val COVER_RECOVERY_RETRY_DELAYS_MS = longArrayOf(1_800L, 4_000L)
        private const val INPUT_RECOVERY_SETTLE_MS = 700L

        @Volatile var running: Boolean = false
            private set

        @Volatile var backgroundBrainReady: Boolean = false
            private set

        fun startUserEnabled(context: Context) {
            CompanionRuntimeState.setOverlayUserEnabled(context, true)
            startPersistent(context, "user_enabled")
        }

        fun entryMode(context: Context): String = normalizeEntryMode(
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_ENTRY_MODE, ENTRY_MODE_BUBBLE),
        )

        fun petSize(context: Context): String = PetOverlayWindow.normalizedSize(
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(PetOverlayWindow.KEY_PET_SIZE, PetOverlayWindow.PET_SIZE_MEDIUM),
        )

        fun setEntryMode(context: Context, mode: String) {
            val normalized = normalizeEntryMode(mode)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_ENTRY_MODE, normalized)
                .apply()
            if (!running) return
            runCatching {
                context.startService(
                    Intent(context, OverlayBubbleService::class.java)
                        .setAction(ACTION_SET_ENTRY_MODE)
                        .putExtra(EXTRA_ENTRY_MODE, normalized)
                        .putExtra(EXTRA_REASON, "system_page"),
                )
            }
        }

        fun setPetSize(context: Context, size: String) {
            val normalized = PetOverlayWindow.normalizedSize(size)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(PetOverlayWindow.KEY_PET_SIZE, normalized)
                .apply()
            if (!running) return
            runCatching {
                context.startService(
                    Intent(context, OverlayBubbleService::class.java)
                        .setAction(ACTION_SET_PET_SIZE)
                        .putExtra(EXTRA_PET_SIZE, normalized)
                        .putExtra(EXTRA_REASON, "system_page"),
                )
            }
        }

        private fun normalizeEntryMode(value: String?): String =
            if (value == ENTRY_MODE_PET) ENTRY_MODE_PET else ENTRY_MODE_BUBBLE

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

        fun notifySystemCoverEntered(context: Context, reason: String): Boolean =
            sendSystemCoverTransition(
                context = context,
                action = ACTION_SYSTEM_COVER_ENTER,
                reason = reason,
                detachBubble = true,
            )

        fun notifySystemCoverExited(context: Context, reason: String): Boolean =
            sendSystemCoverTransition(
                context = context,
                action = ACTION_SYSTEM_COVER_EXIT,
                reason = reason,
                detachBubble = false,
            )

        fun requestSystemCoverRecovery(
            context: Context,
            reason: String = "window_transition",
        ): Boolean = notifySystemCoverExited(context, reason)

        private fun sendSystemCoverTransition(
            context: Context,
            action: String,
            reason: String,
            detachBubble: Boolean,
        ): Boolean {
            if (!CompanionRuntimeState.isOverlayUserEnabled(context)) return false
            if (!NativeEventStore.isActiveBrain(context)) return false
            if (!Settings.canDrawOverlays(context)) return false
            val intent = Intent(context, OverlayBubbleService::class.java)
                .setAction(action)
                .putExtra(EXTRA_REASON, reason.take(100))
                .putExtra(EXTRA_DETACH_BUBBLE, detachBubble)
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
