<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

if (isset($_REQUEST['wipe'])) {

    \session_start();
    $_SESSION = [];

    die('WIPED!');
}

if (isset($_REQUEST['wipe_and_start'])) {

    \session_start();
    $_SESSION = [];
    \session_write_close();

    ___WebApplication_RedirectToSelf('start');
}

if (strpos($_SERVER['REQUEST_URI'], 'favicon.ico') !== FALSE) {

    ob_clean();
    header('content-type: image/x-icon');
    die(base64_decode(
        "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQ" .
        "EAYAAABPYyMiAAAABmJLR0T///////8J" .
        "WPfcAAAACXBIWXMAAABIAAAASABGyWs+" .
        "AAAAF0lEQVRIx2NgGAWjYBSMglEwCkbB" .
        "SAcACBAAAeaR9cIAAAAASUVORK5CYII="
    ));
}

function ___PSM_LoadProgramState() {

    global $___;

    if (\session_id() === '') {

        \session_start();
    }

    if (isset($_REQUEST['recompile'])) {

        ___WebApplication_Recompile();
    }

    if (isset($_REQUEST['start'])) {

        ___WebApplication_ResetProgramState();

        $_SESSION[$___['K5Z_PERSISTENT_DATA_KEY']] = $___['persistent'];

        if (\ob_get_length() !== FALSE) {
            \ob_clean();
        }
        \header('Location: ' . ___WebApplication_RedirectToSelf());

        die();
    }

    if (empty($_SESSION[$___['K5Z_PERSISTENT_DATA_KEY']])) {

        if (Core_GetConfigurationItem('web_application.autostart', FALSE)) {

            ___WebApplication_RedirectToSelf('start');
        }
        else {

            die('Program is not started. Use ?start to start program. Or enable autostart.');
        }
    }

    ___SetupPersistentGlobals($_SESSION[$___['K5Z_PERSISTENT_DATA_KEY']]);

    if (isset($_REQUEST['show_debug'])) {

        ___WebApplication_DumpDebug();
    }

    if (isset($_REQUEST['clear_debug'])) {

        ___WebApplication_ClearDebug();
    }

    if (isset($_REQUEST['show_stats'])) {

        ___WebApplication_DumpStats();
    }
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

    if (Core_GetConfigurationItem('web_application.autostart', FALSE)) {

        WebApplication_Restart();
    }
    else {

        die('Program has finished. Use ?start to re-start program.');
    }
}

function ___PSM_HandleUpdatedProgramCode() {

    if (isset($_REQUEST['start']) || isset($_REQUEST['debug']) || isset($_REQUEST['recompile'])) {

        return;
    }

    if (Core_GetConfigurationItem('web_application.autostart', FALSE)) {

        ___WebApplication_RedirectToSelf('start');
    }
    else {

        die('Program code has been updated. Use ?start to start updated program.');
    }
}

function ___PSM_HandleModifiedProgramSource() {

    if (isset($_REQUEST['recompile']) || isset($_REQUEST['debug'])) {

        return;
    }

    if (Core_GetConfigurationItem('core.recompile.enabled', FALSE) == TRUE) {

        ___WebApplication_RedirectToSelf('recompile');
    }
}

function ___PSM_DetermineResumerThread() {

    ___WebApplication_DetermineResumerThread();
}

function ___PSM_IsProgramRunning() {

    global $___;

    return !empty($___['volatile']['program_is_running']);
}

function ___PSM_RunProgram() {

    global $___;

    if (isset($___['persistent']['main_thread_just_ended'])) {

        ___PSM_MainThreadEnded();
    }

    $___['volatile']['program_is_running'] = TRUE;

    Core_DebugRaw('request url: ' . $_SERVER['REQUEST_URI']);

    ___RunProgram();
}

function ___PSM_MainThreadEnded() {

    global $___;

    unset($___['persistent']['main_thread_just_ended']);

    die('Main thread ended.');
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

    // Write processing time to debug.
    Core_DebugRaw('time: ' . (\sprintf('%f', microtime(TRUE) - (float) $___['volatile']['start_time'])) . 's');

    $session_save_path = session_save_path() ?: realpath(sys_get_temp_dir());
    $session_filename = $session_save_path . '/sess_' . \session_id();
    $session_file_size = filesize($session_filename);
    Core_DebugRaw('session filename: ' . $session_filename);
    Core_DebugRaw('session size: ' . intval($session_file_size));

    foreach ($___['volatile']['suspend_program_handlers'] as $function_name) {

        $function_name();
    }

    ___PSM_StoreProgramState();

    die();
}

function ___PSM_StoreProgramState() {

    global $___;

    $stats_enabled = Core_GetConfigurationItem('core.stats.enabled');

    if ($stats_enabled) {

        $session_save_path = session_save_path() ?: realpath(sys_get_temp_dir());
        $session_filename = $session_save_path . '/sess_' . \session_id();
        $___['stats']['session_filename'] = $session_filename;
        $___['stats']['session_file_size'] = \str_repeat(' ', 20);
    }

    \session_write_close();
}

function ___PSM_ErrorState($type, $message, $context) {

    var_dump([
        'PSM ERROR STATE',
        'type' => $type,
        'message' => $message,
        'context' => $context
    ]);

    die();
}

function ___StandaloneWebApplication_Bootstrap() {

    global $___;

    // Set place where resumer thread name for will be stored.
    $___['volatile']['initial_program_state']['web_application_resumer_thread_name'] = K5Z_DEFAULT_THREAD_NAME;

    $___['volatile']['configuration_data'] = [];

    $configuration_data_filename = substr(__FILE__, 0, -4) . '.configuration.php';

    if (file_exists($configuration_data_filename) && is_readable($configuration_data_filename)) {

        //Core_Debug($configuration_data_filename, ___ConfigurationFile_Bootstrap - file not found.');

        $configuration_data = require_once($configuration_data_filename);

        if (isset($configuration_data) && is_array($configuration_data)) {

            //Core_Debug($configuration_data, ___ConfigurationFile_Bootstrap - data loaded.');
            $___['volatile']['configuration_data'] = $configuration_data;
        }
    }
}

function ___WebApplication_ResetProgramState() {

    ___ResetProgramState();
}

function ___WebApplication_RedirectToSelf($phase = NULL) {

    if (\ob_get_length() !== FALSE) {
        \ob_clean();
    }
    \header('Location: ' . $_SERVER['PHP_SELF'] . ($phase === NULL ? '' : '?' . $phase));

    die();
}

function ___WebApplication_Recompile() {

    $success = ___Recompile();

    if ($success === TRUE) {

        if (Core_GetConfigurationItem('web_application.wipe_on_recompile', FALSE)) {

            ___WebApplication_RedirectToSelf('wipe_and_start');
        }
        else {

            ___WebApplication_RedirectToSelf('start');
        }
    }
    else {

        ___WebApplication_DumpDebug();
    }
}

function ___StandaloneWebApplication_ProcessProgramState() {

    if (!___ThreadExists(K5Z_DEFAULT_THREAD_NAME)) {

        ___PSM_ProgramFinished();
    }
}

function ___WebApplication_DetermineResumerThread() {

    global $___;

    $resumer_thread_name = $___['persistent']['web_application_resumer_thread_name'];

    if (empty($resumer_thread_name)) {

        Core_DebugRaw('Resumer thread for WebSession is not set.');
        ___PSM_SuspendProgram();
    }

    ___SetCurrentThreadNameAndReturnValue($resumer_thread_name);
}

function ___WebApplication_FinalizeOutput() {

    ___PSM_SuspendProgram();
}

function ___WebApplication_DumpDebug($format = 'html') {

    global $___;

    $debug_mode = $___['debug']['mode'];

    if ($debug_mode === 'session') {

        $debug_entries = $___['debug']['entries'];
    }
    elseif ($debug_mode === 'file') {

        $debug_filename = $___['debug']['filename'];

        if (\file_exists($debug_filename) && \is_readable($debug_filename)) {

            $debug_entries = file($debug_filename);
            array_unshift($debug_entries, [NULL, '', 'Reading from debug file', $debug_filename]);
        }
        else {

            $debug_entries = [NULL, '', 'Debug file is not readable', $debug_filename];
        }
    }
    else {

        $debug_entries = [NULL, '', 'Debug mode is not recognized', $debug_mode];
    }

    if ($format === 'php') {

        \var_export($debug_entries);
    }
    else if ($format === 'text') {

        \header('Content-Type: text/plain');

        \var_dump($debug_entries);
    }
    else if ($format === 'html') {

        \header('Content-Type: text/html');
        echo('<pre>');

        foreach ($debug_entries as $key => $debug_entry) {

            if (is_string($debug_entry)) {

                $debug_entry = explode("\t", trim($debug_entry));
            }

            list( /* $time */, $thread_name, $title, $message) = $debug_entry;

            echo(\str_pad(\intval($key), 6, '0', STR_PAD_LEFT) . ' ');

            echo('<span style="color: green;">{' . $thread_name . '}</span> ');
            echo('<span style="font-weight: bold;">' . $title . ':</span> ');

            echo(\htmlspecialchars($message));

            echo("\n");
        }
    }
    else {

        echo('Wut?');
    }

    die();
}

function ___WebApplication_ClearDebug() {

    global $___;

    $___['debug']['entries'] = [];

    die();
}

function ___WebApplication_DumpStats() {

    \header('Content-Type: text/html');

    echo('<pre>');

    foreach (WebApplication_GetStats() as $name => $value) {

        echo('<span style="color: green;">' . $name . '</span>: ');

        if ($name == 'time') {
            echo(sprintf("%0.3f", $value * 1000));
            echo('ms');
        }
        else {
            echo($value);
        }

        echo('<br />');
    }

    die();
}

function WebApplication_GetStats() {

    global $___;

    if (Core_GetConfigurationItem('core.stats.enabled', FALSE)) {

        $___['stats']['session_file_size'] = \str_pad(\filesize($___['stats']['session_filename']), 20);

        return $___['stats'];
    }
    else {

        return [];
    }
}

function WebApplication_Restart() {

    ___WebApplication_RedirectToSelf('start');
}

function WebApplication_OutputBuffer($___frame, $arguments = NULL, $with_named_arguments = NULL) {

    if ($with_named_arguments) {

        $buffer_name = $arguments['buffer'];
        $headers = $arguments['headers'];
        $code = $arguments['code'];
    }
    else {

        $buffer_name = $arguments[0];
        $headers = isset($arguments[1]) ? $arguments[1] : [];
        $code = isset($arguments[2]) ? $arguments[2] : NULL;
    }

    $array = Buffer_GetItems($buffer_name);

    WebApplication_OutputArray($___frame, [$array, $headers, $code]);
}

function WebApplication_OutputArray(
    /** @noinspection PhpUnusedParameterInspection */
    $___frame,
    $arguments = NULL,
    $with_named_arguments = NULL
) {

    if ($with_named_arguments) {

        $array = $arguments['array'];
        $headers = $arguments['headers'];
        $code = $arguments['code'];
    }
    else {

        $array = $arguments[0];
        $headers = isset($arguments[1]) ? $arguments[1] : NULL;
        $code = isset($arguments[2]) ? $arguments[2] : NULL;
    }

    \ob_start();

    if ($code) {

        http_response_code($code);
    }

    if (!empty($headers)) {

        \header_remove();

        foreach ($headers as $name => $value) {

            \header($name . ': ' . $value);
        }
    }

    if (\is_array($array)) {

        foreach ($array as $value) {

            echo($value);
        }
    }

    ___WebApplication_FinalizeOutput();
}

function WebApplication_Output(
    /** @noinspection PhpUnusedParameterInspection */
    $___frame,
    $arguments = NULL,
    $with_named_arguments = NULL
) {

    if ($with_named_arguments) {

        $output = $arguments['output'];
        $headers = $arguments['headers'];
        $code = $arguments['code'];
    }
    else {

        $output = $arguments[0];
        $headers = isset($arguments[1]) ? $arguments[1] : NULL;
        $code = isset($arguments[2]) ? $arguments[2] : NULL;
    }

    \ob_start();

    if ($code) {

        http_response_code($code);
    }

    if (!empty($headers)) {

        \header_remove();

        foreach ($headers as $name => $value) {

            \header($name . ': ' . $value);
        }
    }

    echo($output);

    ___WebApplication_FinalizeOutput();
}

function WebApplication_GetRequestData($p1 = FALSE, $p2 = FALSE, $p3 = FALSE) {

    $r = ['get' => &$_GET, 'post' => &$_POST, 'cookies' => &$_COOKIE, 'files' => &$_FILES, 'server' => &$_SERVER];

    if ($p1) {

        if ($p2) {

            return isset($r[$p1][$p2]) ? $r[$p1][$p2] : $p3;
        }
        else {

            return $r[$p1];
        }
    }
    else {

        return $r;
    }
}

function WebApplication_ClearGlobals($method = FALSE, $names = FALSE) {

    if ($method == FALSE) {

        unset($_GET, $_POST, $_FILES);
    }
    else {

        $r = ['get' => &$_GET, 'post' => &$_POST, 'cookies' => &$_COOKIE, 'files' => &$_FILES];

        if (\is_array($names)) {

            foreach ($names as $name) {

                unset($r[$method][$name]);
            }
        }
        else {

            $r[$method] = [];
        }
    }
}

function WebApplication_SetCookie($key, $value, $expire = 0) {

    if (\setcookie($key, $value, $expire)) {

        $_COOKIE[$key] = $value;
    }
}

function WebApplication_GetCookie($key, $default_value = NULL) {

    return isset($_COOKIE[$key]) ? $_COOKIE[$key] : $default_value;
}

function WebApplication_SetResumerThreadName($thread_name) {

    global $___;

    $___['persistent']['web_application_resumer_thread_name'] = $thread_name;
}

function WebApplication_GetResumerThreadName() {

    global $___;

    return $___['persistent']['web_application_resumer_thread_name'];
}

function WebApplication_GetProgramUrl($query = []) {

    return my_http_build_url(
        (empty($_SERVER['HTTPS']) ? 'http' : 'https')
        . '://' . $_SERVER['SERVER_NAME']
        . ':' . $_SERVER['SERVER_PORT']
        . $_SERVER['SCRIPT_NAME'],
        ['query' => \http_build_query($query)]
    );
}
