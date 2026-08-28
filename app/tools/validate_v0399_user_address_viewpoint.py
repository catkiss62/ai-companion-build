#!/usr/bin/env python3
"""Static contracts for v0.39.9 user address and viewpoint correction."""

from hashlib import sha256
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


assert re.search(r"^version:\s*(?:0\.39\.9\+127|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130)\s*$", read("pubspec.yaml"), re.M)
database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 36;" in database

rules = read("lib/core/rules/rule_layer_content_v0353.dart")
parsed = {
    key: body
    for key, body in re.findall(
        r"const ruleContentV0353_([A-Za-z0-9_]+) = r'''(.*?)''';",
        rules,
        re.S,
    )
}
expected = {
    "01_core": "168f2450de26a50e6cb09d876df348f4ec9ebaeee7c5bc05a08a856adf85307a",
    "01_relationship": "b04d3df03a60f0760b71990e2449c0300d44cb0b667569d600f35fd9a5ef9dde",
    "03_appearance_identity": "762ef524026c76cb95be4ad4b480925c5a7a4834c59b04d926846c56bdde1fe4",
    "08_runtime_identity": "83edab84d1756c3a2ca5567f314f858b647889e9a39bf25704a9e3a70112ef1d",
    "02_daily": "71636a48159cc3e4103289bff26a5ff8c0292dfde4272f9c7942da74a817a091",
    "03_behavior": "0fa391f9ac0b216ef28ec70730d2d2b192073def66a224e69a086337ae136673",
    "08_proactive_turn": "346af7ce34a46cebd32d60bcb30145872d29d5acf333cef0223578fbc0aa8c02",
    "08_visible_inner_voice": "90f809cfdc77d6050d3e3e3ce4600cb8c1b945150aa8c0572f9170ba5e077765",
    "03_personality_seed": "4047452a6e221dc7871535ceaba1748b123c86c92d61f5dedb3ad174d838b569",
    "07_base_gentle": "358e5ddfbf406ceabcfc8015b236338d953c0d790abf96da783cf9308b4aec99",
    "07_base_outgoing": "19efdc987b18a77a70ea7dba1410332fb8b283a0b28aa2ed46ecb5f987335145",
    "07_base_playful": "3e214f21d90feba092a7845d423576c5ed48e915b37e131cadc8a56afe1ace66",
    "07_base_reserved": "d6a6ffc3324b4119804a81cd9039fef51022cfcfce1e3aa7f5b41085a6ce205f",
    "07_posture_equal": "e7d3e3e82a960e834d60eabc065322d351a5c75de682248924d7418dc2fa65b7",
    "07_posture_impish": "25bbd4a0fef61c6a259b0456e2a5f70296d1d4ea6f56b18dcc93fae898a890b3",
    "07_posture_older": "98b7f344be6861729dd58209a8b5d1f1c90f1f6e663f1c4711c0f13dc1805556",
    "07_posture_younger": "7648baed4ee85b1440825561dfab7d0178851faf4178945bc02aa7f0936730d5",
    "07_profile_shared": "455fd36ef2ca753f153027a3e339d2b5b6d65c1c057d12dc7535eb34e587d804",
    "07_special_accomplice": "25b48fc56c76cc924f93c229bd763becdd012f59a1e779c5ffc0e93b2ac9e91c",
    "07_special_doll": "dde1b048bd13628553d8f9386651f09b36820202316ba3bdbc770300f705e9d4",
    "07_special_double": "2287fddbf2b7e48097b93f9e7916b27034b6335dbe62fa56054cbcf79ed9fe60",
    "07_special_hunter": "8320be99801e6d36f442b6e8869694af6183ea007871c95bbbc174283906851c",
    "07_special_seductress": "dc14121aee26264d6d9d0f1fb7a6652adac2a42a5670b134d9991523cd8f4d19",
    "07_special_shared": "7f5fda528b4b5a0c114141683446adc327b0e46ebfb279b628cdb144adc9264e",
    "07_special_sharp": "2214f33309b06973f419255f8e20ead1618f5a355abc390cfb61bd347a01c9c1",
    "07_special_yandere": "868bb7694a32600dff83e31f8450418ecbca8275abd572dcac5726c6165a8275",
    "07_special_zealot": "7227838fc5b3d8c3baa1459610523a3059f9afce5032f1062cf915447d15f5d7",
    "04_memory_rules": "8742ed82f8306383615d28a5e73216cf832c8febb03c8b70e8ef2688d51243b1",
    "04_intimacy_core": "61b9c0d15056a243ddbc4ea84c4de0cc531b9887283d9c3086d5aa256e2217f4",
    "05_intimacy_rendering": "39a531f82611bd576efe26cf83f22d33e4c374fcae02cabb999f49754ce9b997",
    "06_intimacy_reference": "88bd720f3e97769bdde8f01f4fb7c26cd334fd1368ed8ba6c62d9cb047c3d648",
}
assert set(parsed) == set(expected)
for key, digest in expected.items():
    assert sha256(parsed[key].encode()).hexdigest() == digest, key

# The only active-rule occurrence of the third-person pronoun is its literal
# appearance in the final-output forbidden-label list.
active_rules = "\n".join(parsed.values())
active_rules = active_rules.replace("其他", "").replace("他人", "")
active_rules = active_rules.replace("他、用户、玩家、男朋友、男人、男方", "")
assert "他" not in active_rules
assert "玩家" not in active_rules
assert "可见思考中，可以用“你”、名字或昵称指代用户" in parsed["02_daily"]
assert "可见思考中可以称用户为“你”、名字或昵称" in parsed["04_intimacy_core"]
assert "直接写：“她把你按在沙发上" in parsed["05_intimacy_rendering"]

immersive = read("lib/core/rules/rule_layer_content_immersive.dart")
global_rule = immersive.split("const immersiveRuleGlobal = r'''", 1)[1].split("''';", 1)[0]
raw_nsfw = immersive.split("const immersiveNsfwSource = r'''", 1)[1].split("''';", 1)[0]
effective_nsfw = raw_nsfw.replace(
    "以玩家视角为主",
    "以AI角色为叙事焦点的第二人称互动视角",
).replace("玩家", "用户")
assert sha256(global_rule.encode()).hexdigest() == "0ca68893cdee0f467d90af15a134eb7e123621df0e22cf88f35ba21cf2e10bc0"
assert sha256(effective_nsfw.encode()).hexdigest() == "a7b08166b344b949480005f27e75d11e147f5726edb606370443145280250df5"
assert "正文是连续小说文本，可以使用第三人称" not in global_rule
assert "第二人称互动视角、用户控制权" in global_rule
assert "玩家" not in effective_nsfw
assert "以AI角色为叙事焦点的第二人称互动视角" in effective_nsfw

defaults = read("lib/core/rules/rule_layer_defaults.dart")
assert "legacyEditableRuleLayerSha256V0398" in defaults
assert "immersiveNsfwSourceForPrompt(immersiveNsfwSource)" in defaults
assert "...legacyEditableRuleLayerSha256V0398.entries" in database

prompt = read("lib/core/ai/prompt_builder.dart")
personality = read("lib/core/personality/personality_catalog.dart")
somatic = read("lib/core/somatic/somatic_policy.dart")
extractor = read("lib/core/ai/memory_extractor.dart")
for source in (prompt, personality, somatic, extractor):
    sanitized = source.replace("其他", "").replace("他们", "")
    sanitized = sanitized.replace("他、用户、玩家、男方或男人", "")
    assert "他" not in sanitized
assert "可见思考提及用户时也使用“你”、名字或昵称" in prompt
assert '"text":"你刚才主动回来继续和我聊了"' in extractor

workflow = read("../.github/workflows/build-apk.yml")
for token in (
    "agent/v0399-user-address-viewpoint",
    "Build AI Companion v0.39.9+127 APK (User Address and Viewpoint Correction)",
    "python3 tools/validate_v0399_user_address_viewpoint.py",
    "AI-Companion-v0.39.9-127-User-Address-Viewpoint-APK",
    "v0.39.9-user-address-viewpoint",
):
    assert token in workflow, token

print("v0.39.9 user-address and immersive-viewpoint contracts verified")
