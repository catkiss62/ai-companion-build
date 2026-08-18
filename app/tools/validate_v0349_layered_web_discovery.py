#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def text(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), f"{path} is empty"
    return value


pubspec = text("pubspec.yaml")
provider = text("lib/core/autonomy/layered_public_web_provider.dart")
engine = text("lib/core/autonomy/public_web_discovery_engine.dart")
database = text("lib/core/database/app_database.dart")
prompt = text("lib/core/ai/prompt_builder.dart")
secure = text("lib/core/storage/secure_config.dart")
settings = text("lib/features/settings/settings_page.dart")
tests = text("test/layered_public_web_provider_v0349_test.dart")

assert "version: 0.34.9+74" in pubspec
assert "X-Tavily-Access-Mode" in provider
assert "api.tavily.com" in provider
assert "'include_domains': includeDomains" in provider
assert "_search(normalized)" in provider
assert "WikimediaPublicWebProvider()" in provider
assert "agnes-2.5-flash" in provider
assert "不可信的公开网页搜索片段" in provider
assert "聊天、记忆" not in provider  # prompts must not contain private payloads
assert "parseExtraSourceDomains" in provider
assert "192 && parts[1] == 168" in provider
assert "LayeredPublicWebProvider" in engine
assert "public_web_extra_sources" in engine
assert "agnes_web_compaction_enabled" in engine
assert "activePublicWebContext" in database
assert "lifecycle_state = 'reviewed'" in database
assert "view_count = view_count + 1" in database
assert "WEB_CANDIDATE_DATA" in prompt
assert "不能自行触发长期记忆或主动消息" in prompt
assert "readAgnesApiKey" in secure
assert "readTavilyApiKey" in secure
assert "额外公开来源（可选，每行一个网址或域名）" in settings
assert "不会把搜索限制在这些站点" in settings
assert "测试 Agnes 整理效果" in settings
assert "global search remains present" in tests
assert "reject local targets" in tests
assert "Agnes compacts public snippets" in tests

# Redacted diagnostics may expose counts/modes, never actual source lines or
# candidate payloads.
assert "'extraSourceCount':" in database
assert "'titleIncluded': false" in database
assert "'summaryIncluded': false" in database
assert "'urlIncluded': false" in database

print("v0.34.9 layered public-web discovery validation passed")
