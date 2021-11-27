<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

function ___WebApplication_Bootstrap() {
}

function ___WebApplication_ProcessProgramState() {
}

if (function_exists('\http_build_url')) {

    function my_http_build_url($url, $new_parts) {

        return \http_build_url($url, $new_parts, HTTP_URL_JOIN_QUERY);
    }
}
else if (class_exists('\http\Url')) {

    function my_http_build_url($url, $new_parts) {

        $url = new \http\Url($url, $new_parts, \http\Url::JOIN_QUERY);

        return $url->toString();
    }
}
else {

    function my_http_build_url($url, $new_parts) {

        $default_schema = 'http';

        $default_ports = ['http' => 80, 'https' => 433];

        $url_parts = \parse_url($url);

        if ($url_parts === FALSE) {

            return FALSE;
        }

        if (empty($url_parts['scheme'])) {

            $url_parts['scheme'] = $default_schema;
        }

        $url_query_data = [];

        if (!empty($url_parts['query'])) {

            \parse_str($url_parts['query'], $url_query_data);
        }

        if (!empty($new_parts['query'])) {

            $url_query_data = \is_array($url_query_data)
                ? $url_query_data
                : [];

            if (!is_array($new_parts['query'])) {

                \parse_str($new_parts['query'], $new_parts_query);
            }
            else {

                $new_parts_query = $new_parts['query'];
            }

            $url_query_data = \array_merge($url_query_data, $new_parts_query);
        }

        if (!empty($new_parts['scheme'])) {

            $url_parts['scheme'] = $new_parts['scheme'];
        }

        if (!empty($new_parts['port'])) {

            $url_parts['port'] = $new_parts['port'];
        }

        if (!empty($new_parts['path'])) {

            $url_parts['path'] = $new_parts['path'];
        }

        $url_parts['path'] = preg_replace('@[/]+@', '/', $url_parts['path']);

        if (!empty($new_parts['host'])) {

            $url_parts['host'] = $new_parts['host'];
        }

        if (!empty($url_parts['port'])) {

            if (empty($default_ports[$url_parts['scheme']]) && $default_ports[$url_parts['scheme']] == $url_parts['port']) {

                unset($url_parts['port']);
            }
        }

        $url = [$url_parts['scheme'], '://', $url_parts['host']];

        if ($url_parts['port']) {

            $url[] = ':';
            $url[] = $url_parts['port'];
        }

        $url[] = $url_parts['path'];

        if (!empty($url_query_data)) {

            $url[] = '?';
            $url[] = \http_build_query($url_query_data);
        }

        return \join('', $url);
    }
}
