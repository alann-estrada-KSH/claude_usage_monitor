package com.claudeusagemonitor.claude_usage_monitor.wear

import org.json.JSONObject

object WearPayload {
    fun parse(value: String?): JSONObject? = try {
        value?.let(::JSONObject)
    } catch (_: Exception) {
        null
    }

    fun accounts(root: JSONObject?): List<JSONObject> {
        val array = root?.optJSONArray("accounts") ?: return emptyList()
        val result = mutableListOf<JSONObject>()
        for (index in 0 until array.length()) {
            val account = array.opt(index)
            if (account is JSONObject) result += account
        }
        return result
    }
}
