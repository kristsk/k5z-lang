<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

function ___Xhprof_Bootstrap() {

    $enabled = Core_GetConfigurationItem('xhprof.enabled', FALSE);

    if ($enabled) {

        $xhprof_path = Core_GetConfigurationItem('xhprof.path', FALSE);

        if ($xhprof_path) {

            include_once($xhprof_path . '/xhprof_lib/utils/xhprof_lib.php');
            include_once($xhprof_path . '/xhprof_lib/utils/xhprof_runs.php');

            \xhprof_enable(XHPROF_FLAGS_CPU + XHPROF_FLAGS_MEMORY);

            ___PSM_RegisterSuspendProgramHandler(__NAMESPACE__ . '\\___Xhprof_SuspendProgram');
        }
    }
}

function ___Xhprof_SuspendProgram() {

    global $___;

    if (!___PSM_IsProgramRunning()) {

        return;
    }

    $enabled = Core_GetConfigurationItem('xhprof.enabled', FALSE);

    if ($enabled) {

        $xhprof_data = \xhprof_disable();

        /** @noinspection PhpUndefinedClassInspection */
        $xhprof_runs = new \XHProfRuns_Default();

        /** @noinspection PhpUndefinedMethodInspection */
        $run_id = $xhprof_runs->save_run($xhprof_data, '', NULL);

        $profiler_url = \sprintf('/php5-xhprof/xhprof_html/index.php?run=%s&source=%s', $run_id, '');

        $profiler_a_href = '<a href="' . $profiler_url . '">' . $profiler_url . '</a>';

        Core_Debug('', 'XHPROF ' . $profiler_a_href . ' ');

        $___['persistent']['stats']['xhprof_url'] = $profiler_a_href;
    }
}

function ___Xhprof_ProcessProgramState() {
    // Nothing.
}
