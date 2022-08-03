<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

/** @noinspection PhpMultipleClassesDeclarationsInOneFile */

/** @noinspection PhpUndefinedClassInspection */

class SwitchThreadException extends \Exception
{

    public $thread_name;

    public $return_value;

    public function __construct($thread_name, &$return_value) {

        parent::__construct();

        $this->thread_name = $thread_name;
        $this->return_value =& $return_value;
    }
}

/** @noinspection PhpMultipleClassesDeclarationsInOneFile */

class TerminateCurrentAndSwitchException extends SwitchThreadException
{
}

/** @noinspection PhpMultipleClassesDeclarationsInOneFile */

/** @noinspection PhpUndefinedClassInspection */

class FailedAssertionException extends \Exception
{
}

/** @noinspection PhpMultipleClassesDeclarationsInOneFile */

class MainThreadEndedException extends \Exception
{
}

function ___Core_Bootstrap() {

    global $___;

    // Whine about all errors.
    \error_reporting(E_ALL);

    // Hardcoded default limit so you do not have to restart Apache or fpm for runaways.
    \set_time_limit(10);

    $___['K5Z_PERSISTENT_DATA_KEY'] = 'k5z' . md5_file(__FILE__);

    if (!defined('K5Z_DEFAULT_THREAD_NAME')) {

        \define('K5Z_DEFAULT_THREAD_NAME', 'main');
        \define('K5Z_FUNCTION_NAME', 10);
        \define('K5Z_FUNCTION_JUMP', 11);
        \define('K5Z_FUNCTION_BREAKS', 15);
        \define('K5Z_GARBAGE', 16);
        \define('K5Z_FAST_THREAD_SWITCH_LIMIT', 10);
    }

    // Register our error handler.
    \set_error_handler(__NAMESPACE__ . '\\___ErrorHandler');

    // Register our shutdown handler.
    \register_shutdown_function(__NAMESPACE__ . '\\___ShutdownHandler');

    // Set up place for data that is used in current request scope.
    $___['volatile'] = [

        'start_time' => \microtime(TRUE),

        'libraries_with_initializers' => [],
        'program_library' => NULL,

        'suspend_program_handlers' => [],

        'configuration_data' => [],

        'initial_program_state' => [
            'debug' => ['entries' => [], 'filename' => NULL, 'mode' => 'session'],
            'threads' => [],
            'thread_counter' => 0,
            'current_thread_name' => 'main',
            'error_thread_name' => NULL,
            'stats' => []
        ],

        'initial_thread_state' => [
            'name' => NULL,
            'closure' => NULL,
            'call_stack' => [],
            'call_stack_length' => 0,
            'properties' => [],
            'previous_thread_name' => NULL,
            'started' => FALSE,
            'arguments' => [],
            'linked_threads' => [],
            'have_named_arguments' => FALSE
        ]
    ];

    ___PSM_RegisterSuspendProgramHandler(__NAMESPACE__ . '\\___Core_SuspendProgram');
}

function ___ErrorHandler($error_nr, $error_message, $error_file, $error_line) {

    $php_lines = file(__FILE__);

    $php_error_context = ['type' => $error_nr, 'filename' => $error_file, 'line' => $error_line];
    $k5z_error_context = ___PhpLineNumbersToK5zContexts($php_lines, [$error_line])[$error_line];

    Core_Debug($php_error_context, '[PHP ERROR CONTEXT]');
    Core_Debug($k5z_error_context, '[K5Z ERROR CONTEXT]');

    $trace = ___GenerateTrace(
        $php_lines,
        $error_nr == E_USER_ERROR
            ? 4
            : 1
    );

    $trace[0]['php']['file'] = __FILE__;
    $trace[0]['php']['line'] = $error_line;

    $trace[0]['k5z']['file'] = $k5z_error_context['file'];
    $trace[0]['k5z']['line'] = $k5z_error_context['line'];

    ___ErrorState(
        'internal',
        $error_message,
        [
            'error_contexts' => [
                'k5z' => $k5z_error_context,
                'php' => $php_error_context
            ],
            'trace' => $trace
        ]
    );
}

function ___GenerateTrace($php_lines, $frames_to_skip = 1) {

    $php_trace = \debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 100);

    $php_trace = \array_slice($php_trace, $frames_to_skip);

    foreach ($php_trace as &$php_trace_item) {

        $php_trace_item['line'] = isset($php_trace_item['line']) ? $php_trace_item['line'] : NULL;
        $php_trace_item['file'] = isset($php_trace_item['file']) ? $php_trace_item['file'] : NULL;
    }

    $php_line_numbers = [];
    foreach ($php_trace as $php_trace_item) {

        if ($php_trace_item['line']) {

            $php_line_numbers[] = $php_trace_item['line'];
        }
    }

    $k5z_contexts = ___PhpLineNumbersToK5zContexts($php_lines, $php_line_numbers);

    $trace = [];
    foreach ($php_trace as $php_trace_item) {

        $k5z_trace_item = [
            'file' => NULL,
            'line' => NULL,
            //'library' => null,
            //'declaration' => null
        ];

        if ($php_trace_item['file'] === __FILE__ && $php_trace_item['line']) {

            if (isset($k5z_contexts[$php_trace_item['line']])) {

                $k5z_context = $k5z_contexts[$php_trace_item['line']];

                if (!\strpos($php_trace_item['function'], '___')) {

                    $k5z_trace_item['file'] = $k5z_context['file'];
                    $k5z_trace_item['line'] = $k5z_context['line'];
                    //$k5z_trace_item['library'] = $k5z_context['library'];
                    //$k5z_trace_item['declaration'] = $k5z_declaration_names[$php_trace_item['function']];
                }
            }
            else {

                $k5z_trace_item['file'] = '-';
                $k5z_trace_item['line'] = '-';
            }
        }

        $trace[] = [
            'php' => $php_trace_item,
            'k5z' => $k5z_trace_item
        ];
    }

    return $trace;
}

function ___ShutdownHandler() {

    $error = \error_get_last();

    if ($error && $error['type'] == E_ERROR) {

        ___ErrorHandler($error['type'], $error['message'], $error['file'], $error['line']);
    }
}

function ___ErrorState($type, $message, $context) {

    global $___;

    if (\ob_get_length() !== FALSE) {
        \ob_clean();
    }

    $error_thread_name = $___['persistent']['error_thread_name'];

    if (___ThreadExists($error_thread_name)) {

        $return_value = ['type' => $type, 'message' => $message, 'context' => $context];
        ___SetCurrentThreadNameAndReturnValue($error_thread_name, $return_value);
        ___RunThread($error_thread_name);
    }
    else {

        Core_Debug($error_thread_name, 'Error thread does not exist, kicking to PSM');
        ___PSM_ErrorState($type, $message, $context);
    }

    return TRUE;
}

function ___Core_TriggerError($message) {

    trigger_error($message, E_USER_ERROR);
}

function ___Core_ProcessProgramState() {

    global $___;

    $core_time_limit = Core_GetConfigurationItem('core.time_limit', FALSE);
    if ($core_time_limit !== FALSE) {

        \set_time_limit($core_time_limit);
    }

    $should_recompile = ___ShouldRecompile();

    if ($should_recompile) {

        ___PSM_HandleModifiedProgramSource();
    }

    $current_file_m5d = \filemtime(__FILE__);

    if (isset($___['persistent']['md5'])) {

        if ($current_file_m5d != $___['persistent']['md5']) {

            ___PSM_HandleUpdatedProgramCode();
        }
    }
    else {

        $___['persistent']['md5'] = $current_file_m5d;
    }
}

function ___Core_SuspendProgram() {

    global $___;

    if (Core_GetConfigurationItem('core.stats.enabled')) {

        $___['stats']['time'] = \microtime(TRUE) - (float) $___['volatile']['start_time'];
        $___['stats']['thread_count'] = \count($___['threads']);
    }
}

function ___SetupPersistentGlobals(&$initial_program_state) {

    global $___;

    $___['persistent'] =& $initial_program_state;
    $___['threads'] =& $___['persistent']['threads'];
    $___['current_thread_name'] =& $___['persistent']['current_thread_name'];
    $___['debug'] =& $___['persistent']['debug'];
    $___['stats'] =& $___['persistent']['stats'];
}

function ___ResetProgramState() {

    global $___;

    ___SetupPersistentGlobals($___['volatile']['initial_program_state']);

    $runner_closure = ___CaptureClosure('___MainRunnerClosure', [], TRUE);

    Core_MakeNamedThread(K5Z_DEFAULT_THREAD_NAME, $runner_closure);

    ___SetCurrentThreadName(K5Z_DEFAULT_THREAD_NAME);
}

function ___MainRunnerClosure(
    /** @noinspection PhpUnusedParameterInspection */
    $___frame,
    $arguments = NULL,
    $with_named_arguments = NULL
) {

    global $___;

    $___current_thread =& $___['current_thread'];
    $___current_thread_call_stack =& $___current_thread['call_stack'];

    $___frame[K5Z_FUNCTION_NAME] = __FUNCTION__;

    $___jump =& $___frame[K5Z_FUNCTION_JUMP];
    $___garbage =& $___frame[K5Z_GARBAGE];

    $___jump = $___jump ?: 0;

    switch ($___jump) {
        case 0:
            goto l0;
        case 100:
            goto l100;
    }

    l0:
    $___frame[103] = [];
    foreach ($___['volatile']['libraries_with_initializers'] as $___frame[105]) {
        $___frame[103][] = ___CaptureClosure(($___frame[105] . '_Initialize'), [], TRUE);
    }

    $___frame[103][] = ___CaptureClosure(($___['volatile']['program_library'] . '_Main'), [], TRUE);
    // dirty FOREACH-101
    $___frame[101][0] =& $___frame[103];
    if (empty($___frame[101][0])) {
        goto l103;
    }
    $___frame[101][1] = \array_keys($___frame[101][0]);
    $___frame[101][2] = -1;
    $___frame[101][3] = \count($___frame[101][0]);
    l102:
    $___frame[101][2]++;
    $___frame[106] = $___frame[101][0][$___frame[101][1][$___frame[101][2]]];
    // CLOSINV-100
    // not garbage: 101
    // garbage: 103, 100, 106, 104, 105
    $___c =& $___frame[106];
    if (empty($___c['Ⓚ⑤Ⓩ'])) {
        $___frame[100] = $___c;
    }
    else {
        $___args = [];
        if ($___c['dirty']) {
            $___jump = 100;
            $___current_thread_call_stack[$___current_thread['call_stack_length']++] =& $___frame;
            $___garbage = [103, 100, 106, 104, 105];
            $___frame[100] = $___c['php_name']($___c['frame'], $___args, FALSE);
            unset($___current_thread_call_stack[--$___current_thread['call_stack_length']]);
        }
        else {
            $___frame[100] = \call_user_func_array($___c['php_name'], $___args);
        }
    }
    l100:
    // CLOSINV-100 ends
    if ($___frame[101][2] + 1 != $___frame[101][3]) {
        goto l102;
    }
    l103:
    // dirty FOREACH-101 ends
}

// <-- IMPORTANT! & must be used on the other end too!!!
// e.g. $data =& ___GetPersistentDataRef($thread_name);
function &___GetPersistentDataRef() {

    global $___;

    return $___['persistent'];
}

// <-- IMPORTANT! & must be used on the other end too!!!
// e.g. $data =& ___GetVolatileDataRef($thread_name);
function &___GetVolatileDataRef() {

    global $___;

    return $___['volatile'];
}

// <-- IMPORTANT! & must be used on the other end too!!!
// e.g. $threads =& ___GetThreadsRef($thread_name);
function &___GetThreadsRef() {

    global $___;

    return $___['threads'];
}

function ___ThreadExists($thread_name) {

    global $___;

    return isset($___['threads'][$thread_name]);
}

function ___AssertThreadExists($thread_name, $context = 'So that you know') {

    global $___;

    if (!isset($___['threads'][$thread_name])) {

        Core_Error($context . ' - thread "' . $thread_name . '" does not exist.');
        //throw new FailedAssertionException($context . ' - thread "' . $thread_name . '" does not exist.');
    }
}

function ___InitializeNewThread($closure, $thread_name = FALSE, $properties = []) {

    global $___;

    if ($thread_name === FALSE) {

        $thread_name = 'thread-' . intval($___['persistent']['thread_counter']);
        $___['persistent']['thread_counter'] = \intval($___['persistent']['thread_counter']) + 1;
    }

    if (isset($___['threads'][$thread_name])) {

        throw new FailedAssertionException('___InitializeNewThread - thread "' . $thread_name . '" already exists');
    }

    $thread = $___['volatile']['initial_thread_state'];

    $thread['name'] = $thread_name;
    $thread['properties'] = $properties;
    $thread['closure'] = $closure;

    $___['threads'][$thread_name] =& $thread;

    return $thread_name;
}

function ___TerminateThread($thread_name) {

    global $___;

    $thread =& $___['threads'][$thread_name];

    $linked_threads = \is_array($thread['linked_threads']) ? $thread['linked_threads'] : [];

    foreach ($linked_threads as $linked_thread_name => $dummy) {

        ___TerminateThread($linked_thread_name);
    }
    $thread['linked_threads'] = [];

    if (isset($___['threads'][$thread_name])) {

        unset($___['threads'][$thread_name]);

        if ($thread_name == K5Z_DEFAULT_THREAD_NAME) {

            $___['persistent']['main_thread_just_ended'] = TRUE;

            throw new MainThreadEndedException();
        }
    }
}

function ___GetCurrentThreadName() {

    global $___;

    return $___['current_thread_name'];
}

function ___SetCurrentThreadName($thread_name) {

    global $___;

    $___['current_thread_name'] = $thread_name;

    $___['current_thread'] =& $___['threads'][$thread_name];
}

// <-- IMPORTANT! & must be used on the other end too!!!
// e.g. $thread =& ___GetThreadRef($thread_name);
function &___GetThreadRef($thread_name) {

    global $___;

    return $___['threads'][$thread_name];
}

// <-- IMPORTANT! & must be used on the other end too!!!
// e.g. $thread =& ___GetCurrentThreadRef();
function &___GetCurrentThreadRef() {

    global $___;

    return $___['current_thread'];
}

function ___SetCurrentThreadNameAndReturnValue($thread_name, &$return_value = NULL) {

    global $___;

    $___thread =& $___['threads'][$thread_name];

    if ($___thread['started'] == FALSE) {

        $___thread['arguments'][] =& $return_value;
    }
    else {

        $last_frame =& ___GetCallStackFrameRef($thread_name, -1);

        $last_frame[$last_frame[K5Z_FUNCTION_JUMP]] =& $return_value;
    }

    ___SetCurrentThreadName($thread_name);
}

// <-- IMPORTANT! & must be used on the other end too!!!
// e.g. $thread_properties =& ___GetThreadPropertiesRef($thread_name);
function &___GetThreadPropertiesRef($thread_name) {

    global $___;

    if (isset($___['threads'][$thread_name])) {

        return $___['threads'][$thread_name]['properties'];
    }
    else {

        $empty = [];

        return $empty;
    }
}

function ___GetPreviousThreadName($thread_name) {

    global $___;

    return $___['threads'][$thread_name]['previous_thread_name'];
}

function ___SetPreviousThreadName($thread_name, $previous_thread_name) {

    global $___;

    $___['threads'][$thread_name]['previous_thread_name'] = $previous_thread_name;
}

function ___GetErrorThreadName() {

    global $___;

    return $___['persistent']['error_thread_name'];
}

function ___SetErrorThreadName($thread_name) {

    global $___;

    $___['persistent']['error_thread_name'] = $thread_name;
}

/*
    Following functions are used internally to manage K5Z thread stack data structures.
*/

// <-- IMPORTANT! & must be used on the other end too!!!
// e.g. $call_stack =& ___GetCallStack($thread_name);
function &___GetCallStack($thread_name) {

    global $___;

    return $___['threads'][$thread_name]['call_stack'];
}

// <-- IMPORTANT! & must be used on the other end too!!!
// e.g. $frame =& ___PeekCallStack($thread_name);
function &___GetCallStackFrameRef($thread_name, $index = 0) {

    global $___;

    $call_stack =& $___['threads'][$thread_name]['call_stack'];
    $call_stack_length =& $___['threads'][$thread_name]['call_stack_length'];

    if ($index < 0) {

        $index = $call_stack_length + $index;
    }

    if (isset($call_stack[$index])) {

        $frame =& $call_stack[$index];
    }
    else {

        $frame = NULL;
    }

    return $frame;
}

function ___PrependToCallStack($thread_name, $frame) {

    global $___;

    \array_unshift($___['threads'][$thread_name]['call_stack'], $frame);
}

function ___PushToCallStack($thread_name, $frame) {

    global $___;

    $___thread =& $___['threads'][$thread_name];

    $___thread['call_stack'][$___thread['call_stack_length']++] = $frame;
}

function ___PopFromCallStack($thread_name) {

    global $___;

    $___thread =& $___['threads'][$thread_name];

    return
        $___thread['call_stack_length'] != 0
            ? $___thread['call_stack'][--$___thread['call_stack_length']]
            : FALSE;
}

function ___CallStackIsEmpty($thread_name) {

    global $___;

    return $___['threads'][$thread_name]['call_stack_length'] == 0;
}

function ___CleanupGarbage($thread_name = FALSE) {

    global $___;

    if ($thread_name == FALSE) {

        $thread_name = $___['current_thread_name'];
    }

    if (isset($___['threads'][$thread_name])) {

        $call_stack =& $___['threads'][$thread_name]['call_stack'];

        foreach (\range($___['threads'][$thread_name]['call_stack_length'], \count($call_stack)) as $key) {

            unset($call_stack[$key]);
        }

        foreach ($call_stack as &$frame) {

            if (!isset($frame[K5Z_GARBAGE])) {

                continue;
            }

            foreach ($frame[K5Z_GARBAGE] as $name) {

                unset($frame[$name]);
            }

            unset($frame[K5Z_GARBAGE]);
        }
    }
}

function ___CaptureClosure($php_name, $initial_frame, $dirty) {

    if ($php_name[0] !== '\\') {

        $php_name = '\\' . __NAMESPACE__ . '\\' . $php_name;
    }

    $dummy_frame = [];
    foreach ($initial_frame as $key => &$value) {

        $dummy_frame[$key] =& $value;
    }

    return [
        'php_name' => $php_name,
        'frame' => $initial_frame,
        'dummy_frame' => $dummy_frame,
        'dirty' => $dirty,
        'Ⓚ⑤Ⓩ' => 42
    ];
}

/*
    This function starts and/or runs thread.
*/
function ___RunThread($thread_name) {

    global $___;

    //Core_DebugRaw('___RunThread START');

    $result = NULL;

    $___thread =& $___['threads'][$thread_name];

    if ($___thread['started'] == FALSE) {

        $___thread['started'] = TRUE;

        $closure =& $___thread['closure'];

        $arguments = $___thread['arguments'];
        $have_named_arguments = $___thread['have_named_arguments'];

        unset($___thread['arguments']);
        unset($___thread['have_named_arguments']);

        $result = $closure['php_name']($closure['frame'], $arguments, $have_named_arguments);
    }
    else {

        $frame = ___PopFromCallStack($thread_name);

        while (TRUE) {

            $result = $frame[K5Z_FUNCTION_NAME]($frame);

            $frame = ___PopFromCallStack($thread_name);

            if ($frame === FALSE) {

                break;
            }
            else {

                $frame[$frame[K5Z_FUNCTION_JUMP]] =& $result;
            }
        }
    }

    ___TerminateThread($thread_name);

    //Core_DebugRaw('___RunThread END');

    return $result;
}

function ___RunProgram() {

    global $___;

    $had_thread_switch = TRUE;

    $___['stats']['thread_switches'] = 0;
    $___['stats']['threads_terminated'] = 0;

    while ($had_thread_switch) {

        try {

            $had_thread_switch = FALSE;
            ___RunThread($___['current_thread_name']);
        } catch (TerminateCurrentAndSwitchException $e) {

            $___['stats']['threads_terminated']++;
            $___['stats']['thread_switches']++;

            ___TerminateThread($___['current_thread_name']);

            ___SetCurrentThreadNameAndReturnValue($e->thread_name, $e->return_value);

            $had_thread_switch = TRUE;
        } catch (SwitchThreadException $e) {

            $___['stats']['thread_switches']++;

            ___SetPreviousThreadName($e->thread_name, $___['current_thread_name']);

            ___SetCurrentThreadNameAndReturnValue($e->thread_name, $e->return_value);

            $had_thread_switch = TRUE;
        } catch (MainThreadEndedException $e) {

            ___PSM_MainThreadEnded();
        } catch (FailedAssertionException $e) {

            Core_Debug($e, 'Assert failed: ');
            Core_Error('Assert failed: ' . $e->getMessage());
        }
    }

    ___PSM_ProgramFinished();
}

function ___CheckAndAssignAE(&$array, $element) {

    if (!\is_array($array) && isset($array)) {

        return FALSE;
    }

    $array[] = $element;

    return $element;
}

function ___CheckAndAssignRefAE(&$array, &$element) {

    if (!\is_array($array) && isset($array)) {

        return FALSE;
    }
    $array[] =& $element;

    return $element;
}

function ___FindPreviousDbgsrcLine($php_lines, $current_php_line_number, array $fragments, $default) {

    $regex = '@((' . join(')|(', \array_keys($fragments)) . '))@S';

    while ($current_php_line_number > 0) {

        $php_line = $php_lines[$current_php_line_number];
        if ($php_line && \preg_match($regex, $php_line, $match) && \strpos($php_line, 'skipdbgsrc') === FALSE) {

            return $fragments[$match[1]](
                [
                    'php_line' => $php_line,
                    'current_php_line_number' => $current_php_line_number,
                    'fragment' => $match[1]
                ]
            );
        }

        $current_php_line_number--;
    }

    return $default();
}

function ___FindNextDbgsrcLine($php_lines, $current_php_line_number, array $fragments, $default) {

    $regex = '@((' . join(')|(', \array_keys($fragments)) . '))@S';

    $php_line_count = count($php_lines);

    while ($current_php_line_number <= $php_line_count) {

        $php_line = $php_lines[$current_php_line_number];
        if ($php_line && \preg_match($regex, $php_line, $match) && \strpos($php_line, 'skipdbgsrc') === FALSE) {

            return $fragments[$match[1]](
                [
                    'php_line' => $php_line,
                    'current_php_line_number' => $current_php_line_number,
                    'fragment' => $match[1]
                ]
            );
        }

        $current_php_line_number++;
    }

    return $default();
}

function ___PhpLineNumbersToK5zContexts($php_lines, $php_line_numbers) {

    global $___;

    if (!$___['___WITH_DEBUG_INFO']) {

        return array_flip($php_line_numbers);
    }

    $diver = function ($dive_context, $handlers) {

        $find_handlers = [];

        foreach ($handlers as $handler_name => $handler) {

            $find_handlers[$handler_name] = function ($find_context) use (&$dive_context, $handler) {

                $dive_context['current_php_line_number'] = $find_context['current_php_line_number'];

                return $handler($dive_context, $find_context);
            };
        }
        $default_find_handler = array_pop($find_handlers);

        return ___FindPreviousDbgsrcLine(
            $dive_context['php_lines'],
            isset($dive_context['current_php_line_number'])
                ? $dive_context['current_php_line_number']
                : $dive_context['source_php_line_number'],
            $find_handlers,
            $default_find_handler
        );
    };

    $pick_handlers = function ($handler_names) use (&$handlers) {

        $picked_handlers = [];
        foreach ($handler_names as $handler_name) {

            $picked_handlers[$handler_name] = $handlers[$handler_name];
        }

        return $picked_handlers;
    };

    /** @noinspection PhpUnusedLocalVariableInspection */
    /** @noinspection PhpUnusedParameterInspection */
    $handlers = [
        'DBGSRC:L:' => function (&$dive_context, $find_context) use ($diver, $pick_handlers) { // skipdbgsrc

            $k5z_context = $diver($dive_context, $pick_handlers(['DBGSRC:DS:', 'DBGSRC:FS:', 'DEFAULT'])); // skipdbgsrc

            \preg_match('@DBGSRC:L:(\d+):(\d+)@', $find_context['php_line'], $match); // skipdbgsrc
            $k5z_context['line'] = $match[1];
            $k5z_context['position'] = $match[2];

            $k5z_context['type'] = 'k5z';

            return $k5z_context;
        },
        'DBGSRC:IFS:' => function (&$dive_context, $find_context) use ($diver, $pick_handlers) { // skipdbgsrc

            $k5z_context = $diver($dive_context, $pick_handlers(['DBGSRC:DS:', 'DBGSRC:FS:', 'DEFAULT'])); // skipdbgsrc

            \preg_match('@DBGSRC:IFS:(.*?)\*@', $find_context['php_line'], $match); // skipdbgsrc
            $k5z_context['file'] = $match[1];

            $k5z_context['type'] = 'include';
            $k5z_context['line'] = $dive_context['source_php_line_number'] - $find_context['current_php_line_number'];

            return $k5z_context;
        },
        'DBGSRC:DS:' => function (&$dive_context, $find_context) use ($diver, $pick_handlers) { // skipdbgsrc

            $k5z_context = $diver($dive_context, $pick_handlers(['DBGSRC:FS:', 'DEFAULT'])); // skipdbgsrc

            \preg_match('@DBGSRC:DS:(.*?):@', $find_context['php_line'], $match); // skipdbgsrc
            $k5z_context['declaration'] = $match[1];

            return $k5z_context;
        },
        'DBGSRC:FS:' => function (&$dive_context, $find_context) use (&$handlers) { // skipdbgsrc

            $k5z_context = $handlers['DEFAULT']();

            \preg_match('@DBGSRC:FS:(.*?):(.*?)\*@', $find_context['php_line'], $match); // skipdbgsrc
            $k5z_context['file'] = $match[1];
            $k5z_context['library'] = $match[2];

            return $k5z_context;
        },
        'DEFAULT' => function () {

            return [
                'type' => NULL,
                'line' => NULL,
                'position' => NULL,
                'library' => NULL,
                'declaration' => NULL,
                'file' => NULL
            ];
        }
    ];

    $results = [];
    foreach ($php_line_numbers as $php_line_number) {

        if ($php_line_number === FALSE) {

            $results[] = $handlers['DEFAULT']();

            continue;
        }

        $results[$php_line_number] = $diver(
            [
                'php_lines' => $php_lines,
                'source_php_line_number' => \intval($php_line_number) - 1
            ],
            $pick_handlers(['DBGSRC:L:', 'DBGSRC:DS:', 'DBGSRC:FS:', 'DBGSRC:IFS:', 'DEFAULT'])); // skipdbgsrc
    }

    return $results;
}

function ___PhpFunctionNamesToK5zDeclarationNames($php_lines, $php_function_names) {

    global $___;

    if (!$___['___WITH_DEBUG_INFO']) {

        return [];
    }

    \preg_match_all('@\/\*DBGSRC:DS:(.*?):(.*?)\*\/@', join(',', $php_lines), $matches, PREG_SET_ORDER); // skipdbgsrc

    $fixed_php_function_names = [];
    foreach ($php_function_names as $php_function_name) {

        $parts = \explode('\\', $php_function_name);

        $fixed_php_function_names[\array_pop($parts)] = $php_function_name;
    }

    $k5z_declaration_names = \array_combine($php_function_names, $php_function_names);

    foreach ($matches as $match) {

        list(, $k5z_declaration_name, $php_function_name) = $match;

        if (isset($fixed_php_function_names[$php_function_name])) {

            $k5z_declaration_names[$fixed_php_function_names[$php_function_name]] = $k5z_declaration_name;
        }
    }

    return $k5z_declaration_names;
}

function ___ShouldRecompile() {

    global $___;

    $should_recompile = FALSE;

    if (Core_GetConfigurationItem('core.recompile.enabled', FALSE)) {

        // Compare mtimes for source and .k5z.lib files for all imported libraries and included files.
        // If any one fails test, we should recompile.

        foreach ($___['___IMPORT_AND_INCLUDE_FILES'] as $linked_library_data) {

            list(, $compiled_mtime, $source_filename, $compiled_filename) = $linked_library_data;

            if (\file_exists($source_filename)) {

                $t1 = \filemtime($source_filename);
                $t2 = \filemtime($compiled_filename);
            }
            else {

                $t1 = \filemtime($compiled_filename);
                $t2 = $compiled_mtime;
            }

            if ($t1 > $t2) {

                $should_recompile = TRUE;

                break;
            }
        }
    }

    return $should_recompile;
}

function ___Recompile() {

    global $___;

    $output = [];
    $exit_code = 0;
    $recompile_command = Core_GetConfigurationItem('core.recompile.command') . ' ' . (\substr(__FILE__, 0, -4));
    $start = \microtime(TRUE);
    $current_dir = getcwd();
    chdir(dirname(__FILE__));
    exec($recompile_command, $output, $exit_code);
    chdir($current_dir);

    $end = \microtime(TRUE);

    $compileTime = $end - $start;

    $success = TRUE;

    if ($exit_code != 0 || !empty($output)) {

        $___['persistent']['debug'] = [];

        $___['volatile']['configuration_data']['core.debug.enabled'] = TRUE;

        Core_DebugRaw('Recompile command: ' . $recompile_command);

        Core_DebugRaw('Exit code: ' . $exit_code);

        Core_DebugRaw('Time: ' . $compileTime);

        foreach ($output as $n => $line) {

            Core_DebugRaw('#' . \intval($n) . ' ' . \trim($line));
        }

        $success = FALSE;
    }

    return $success;
}

function Core_SwitchToThread(
    /** @noinspection PhpUnusedParameterInspection */
    $___frame,
    $arguments = NULL,
    $have_named_arguments = NULL
) {

    global $___;

    if ($have_named_arguments) {

        $arguments[0] =& $arguments['thread_name'];
        $arguments[1] =& $arguments['return_value'];
    }
    $next_thread_name = $arguments[0];

    if (!isset($___['threads'][$next_thread_name])) {

        throw new FailedAssertionException(__FUNCTION__ . ' - thread "' . $next_thread_name . '" does not exist.');
    }

    $return_value = NULL;

    if (isset($arguments[1])) {

        $return_value =& $arguments[1];
    }

    $___['stats']['thread_switches']++;

    if ($___['stats']['thread_switches'] <= K5Z_FAST_THREAD_SWITCH_LIMIT) {

        ___SetPreviousThreadName($next_thread_name, $___['current_thread_name']);

        ___SetCurrentThreadNameAndReturnValue($next_thread_name, $return_value);

        ___RunThread($next_thread_name);

        throw new \RuntimeException('May not return!');
    }
    else {

        throw new SwitchThreadException($next_thread_name, $return_value);
    }
}

function Core_PreviousThreadName() {

    global $___;

    return $___['current_thread']['previous_thread_name'];
}

function Core_SetPreviousThreadName($thread_name) {

    ___SetPreviousThreadName(___GetCurrentThreadName(), $thread_name);
}

function Core_SwitchToPreviousThread($___frame) {

    Core_SwitchToThread($___frame, [Core_PreviousThreadName()]);
}

function Core_TerminateThisThreadAndSwitch(
    /** @noinspection PhpUnusedParameterInspection */
    $___frame,
    $arguments = NULL,
    $have_named_arguments = NULL
) {

    global $___;

    if ($have_named_arguments) {

        $arguments[0] =& $arguments['thread_name'];
        $arguments[1] =& $arguments['return_value'];
    }
    $next_thread_name = $arguments[0];

    if (!isset($___['threads'][$next_thread_name])) {

        throw new FailedAssertionException(__FUNCTION__ . ' - thread "' . $next_thread_name . '" does not exist.');
    }

    $return_value = NULL;

    if (isset($arguments[1])) {

        $return_value =& $arguments[1];
    }

    $___['stats']['threads_terminated']++;
    $___['stats']['thread_switches']++;

    if ($___['stats']['thread_switches'] <= K5Z_FAST_THREAD_SWITCH_LIMIT) {

        ___TerminateThread($___['current_thread_name']);

        ___SetCurrentThreadNameAndReturnValue($next_thread_name, $return_value);

        ___RunThread($next_thread_name);

        throw new \RuntimeException('May not return!');
    }
    else {

        throw new TerminateCurrentAndSwitchException($next_thread_name, $return_value);
    }
}

function Core_TerminateThisThreadAndSwitchToPrevious($___frame, $arguments = NULL, $have_named_arguments = NULL) {

    if ($have_named_arguments) {

        $arguments[1] =& $arguments['return_value'];
    }
    else {

        $arguments[1] = $arguments[0];
    }

    $arguments[0] = Core_PreviousThreadName();

    Core_TerminateThisThreadAndSwitch($___frame, $arguments);
}

function Core_TerminateThread($thread_name) {

    ___AssertThreadExists($thread_name);

    ___TerminateThread($thread_name);
}

function Core_MakeThread($closure, $properties = []) {

    return Core_MakeNamedThread(FALSE, $closure, $properties);
}

function Core_MakeNamedThread($thread_name, $closure, $properties = []) {

    if ($properties === FALSE) {

        $current_thread_name = ___GetCurrentThreadName();

        if ($current_thread_name) {

            $properties = ___GetThreadPropertiesRef($current_thread_name);
        }
        else {

            $properties = [];
        }
    }

    // This weirdness ensures we will have valid thread name in case $thread_name is FALSE.
    $thread_name = ___InitializeNewThread($closure, $thread_name, $properties);

    return $thread_name;
}

function Core_LinkToThisThread($other_thread_name) {

    global $___;

    $current_thread =& $___['threads'][$___['current_thread_name']];

    $current_thread['linked_threads'][$other_thread_name] = TRUE;
}

function Core_UnlinkFromThisThread($other_thread_name) {

    global $___;

    $current_thread =& $___['threads'][$___['current_thread_name']];

    unset($current_thread['linked_threads'][$other_thread_name]);
}

function Core_SetThreadProperty($thread_name, $name, $value) {

    global $___;

    if (!isset($___['threads'][$thread_name])) {

        return FALSE;
    }

    $___['threads'][$thread_name]['properties'][$name] = $value;

    return TRUE;
}

function Core_UnSetThreadProperty($thread_name, $name) {

    global $___;

    if (!isset($___['threads'][$thread_name])) {

        return FALSE;
    }

    $properties =& $___['threads'][$thread_name]['properties'];

    if (isset($properties[$name])) {

        unset($properties[$name]);
    }

    return TRUE;
}

function Core_GetThreadProperty($thread_name, $name, $default_value) {

    global $___;

    if (!isset($___['threads'][$thread_name])) {

        return FALSE;
    }

    $properties =& $___['threads'][$thread_name]['properties'];

    if (!isset($properties[$name])) {

        return $default_value;
    }

    return $properties[$name];
}

function &Core_GetThreadPropertyRef($thread_name, $name, $default_value) {

    global $___;

    if (!isset($___['threads'][$thread_name])) {

        $false = FALSE;

        return $false;
    }

    $properties =& $___['threads'][$thread_name]['properties'];

    if (!isset($properties[$name])) {

        $properties[$name] = $default_value;
    }

    return $properties[$name];
}

function Core_IsThreadPropertySet($thread_name, $name) {

    global $___;

    if (!isset($___['threads'][$thread_name])) {

        return FALSE;
    }

    $properties =& $___['threads'][$thread_name]['properties'];

    return isset($properties[$name]);
}

function Core_GetAllThreadProperties($thread_name) {

    global $___;

    if (!isset($___['threads'][$thread_name])) {

        return FALSE;
    }

    return $___['threads'][$thread_name]['properties'];
}

function Core_UnSetCurrentThreadProperty($name) {

    global $___;

    return Core_UnSetThreadProperty($___['current_thread_name'], $name);
}

function Core_SetCurrentThreadProperty($name, $value) {

    global $___;

    return Core_SetThreadProperty($___['current_thread_name'], $name, $value);
}

function &Core_GetCurrentThreadPropertyRef($name, $default_value) {

    global $___;

    return Core_GetThreadPropertyRef($___['current_thread_name'], $name, $default_value);
}

function Core_GetCurrentThreadProperty($name, $default_value) {

    global $___;

    return Core_GetThreadProperty($___['current_thread_name'], $name, $default_value);
}

function Core_GetAllCurrentThreadProperties() {

    global $___;

    return Core_GetAllThreadProperties($___['current_thread_name']);
}

function Core_IsClosure($closure) {

    if (!($closure instanceof \DateTime) && isset($closure['Ⓚ⑤Ⓩ'])) {

        return TRUE;
    }

    return FALSE;
}

function Core_IsPlainArray($array) {

    return \is_array($array) && !isset($closure['Ⓚ⑤Ⓩ']);
}

function Core_ThisClosure(
    /** @noinspection PhpUnusedParameterInspection */
    $___frame,
    $arguments = NULL,
    $have_named_arguments = NULL
) {

    global $___;

    $current_thread =& $___['threads'][$___['current_thread_name']];

    $last_frame = $current_thread['call_stack'][$current_thread['call_stack_length'] - 1];

    $php_function_name = '\\' . $last_frame[K5Z_FUNCTION_NAME];
    unset($last_frame[K5Z_FUNCTION_JUMP], $last_frame[K5Z_FUNCTION_NAME]);

    $dummy_frame = [];
    foreach ($last_frame as $key => &$value) {

        $dummy_frame[$key] =& $value;
    }

    return [
        'php_name' => $php_function_name,
        'frame' => $last_frame,
        'dummy_frame' => $dummy_frame,
        'dirty' => TRUE,
        'Ⓚ⑤Ⓩ' => 42
    ];
}

function ___Core_WriteDebug($thread_name, $title, $message) {

    global $___;

    $core_debug_enabled = isset($___['volatile']['configuration_data']['core.debug.enabled'])
        ? $___['volatile']['configuration_data']['core.debug.enabled']
        : FALSE;

    if (!$core_debug_enabled) {

        return FALSE;
    }

    $time = \microtime(TRUE);

    $core_debug_mode = isset($___['volatile']['configuration_data']['core.debug.mode'])
        ? $___['volatile']['configuration_data']['core.debug.mode']
        : 'session';

    $___['debug']['mode'] = $core_debug_mode;

    if ($core_debug_mode === 'session') {

        $___['debug']['entries'][] = [$time, $thread_name, $title, $message];
    }
    elseif ($core_debug_mode === 'file') {

        $core_debug_filename = isset($___['volatile']['configuration_data']['core.debug.filename'])
            ? $___['volatile']['configuration_data']['core.debug.filename']
            : FALSE;

        if (!$core_debug_filename) {

            $core_debug_filename = $core_debug_filename !== TRUE ?: __FILE__ . '.log';
        }

        $___['debug']['filename'] = $core_debug_filename;

        $log_time = \date_create_from_format('U.u', $time);

        $fp = \fopen($core_debug_filename, 'a');

        \fwrite($fp,
            \date_format($log_time, '[Y-m-d H:i:s.u] ') . "\t" . $thread_name . "\t" . $title . "\t" . $message . "\n");

        \fclose($fp);
    }
    else {

        ___Core_TriggerError('___Core_WriteDebug - debug mode "' . $core_debug_mode . '" is not recognized');
    }

    return TRUE;
}

function Core_DebugRaw($message) {

    ___Core_WriteDebug(NULL, NULL, $message);
}

function Core_Debug($message, $title = '') {

    global $___;

    $core_debug_enabled = isset($___['volatile']['configuration_data']['core.debug.enabled'])
        ? $___['volatile']['configuration_data']['core.debug.enabled']
        : FALSE;

    if ($core_debug_enabled == FALSE) {

        return FALSE;
    }

    if (\is_array($message)) {

        \ob_start();
        \var_dump($message);
        $message = \ob_get_clean();
    }

    return ___Core_WriteDebug($___['current_thread_name'], $title, $message);
}

function Core_MaybeDebug($context, $message, $title = '') {

    global $___;

    $core_debug_enabled = isset($___['volatile']['configuration_data']['core.debug.enabled'])
        ? $___['volatile']['configuration_data']['core.debug.enabled']
        : FALSE;

    if ($core_debug_enabled == FALSE) {

        return FALSE;
    }

    $core_debug_context_enabled = isset($___['volatile']['configuration_data']['core.debug_contexts.' . $context])
        ? $___['volatile']['configuration_data']['core.debug_contexts.' . $context]
        : FALSE;

    if ($core_debug_context_enabled == FALSE) {

        return FALSE;
    }

    if (\is_array($message)) {

        \ob_start();
        \var_dump($message);
        $message = \ob_get_clean();
    }

    return ___Core_WriteDebug($___['current_thread_name'], $title, $message);
}

function Core_Error($message) {

    ___Core_TriggerError($message);
}

function call_user_func_fancy($function_name, $arguments = []) {

    $function_reflection = new \ReflectionFunction($function_name);
    $real_arguments = [];

    foreach ($function_reflection->getParameters() as $key => $parameter_reflection) {

        if (!$parameter_reflection->isOptional()) {

            if ($parameter_reflection->isPassedByReference()) {

                $real_arguments[$key] =& $arguments[$key];
            }
            else {

                $real_arguments[$key] = $arguments[$key];
            }
        }
        else {

            if (isset($arguments[$key])) {

                $real_arguments[$key] = $arguments[$key];
            }
            else {

                $real_arguments[$key] = $parameter_reflection->getDefaultValue();
            }
        }
    }

    return \call_user_func_array($function_name, $real_arguments);
}

function Core_GetConfigurationItem($name, $default_value = FALSE) {

    global $___;

    if (!isset($___['volatile']['configuration_data'])) {

        return $default_value;
    }

    if (!isset($___['volatile']['configuration_data'][$name])) {

        return $default_value;
    }

    return $___['volatile']['configuration_data'][$name];
}

function Core_Die() {

    Core_DebugRaw('Core_Die called!');

    die();
}

function is_empty($var) {

    return empty($var);
}

function not_empty($var) {

    return !empty($var);
}

function safe_file_get_contents($filename) {

    /** @noinspection PhpUsageOfSilenceOperatorInspection */
    return @\file_get_contents($filename);
}

function safe_file_put_contents($filename, $data) {

    /** @noinspection PhpUsageOfSilenceOperatorInspection */
    return @\file_put_contents($filename, $data);
}

function sort_array_by_integer_valued_key($array, $key) {

    usort($array, function ($a, $b) use ($key) {

        return $a[$key] - $b[$key];
    });

    return $array;
}

function generate_uuid_v4() {

    return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        \mt_rand(0, 0xffff), \mt_rand(0, 0xffff),
        \mt_rand(0, 0xffff),
        \mt_rand(0, 0x0fff) | 0x4000,
        \mt_rand(0, 0x3fff) | 0x8000,
        \mt_rand(0, 0xffff), \mt_rand(0, 0xffff), \mt_rand(0, 0xffff)
    );
}
