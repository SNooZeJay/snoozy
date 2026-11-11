package com.snoozy.app.ui.components

import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp
import com.kyant.capsule.ContinuousRoundedRectangle

enum class GroupedRowPosition { Single, First, Middle, Last }

fun groupedRowPosition(index: Int, count: Int): GroupedRowPosition = when {
    count <= 1 -> GroupedRowPosition.Single
    index <= 0 -> GroupedRowPosition.First
    index >= count - 1 -> GroupedRowPosition.Last
    else -> GroupedRowPosition.Middle
}

/** Continuous 26 dp corners for a virtualized grouped list. */
fun groupedRowShape(position: GroupedRowPosition): Shape {
    val corner = 26.dp
    val none = 0.dp
    return when (position) {
        GroupedRowPosition.Single -> ContinuousRoundedRectangle(corner)
        GroupedRowPosition.First -> ContinuousRoundedRectangle(corner, corner, none, none)
        GroupedRowPosition.Middle -> ContinuousRoundedRectangle(none)
        GroupedRowPosition.Last -> ContinuousRoundedRectangle(none, none, corner, corner)
    }
}
