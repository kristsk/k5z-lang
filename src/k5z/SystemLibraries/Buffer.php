<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

function ___Buffer_Bootstrap() {

    global $___;

    $___['buffer'] = [
        'prefix_counter' => 1,
        'insert_counter' => 0,
        'buffers' => []
    ];

    $___['volatile']['initial_thread_state']['current_buffer_name'] = NULL;
}

function ___Buffer_ProcessProgramState() {
    // Nothing.
}

function Buffer_SetCurrentForThread($thread_name, $buffer_name, $prefix = 'auto') {

    global $___;

    ___AssertThreadExists($thread_name);

    if ($buffer_name) {

        if ($buffer_name === '*') {

            $buffer_name = $prefix . \intval($___['buffer']['prefix_counter']++);
        }

        $___['threads'][$thread_name]['current_buffer_name'] = $buffer_name;

        $result = $buffer_name;
    }
    else {

        Core_Debug([$thread_name, $buffer_name, $prefix], 'Buffer name not is valid');

        Core_Error('Buffer name not is valid');

        return FALSE;
    }

    return $result;
}

function Buffer_GetCurrentForThread($thread_name) {

    global $___;

    ___AssertThreadExists($thread_name);

    return $___['threads'][$thread_name]['current_buffer_name'];
}

function Buffer_SetCurrent($buffer_name, $prefix = 'auto') {

    global $___;

    return Buffer_SetCurrentForThread($___['current_thread_name'], $buffer_name, $prefix);
}

function Buffer_GetCurrent() {

    global $___;

    return $___['current_thread']['current_buffer_name'];
}

function Buffer_GetNext($prefix = 'auto') {

    global $___;

    $next_buffer_name = $prefix . \intval($___['buffer']['prefix_counter']++);

    return $next_buffer_name;
}

function Buffer_Trash($buffer_name = FALSE) {

    global $___;

    unset($___['buffer']['buffers'][$buffer_name]);

    return TRUE;
}

function Buffer_GetItemsAndTrash($buffer_name, $default_items = FALSE) {

    $result = Buffer_GetItems($buffer_name, $default_items);

    Buffer_Trash($buffer_name);

    return $result;
}

function Buffer_AddBuffer($target_buffer_name, $source_buffer_name) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    if (!isset($___buffer_root[$source_buffer_name])) {

        $result = FALSE;
    }
    else {

        if (!isset($___buffer_root[$target_buffer_name])) {

            $target_contents = $___buffer_root[$source_buffer_name];
        }
        else {

            $target_contents = \array_merge($___buffer_root[$target_buffer_name], $___buffer_root[$source_buffer_name]);
        }

        $___buffer_root[$target_buffer_name] = $target_contents;

        $result = TRUE;
    }

    return $result;
}

function Buffer_AddBufferAndTrash($target_buffer_name, $source_buffer_name) {

    $result = Buffer_AddBuffer($target_buffer_name, $source_buffer_name);

    if ($result != FALSE) {

        Buffer_Trash($source_buffer_name);
    }

    return $result;
}

function Buffer_AddItem($buffer_name, $item) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    $___['buffer']['insert_counter']++;

    if (!isset($___buffer_root[$buffer_name])) {

        $___buffer_root[$buffer_name] = [$item];
    }
    else {

        $___buffer_root[$buffer_name][] = $item;
    }
}

function Buffer_AddItems($buffer_name, $items) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    $___['buffer']['insert_counter']++;

    if (!is_array($items)) {

        $items = [$items];
    }

    if (!isset($___buffer_root[$buffer_name])) {

        $___buffer_root[$buffer_name] = $items;
    }
    else {

        foreach ($items as $contents) {

            $___buffer_root[$buffer_name][] = $contents;
        }
    }
}

function Buffer_GetItems($buffer_name, $default_items = FALSE) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    if (\is_scalar($buffer_name) && isset($___buffer_root[$buffer_name])) {

        $result = $___buffer_root[$buffer_name];
    }
    else {

        $result = $default_items;
    }

    return $result;
}

function Buffer_IsEmpty($buffer_name) {

    global $___;

    return !isset($___['buffer']['buffers'][$buffer_name]);
}

function Buffer_SetItems($buffer_name, $items) {

    global $___;

    if (!\is_array($items)) {

        $result = FALSE;
    }
    else {

        $___['buffer']['buffers'][$buffer_name] = $items;

        $result = TRUE;
    }

    return $result;
}

function Buffer_GetItemsAsString($buffer_name, $default_items = '') {

    if (Buffer_IsEmpty($buffer_name)) {

        $items = $default_items;
    }
    else {

        $items = Buffer_GetItems($buffer_name, $default_items);
    }

    return join('', is_array($items) ? $items : []);
}

function Buffer_GetItemsAsStringAndTrash($buffer_name, $default_items = '') {

    $result = Buffer_GetItemsAsString($buffer_name, $default_items);

    Buffer_Trash($buffer_name);

    return $result;
}

function Buffer_DumpStateToDebug($title = FALSE) {

    global $___;

    Core_Debug($___['buffer'], $title ?: 'Buffer data');
}

function Buffer_DumpBufferToDebug($buffer_name, $title = FALSE) {

    global $___;

    Core_Debug(
        isset($___['buffer']['buffers'][$buffer_name]) ? $___['buffer']['buffers'][$buffer_name] : 'No such buffer',
        $title ?: 'Buffer data for ' . $buffer_name
    );
}
