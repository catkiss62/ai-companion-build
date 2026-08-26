package com.aicompanion.localfirst

import org.junit.Assert.assertEquals
import org.junit.Test

class OverlayDialogueFormatterTest {
    @Test
    fun `legacy action delimiters are hidden without changing dialogue`() {
        val visible = OverlayDialogueFormatter.visibleText(
            "（耳鳍轻轻抖了一下）\n「才没有一直等你。」\n(尾巴晃了晃)",
        )

        assertEquals(
            "耳鳍轻轻抖了一下\n「才没有一直等你。」\n尾巴晃了晃",
            visible,
        )
        assertEquals(listOf(9..18), OverlayDialogueFormatter.dialogueRanges(visible))
    }

    @Test
    fun `streaming opening action delimiter is hidden immediately`() {
        assertEquals(
            "她刚刚抬起眼",
            OverlayDialogueFormatter.visibleText("（她刚刚抬起眼"),
        )
    }
}
