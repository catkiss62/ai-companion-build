package com.aicompanion.localfirst.pet

import com.aicompanion.localfirst.CompanionRuntimeState
import android.graphics.Region
import android.view.View
import java.lang.reflect.Proxy

/** Keep the full animation buffer while publishing the smaller input region to
 * WindowManager. The internal-insets compatibility call is isolated here;
 * vendor/API failures are reported rather than changing visual scale. */
internal class PetTouchableRegion(private val view: View, private val bounds: () -> Region) {
    private var listener: Any? = null
    private var listenerType: Class<*>? = null
    var status: String = "not_attached"
        private set(value) { field = value; CompanionRuntimeState.overlayPetTouchRegion = value }

    fun attach() {
        runCatching {
            val type = Class.forName("android.view.ViewTreeObserver\$OnComputeInternalInsetsListener")
            val info = Class.forName("android.view.ViewTreeObserver\$InternalInsetsInfo")
            val regionField = info.getField("touchableRegion")
            val mode = info.getMethod("setTouchableInsets", Int::class.javaPrimitiveType)
            val proxy = Proxy.newProxyInstance(type.classLoader, arrayOf(type)) { instance, method, args ->
                when (method.name) {
                    "onComputeInternalInsets" -> {
                        runCatching {
                            val data = args!![0]
                            val region = bounds()
                            (regionField.get(data) as Region).set(region)
                            mode.invoke(data, 3) // InternalInsetsInfo.TOUCHABLE_INSETS_REGION
                            val rect = region.bounds
                            status = if (region.isEmpty) "pending_standing_bounds" else
                                "applied:${view.width}x${view.height}:${rect.left},${rect.top},${rect.right},${rect.bottom}:alpha"
                        }.onFailure { status = "failed:${it.javaClass.simpleName}" }
                        null
                    }
                    "hashCode" -> System.identityHashCode(instance)
                    "equals" -> instance === args?.get(0)
                    "toString" -> "PetTouchableRegion"
                    else -> null
                }
            }
            view.viewTreeObserver.javaClass.getMethod("addOnComputeInternalInsetsListener", type)
                .invoke(view.viewTreeObserver, proxy)
            listenerType = type
            listener = proxy
            status = "registered"
            view.requestLayout()
        }.onFailure { status = "unavailable:${it.javaClass.simpleName}" }
    }
    fun detach() {
        val proxy = listener ?: return
        runCatching {
            view.viewTreeObserver.javaClass.getMethod("removeOnComputeInternalInsetsListener", listenerType!!)
                .invoke(view.viewTreeObserver, proxy)
        }
        listener = null
        status = "not_attached"
    }
    fun refresh() { if (listener != null) view.requestLayout() }
}
