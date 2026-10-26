package com.aicompanion.localfirst.qq

import android.graphics.BitmapFactory
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],manifest=Config.NONE)
class QqSvgRendererTest {
    @Test fun paintsBoundedShapesPathsAndChineseWithoutAWebView() {
        val svg="""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="#ffffff"/><g transform="translate(10,10)" stroke="#000000" stroke-width="3"><circle cx="250" cy="220" r="80" fill="#aaffff"/><path d="M 60 300 Q 200 200 300 350 l 50 0 z" fill="none"/><text x="240" y="400" text-anchor="middle">鲸鱼</text></g></svg>"""
        val bytes=QqSvgRenderer.render(svg)
        val bitmap=BitmapFactory.decodeByteArray(bytes,0,bytes.size)
        assertNotNull(bitmap);assertEquals(512,bitmap.width);assertEquals(512,bitmap.height)
    }
    @Test fun rejectsExecutableExternalAndUnboundedInputs() {
        for(svg in listOf(
            "<svg><script>alert(1)</script></svg>",
            "<svg><image href='https://example.invalid/a.png'/></svg>",
            "<!DOCTYPE svg [<!ENTITY x SYSTEM 'file:///private'>]><svg>&x;</svg>",
            "<svg><rect onclick='x()'/></svg>",
            "<svg><foreignObject/></svg>",
            "<svg><use href='#x'/></svg>",
            "<svg viewBox='0 0 0.00000001 512'/>",
            "<svg><path d='M 0 0 A 10 10 0 0 0 20 20'/></svg>",
            "<svg><circle r='NaN'/></svg>",
            "<svg>"+"<g>".repeat(14)+"</g>".repeat(14)+"</svg>",
            "<svg>"+"<circle r='1'/>".repeat(230)+"</svg>"
        )) {
            try {QqSvgRenderer.render(svg);fail("accepted unsupported input: ${svg.take(80)}")}catch(_:Exception) {}
        }
    }
    @Test fun supportsRelativeCurvesButRejectsMissingAndJunkCoordinates() {
        assertTrue(QqSvgRenderer.render("<svg><path d='M 1 1 h 20 v 10 c 2 2 3 3 4 4 q 2 2 4 4 Z' fill='#abc'/></svg>").isNotEmpty())
        for(d in listOf("M 1", "M 0 0 L junk", "M 1e999 0", "M 0 0 Z 1 2")) {
            try {QqSvgRenderer.render("<svg><path d='$d'/></svg>");fail("invalid path accepted")}catch(_:Exception) {}
        }
    }
}
