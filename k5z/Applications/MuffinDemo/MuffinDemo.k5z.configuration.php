<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

return [
    'javascript_links' => [
        'jquery.js' => 'https://code.jquery.com/jquery-3.2.1.min.js',
        'bootstrap.js' => 'https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/js/bootstrap.min.js',
        'popper.js' => 'https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.12.9/umd/popper.min.js'
    ],
    'css_links' => [
        'bootstrap.css' => 'https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/css/bootstrap.min.css',
    ],
    'mysql' => [
        'dsn' => 'mysql:dbname=bulkas;host=127.0.0.1',
        'user' => 'root',
        'password' => 'root'
    ],
//    'sqlite' => [
//        'dsn' => 'sqlite:./muffinator.sqlite',
//    ],
    'core.active' => TRUE,
    'core.autostart' => TRUE,
//    'core.debug.enabled' => TRUE,
    'core.stats.enabled' => TRUE,
    'core.debug.filename' => TRUE,
    'core.time_limit' => 1,
    'core.recompile.enabled' => TRUE,
    'core.recompile.command' => '/Users/kristsk/Projects/GEN5/k5z/this-k5z',
//    'xhprof.enabled' => TRUE,
//    'xhprof.path' => '/Users/kristsk/Projects/GEN5/php5-xhprof',
    'web_application.wipe_on_recompile' => TRUE,
    'web_application.dev_tools.enabled' => TRUE
];