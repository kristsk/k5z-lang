<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

function CurrentBuffer_AddItem($item) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    $buffer_name = $___['current_thread']['current_buffer_name'];

    $___['buffer']['insert_counter']++;

    if (!isset($___buffer_root[$buffer_name])) {

        $___buffer_root[$buffer_name] = [$item];
    }
    else {

        $___buffer_root[$buffer_name][] = $item;
    }
}

function CurrentBuffer_AddItems($items) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    $buffer_name = $___['current_thread']['current_buffer_name'];

    $___['buffer']['insert_counter']++;

    if (!\is_array($items)) {

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

function CurrentBuffer_SetItems($items) {

    global $___;

    if (!\is_array($items)) {

        $result = FALSE;
    }
    else {

        $___['buffer']['buffers'][$___['current_thread']['current_buffer_name']] = $items;

        $result = TRUE;
    }

    return $result;
}

function CurrentBuffer_GetItems($default_items = FALSE) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    $buffer_name = $___['current_thread']['current_buffer_name'];

    if (\is_scalar($buffer_name) && isset($___buffer_root[$buffer_name])) {

        $result = $___buffer_root[$buffer_name];
    }
    else {

        $result = $default_items;
    }

    return $result;
}

function CurrentBuffer_GetItemsAndTrash($default_items = FALSE) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    $buffer_name = $___['current_thread']['current_buffer_name'];

    if (\is_scalar($buffer_name) && isset($___buffer_root[$buffer_name])) {

        $result = $___buffer_root[$buffer_name];
    }
    else {
        $result = $default_items;
    }

    unset($___['buffer']['buffers'][$buffer_name]);

    return $result;
}

function CurrentBuffer_AddBuffer($source_buffer_name) {

    global $___;

    $___buffer_root =& $___['buffer']['buffers'];

    if (!isset($___buffer_root[$source_buffer_name])) {

        $result = FALSE;
    }
    else {

        $current_buffer_name = $___['current_thread']['current_buffer_name'];

        if (!isset($___buffer_root[$current_buffer_name])) {

            $target_contents = $___buffer_root[$source_buffer_name];
        }
        else {

            $target_contents = \array_merge($___buffer_root[$current_buffer_name],
                $___buffer_root[$source_buffer_name]);
        }

        $___buffer_root[$current_buffer_name] = $target_contents;

        $result = TRUE;
    }

    return $result;
}

function CurrentBuffer_AddBufferAndTrash($source_buffer_name) {

    $result = CurrentBuffer_AddBuffer($source_buffer_name);

    if ($result != FALSE) {

        Buffer_Trash($source_buffer_name);
    }

    return $result;
}

function CurrentBuffer_Trash() {

    global $___;

    unset($___['buffer']['buffers'][$___['current_thread']['current_buffer_name']]);

    return TRUE;
}
