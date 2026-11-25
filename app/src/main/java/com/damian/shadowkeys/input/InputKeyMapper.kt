package com.damian.shadowkeys.input

object InputKeyMapper {
    fun toKeyCodes(text: String): IntArray? {
        if (text.isBlank() || !text.matches(Regex("[A-Za-z0-9]+"))) return null
        return text.uppercase().map { character ->
            when (character) {
                in 'A'..'Z' -> 29 + (character - 'A')
                in '0'..'9' -> 7 + (character - '0')
                else -> return null
            }
        }.toIntArray()
    }
}
