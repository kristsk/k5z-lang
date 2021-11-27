<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

function ___Embedder_Bootstrap() {
}

function ___Embedder_ProcessProgramState() {
}

function Embedder_Load($source_filename, $url, $configuration_data = []) {

    return [
        'source_filename' => $source_filename,
        'url' => $url,
        'configuration_data' => $configuration_data,
        'state' => []
    ];
}

function ___Embedder_GetEmbeddedApplicationObject($embedded_program_array) {

    $embedded = new \Kristsk\K5z\EmbeddedK5zApplication(
        $embedded_program_array['source_filename'],
        $embedded_program_array['configuration_data']
    );

    if (!empty($embedded_program_array['state'])) {

        $embedded->setProgramState($embedded_program_array['state']);
    }

    if (!empty($embedded_program_array['url'])) {

        $embedded->setProgramUrl($embedded_program_array['url']);
    }

    return $embedded;
}

function Embedder_Resume(&$embedded_program, $state, $request) {

    global $___;

    $___backup =& $___;
    unset($___);

    $embedded = ___Embedder_GetEmbeddedApplicationObject($embedded_program);
    $embedded->setProgramState($state);
    $embedded->setRequest($request);

    $embedded->resume();

    $embedded_program['state'] = $embedded->getProgramState();

    $___ =& $___backup;

    return [
        'output' => $embedded->getOutput(),
        'debug' => $embedded->getDebug(),
        'stats' => $embedded->getStats(),
        'program_state' => $embedded->getProgramState()
    ];
}

function Embedder_Start(&$embedded_program, $request) {

    global $___;

    $___backup =& $___;
    unset($___);

    $embedded = ___Embedder_GetEmbeddedApplicationObject($embedded_program);
    $embedded->setRequest($request);

    $embedded->start();

    $embedded_program['state'] = $embedded->getProgramState();

    $___ =& $___backup;

    return [
        'output' => $embedded->getOutput(),
        'debug' => $embedded->getDebug(),
        'stats' => $embedded->getStats(),
        'program_state' => $embedded->getProgramState()
    ];
}

function Embedder_IsResumable($embedded_program, $state) {

    $embedded = ___Embedder_GetEmbeddedApplicationObject($embedded_program);
    $embedded->setProgramState($state);

    return $embedded->isResumable();
}
