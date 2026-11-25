package com.catkiss.senlive2dcompanion.smoke

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import com.aicompanion.localfirst.DownloadWorkspace
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 29)
class DownloadWorkspaceTest {
    @Test fun workingFilesKeepTheirNamesAndReopenFromDownloads() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        fun reopen() = DownloadWorkspace(ctx.contentResolver, ctx.packageName)
        val id = UUID.randomUUID().toString()
        val names = listOf("任务-$id.json", "报告-$id.md", "作品-${id.replace("-", "").repeat(2)}.html")
        for (name in names) {
            val work = reopen()
            try {
                work.handle("workTreeWrite", name, "第一次写入")
                assertTrue((work.handle("workTreeList", null, null) as List<*>).contains(name))
                assertEquals("第一次写入", reopen().handle("workTreeRead", name, null))
                work.handle("workTreeWrite", name, "短")
                assertEquals("短", reopen().handle("workTreeRead", name, null))
            } finally {
                if ((work.handle("workTreeList", null, null) as List<*>).contains(name)) {
                    work.handle("workTreeDelete", name, null)
                }
            }
            assertTrue(!(work.handle("workTreeList", null, null) as List<*>).contains(name))
        }
    }
}
