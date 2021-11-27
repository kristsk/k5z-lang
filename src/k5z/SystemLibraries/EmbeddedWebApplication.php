<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

/** @noinspection PhpMultipleClassesDeclarationsInOneFile */

class EmbeddedProgramSuspended extends \Exception
{
}

/** @noinspection PhpMultipleClassesDeclarationsInOneFile */

class EmbeddedProgramEnded extends \Exception
{
}

/** @noinspection PhpMultipleClassesDeclarationsInOneFile */

class EmbeddedProgramStateException extends \Exception
{
}

function ___PSM_LoadProgramState() {

    global $___;
    global $embedded;

    if ($embedded->runMode === 'start') {

        ___ResetProgramState();

        $embedded->programState = $___['persistent'];
    }

    if (empty($embedded->programState)) {

        throw new EmbeddedProgramStateException('Program not started. Use ->start() to start it.');
    }

    ___SetupPersistentGlobals($embedded->programState);
}

function ___PSM_AddStartupInitializer($library_name) {

    global $___;

    $___['volatile']['libraries_with_initializers'][] = $library_name;
}

function ___PSM_SetProgramLibrary($library_name) {

    global $___;

    $___['volatile']['program_library'] = $library_name;
}

function ___PSM_ProgramFinished() {

    global $___;

    $___['embedded']['finished'] = TRUE;
}

function ___PSM_HandleUpdatedProgramCode() {

    throw new EmbeddedProgramStateException('Program code has changed and does not match loaded program state. Please recompile manually.');
}

function ___PSM_HandleModifiedProgramSource() {

    throw new EmbeddedProgramStateException('Program source has changed. Please recompile manually.');
}

function ___PSM_DetermineResumerThread() {

    ___EmbeddedWebApplication_DetermineResumerThread();
}

function ___PSM_IsProgramRunning() {

    global $___;

    return !empty($___['volatile']['program_is_running']);
}

function ___PSM_RunProgram() {

    global $___;

    if (isset($___['persistent']['main_thread_just_ended'])) {

        unset($___['persistent']['main_thread_just_ended']);

        throw new EmbeddedProgramStateException('Program has ended.');
    }

    $___['volatile']['program_is_running'] = TRUE;

    ___RunProgram();
}

function ___PSM_RegisterSuspendProgramHandler($handler_function_name) {

    global $___;

    $___['volatile']['suspend_program_handlers'][] = $handler_function_name;
}

function ___PSM_SuspendProgram() {

    global $___;

    $___['threads'] = &___GetThreadsRef();

    foreach (\array_keys($___['threads']) as $thread_name) {

        ___CleanupGarbage($thread_name);
    }

    Core_DebugRaw('---------------------');

    // Write total processing time to debug.
    Core_DebugRaw('time: ' . (\sprintf('%f', \microtime(TRUE) - (float) $___['volatile']['start_time'])) . 's');

    foreach ($___['volatile']['suspend_program_handlers'] as $function_name) {

        $function_name();
    }

    ___PSM_StoreProgramState();

    throw new EmbeddedProgramSuspended();
}

function ___PSM_StoreProgramState() {
    // Nothing to do.
}

function ___EmbeddedWebApplication_Bootstrap() {

    global $___;
    global $embedded;

    $embedded->initial___ = $___;

    if (isset($embedded->configurationData)) {

        $___['volatile']['configuration_data'] = $embedded->configurationData;
    }

    // Set place where resumer thread name for will be stored.
    $___['volatile']['initial_program_state']['web_application_resumer_thread_name'] = K5Z_DEFAULT_THREAD_NAME;
}

function ___EmbeddedWebApplication_ProcessProgramState() {

    if (!___ThreadExists(K5Z_DEFAULT_THREAD_NAME)) {

        ___PSM_ProgramFinished();
    }
}

function ___EmbeddedWebApplication_DetermineResumerThread() {

    global $___;

    $resumer_thread_name = $___['persistent']['web_application_resumer_thread_name'];

    if (empty($resumer_thread_name)) {

        Core_DebugRaw('Resumer thread for EmbeddedWebApplication is not set.');
        ___PSM_SuspendProgram();
    }

    ___SetCurrentThreadNameAndReturnValue($resumer_thread_name);
}

function WebApplication_OutputBuffer($___frame, $arguments = NULL, $with_named_arguments = NULL) {

    if ($with_named_arguments) {

        $buffer_name = $arguments['buffer'];
        $headers = $arguments['headers'];
    }
    else {

        $buffer_name = $arguments[0];
        $headers = isset($arguments[1]) ? $arguments[1] : [];
    }

    $array = Buffer_GetContents($buffer_name);

    WebApplication_OutputArray($___frame, [$array, $headers]);
}

function WebApplication_OutputArray(
    /** @noinspection PhpUnusedParameterInspection */
    $___frame,
    $arguments = NULL,
    $with_named_arguments = NULL
) {

    global $embedded;

    if ($with_named_arguments) {

        $array = $arguments['array'];
        $headers = $arguments['headers'];
    }
    else {

        $array = $arguments[0];
        $headers = $arguments[1];
    }

    $embedded->output['headers'] = $headers;

    \ob_start();
    if (\is_array($array)) {

        foreach ($array as $value) {

            echo($value);
        }
    }
    $embedded->output['content'] = \ob_get_clean();

    ___PSM_SuspendProgram();
}

function WebApplication_Output(
    /** @noinspection PhpUnusedParameterInspection */
    $___frame,
    $arguments = NULL,
    $with_named_arguments = NULL
) {

    global $embedded;

    if ($with_named_arguments) {

        $output = $arguments['output'];
        $headers = $arguments['headers'];
    }
    else {

        $output = $arguments[0];
        $headers = $arguments[1];
    }

    $embedded->output['headers'] = $headers;

    \ob_start();
    echo($output);
    $embedded->output['content'] = \ob_get_clean();

    ___PSM_SuspendProgram();
}

function WebApplication_GetRequestData($p1 = FALSE, $p2 = FALSE, $p3 = FALSE) {

    global $embedded;

    if ($p1) {

        if ($p2) {

            return isset($embedded->request[$p1][$p2]) ? $embedded->request[$p1][$p2] : $p3;
        }
        else {

            return $embedded->request[$p1];
        }
    }
    else {

        return $embedded->request;
    }
}

function WebApplication_ClearGlobals($method = FALSE, $names = FALSE) {

    global $embedded;

    if ($method == FALSE) {

        $embedded->request = ['get' => [], 'post' => [], 'cookies' => [], 'files' => []];
    }
    else {

        if (is_array($names)) {

            foreach ($names as $name) {

                unset($embedded->request[$method][$name]);
            }
        }
        else {

            $embedded->request[$method] = [];
        }
    }
}

function WebApplication_SetCookie($key, $value, $expire = 0) {

    global $embedded;

    $embedded->cookiesSet[$key] = [$key, $value, $expire];

    if ($expire > 0 && $value) {

        $embedded->request['cookies'][$key] = $value;
    }
}

function WebApplication_GetCookie($key, $default_value = NULL) {

    global $embedded;

    return isset($embedded->request['cookies'][$key])
        ? $embedded->request['cookies'][$key]
        : $default_value;
}

function WebApplication_SetResumerThread($thread_name) {

    global $___;

    $___['persistent']['web_application_resumer_thread_name'] = $thread_name;
}

function WebApplication_GetResumerThread() {

    global $___;

    return $___['persistent']['web_application_resumer_thread_name'];
}

function WebApplication_GetProgramUrl($query = []) {

    global $embedded;

    return my_http_build_url($embedded->programUrl, ['query' => \http_build_query($query)]);
}
