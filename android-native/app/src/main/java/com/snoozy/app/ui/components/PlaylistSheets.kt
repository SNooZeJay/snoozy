package com.snoozy.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import com.snoozy.app.data.model.Playlist
import io.github.neoruaa.glasmio.core.LocalGlassColors
import io.github.neoruaa.glasmio.glass.GlassEmphasis
import io.github.neoruaa.glasmio.ui.GlasmioActionSheetContent
import io.github.neoruaa.glasmio.ui.GlasmioAlertButtonLayout
import io.github.neoruaa.glasmio.ui.GlasmioAlertButtonRole
import io.github.neoruaa.glasmio.ui.GlasmioAlertButtonSpec
import io.github.neoruaa.glasmio.ui.GlasmioAlertDialog
import io.github.neoruaa.glasmio.ui.GlasmioAlertFieldGroup
import io.github.neoruaa.glasmio.ui.GlasmioAlertTextField
import io.github.neoruaa.glasmio.ui.GlasmioBottomSheet
import io.github.neoruaa.glasmio.ui.GlasmioButton
import io.github.neoruaa.glasmio.ui.GlasmioListRow

@Composable
fun PlaylistNameSheet(
    title: String,
    submitLabel: String,
    initialName: String,
    onSubmit: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf(TextFieldValue(initialName)) }
    val focusRequester = remember { FocusRequester() }
    val submit = {
        val trimmed = name.text.trim()
        if (trimmed.isNotEmpty()) {
            onSubmit(trimmed)
            onDismiss()
        }
    }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    GlasmioBottomSheet(
        visible = true,
        fitContent = true,
        onDismissRequest = onDismiss,
    ) {
        GlasmioActionSheetContent(title) {
            GlasmioAlertFieldGroup {
                GlasmioAlertTextField(
                    value = name,
                    onValueChange = { name = it },
                    placeholder = "Playlist name",
                    modifier = Modifier.focusRequester(focusRequester),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { submit() }),
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                GlasmioButton(onClick = onDismiss) {
                    Text("Cancel")
                }
                GlasmioButton(
                    onClick = submit,
                    enabled = name.text.trim().isNotEmpty(),
                    emphasis = GlassEmphasis.Prominent,
                ) {
                    Text(submitLabel)
                }
            }
        }
    }
}

@Composable
fun PlaylistActionsSheet(
    playlist: Playlist,
    onRename: () -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit,
) {
    val destructive = LocalGlassColors.current.destructive
    GlasmioBottomSheet(
        visible = true,
        fitContent = true,
        onDismissRequest = onDismiss,
    ) {
        GlasmioActionSheetContent(playlist.name, message = "Choose an action") {
            GlasmioListRow(
                title = "Rename",
                showDisclosure = false,
                onClick = {
                    onRename()
                    onDismiss()
                },
            )
            GlasmioListRow(
                title = "Delete",
                showDisclosure = false,
                titleColor = destructive,
                onClick = {
                    onDelete()
                    onDismiss()
                },
            )
            GlasmioListRow(
                title = "Cancel",
                showDisclosure = false,
                onClick = onDismiss,
            )
        }
    }
}

@Composable
fun PlaylistDeleteDialog(
    name: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    GlasmioAlertDialog(
        onDismissRequest = onDismiss,
        title = "Delete playlist?",
        message = "\"$name\" will be removed. Your songs stay in the library.",
        buttonLayout = GlasmioAlertButtonLayout.SideBySide,
        buttons = listOf(
            GlasmioAlertButtonSpec(
                label = "Cancel",
                onClick = onDismiss,
                role = GlasmioAlertButtonRole.Cancel,
            ),
            GlasmioAlertButtonSpec(
                label = "Delete",
                onClick = onConfirm,
                role = GlasmioAlertButtonRole.Destructive,
            ),
        ),
    )
}
