package com.aicompanion.localfirst

import org.junit.Assert.assertEquals
import org.junit.Test

class OverlayDialogueFormatterTest {
    @Test
    fun `plain reply is dialogue instead of a full italic action`() {
        val value = "回来啦。"
        assertEquals(listOf(value.indices), OverlayDialogueFormatter.dialogueRanges(value))
        assertEquals(emptyList<IntRange>(), OverlayDialogueFormatter.actionRanges(value))
    }

    @Test
    fun `legacy action delimiters are hidden without changing dialogue`() {
        val visible = OverlayDialogueFormatter.visibleText(
            "（耳鳍轻轻抖了一下）\n「才没有一直等你。」\n(尾巴晃了晃)",
        )

        assertEquals(
            "耳鳍轻轻抖了一下\n\n「才没有一直等你。」\n尾巴晃了晃",
            visible,
        )
        assertEquals(listOf(10..19), OverlayDialogueFormatter.dialogueRanges(visible))
        assertEquals(
            listOf("耳鳍轻轻抖了一下\n\n", "\n尾巴晃了晃"),
            OverlayDialogueFormatter.actionRanges(visible).map { visible.substring(it) },
        )
    }

    @Test
    fun `streaming opening action delimiter is hidden immediately`() {
        assertEquals(
            "她刚刚抬起眼",
            OverlayDialogueFormatter.visibleText("（她刚刚抬起眼"),
        )
    }

    @Test
    fun `action only reply stays action after delimiters are hidden`() {
        val source = "（尾巴轻轻晃了一下）"
        val startsWithAction = OverlayDialogueFormatter.sourceStartsWithAction(source)
        val visible = OverlayDialogueFormatter.visibleText(source)

        assertEquals("尾巴轻轻晃了一下", visible)
        assertEquals(true, startsWithAction)
        assertEquals(
            listOf(visible.indices),
            OverlayDialogueFormatter.actionRanges(visible, startsWithAction),
        )
        assertEquals(
            emptyList<IntRange>(),
            OverlayDialogueFormatter.dialogueRanges(visible, startsWithAction),
        )
    }

    @Test
    fun `nested corner quotes keep the outer dialogue range intact`() {
        val value = "动作在前\n\n「正被你那句「在干嘛呢」从刚才的坏心思里拽回来呢。」\n\n动作在后"
        assertEquals(
            listOf("「正被你那句「在干嘛呢」从刚才的坏心思里拽回来呢。」"),
            OverlayDialogueFormatter.dialogueRanges(value).map {
                value.substring(it)
            },
        )
    }

    @Test
    fun `nested quote stays dialogue while outer quote is streaming`() {
        val value = "「正被你那句「在干嘛呢」从刚才"
        assertEquals(
            listOf(value.indices),
            OverlayDialogueFormatter.dialogueRanges(value),
        )
    }
}
