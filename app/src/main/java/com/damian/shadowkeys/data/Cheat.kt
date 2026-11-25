package com.damian.shadowkeys.data

data class Cheat(
    val title: String,
    val code: String,
    val category: String,
    val description: String,
    val warning: String? = null
)
