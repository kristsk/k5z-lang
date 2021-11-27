<?php
// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

function ___Pdo_Bootstrap() {

    global $___;

    $___['volatile']['initial_program_state']['pdo'] = [
        'connections' => [],
        'statements' => [],
        'error_on_failure' => FALSE,
        'last_k5z_connection_id' => NULL,
        'last_error' => NULL
    ];

    ___PSM_RegisterSuspendProgramHandler(__NAMESPACE__ . '\\___Pdo_SuspendProgram');
}

function ___Pdo_SuspendProgram() {

    global $___;

    foreach ($___['persistent']['pdo']['connections'] as &$connection) {

        unset($connection['pdo_connection']);
    }

    foreach ($___['persistent']['pdo']['statements'] as &$statement) {

        unset($statement['pdo_statement']);
    }
}

function ___Pdo_ProcessProgramState() {
}

function ___Pdo_GetInternalConnection($k5z_connection_id) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    if ($k5z_connection_id === TRUE && $___pdo['last_k5z_connection_id']) {

        $k5z_connection_id = $___pdo['last_k5z_connection_id'];
    }

    if (!$k5z_connection_id) {

        return FALSE;
    }

    $internal_connection = $___pdo['connections'][$k5z_connection_id];

    if (!$internal_connection) {

        return FALSE;
    }

    if (!isset($internal_connection['pdo_connection'])) {

        if (isset($internal_connection['configuration_item_name'])) {

            $internal_connection = ___Pdo_ConnectFromConfigurationItem(
                $internal_connection['configuration_item_name'],
                $internal_connection
            );
        }
        else {

            $internal_connection = ___Pdo_Connect(
                $internal_connection['dsn'],
                $internal_connection['user'],
                $internal_connection['password'],
                $internal_connection
            );
        }

        ___Pdo_SetInternalConnection($internal_connection);
    }

    return $internal_connection;
}

function ___Pdo_RemoveInternalConnection($k5z_connection_id) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    if (!$k5z_connection_id) {

        return FALSE;
    }

    unset($___pdo['connections'][$k5z_connection_id]);

    $last_k5z_connection_id =& $___pdo['last_k5z_connection_id'];

    if ($last_k5z_connection_id == $k5z_connection_id) {

        $last_k5z_connection_id = NULL;
    }

    return TRUE;
}

function ___Pdo_SetInternalConnection(&$internal_connection) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    if (!is_array($internal_connection)) {

        return FALSE;
    }

    //Core_Debug(print_r($connection, TRUE), '_Pdo_SetConnection - connection');

    $k5z_connection_id =& $internal_connection['k5z_connection_id'];

    if (!$k5z_connection_id) {

        $k5z_connection_id = \uniqid('pdocn');
    }

    $___pdo['connections'][$k5z_connection_id] = $internal_connection;

    $___pdo['last_k5z_connection_id'] = $k5z_connection_id;

    return $k5z_connection_id;
}

function ___Pdo_GetInternalStatement($k5z_statement_id) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    if (!$k5z_statement_id) {

        return FALSE;
    }

    $internal_statement =& $___pdo['statements'][$k5z_statement_id];

    if (!$internal_statement) {

        return FALSE;
    }

    if (!isset($internal_statement['pdo_statement'])) {

        $internal_statement = ___Pdo_Query(
            $internal_statement['sql'],
            $internal_statement['params'],
            $internal_statement['k5z_connection_id'],
            $internal_statement
        );

        $pdo_statement = $internal_statement['pdo_statement'];
        /* @var $pdo_statement \PdoStatement */

        $counter = 0;
        while ($counter != $internal_statement['position']) {

            $pdo_statement->fetch();
            $counter++;
        }

        ___Pdo_SetInternalStatement($internal_statement);
    }

    return $internal_statement;
}

function ___Pdo_RemoveInternalStatement($k5z_statement_id) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    if (!$k5z_statement_id) {

        return FALSE;
    }

    unset($___pdo['statements'][$k5z_statement_id]);

    return TRUE;
}

function ___Pdo_SetInternalStatement(&$internal_statement) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    if (!is_array($internal_statement)) {

        return FALSE;
    }

    $k5z_statement_id = &$internal_statement['k5z_statement_id'];

    if (!$k5z_statement_id) {

        $k5z_statement_id = \uniqid('pdoqr');
    }

    $___pdo['statements'][$k5z_statement_id] = $internal_statement;

    return $k5z_statement_id;
}

/**
 * @param string $sql
 * @param array $params
 * @param bool|string $k5z_connection_id
 * @return bool|\PDOStatement
 */
function ___Pdo_ExecuteStatement($sql, $params = [], $k5z_connection_id = TRUE) {

    global $___;

    $internal_connection = ___Pdo_GetInternalConnection($k5z_connection_id);

    if ($internal_connection == FALSE) {

        Core_Debug('___Pdo_ExecuteStatement - no connection');

        return FALSE;
    }

    $pdo_connection =& $internal_connection['pdo_connection'];
    /* @var $pdo_connection \PDO */

    $statement = $pdo_connection->prepare($sql);

    try {

        $statement->execute($params);
        ___Pdo_SetLastError(FALSE, $internal_connection);
    } catch (\PDOException $e) {

        $___pdo =& $___['persistent']['pdo'];

        if ($___pdo['error_on_failure']) {

            ___Core_TriggerError('___Pdo_ExecuteStatement - did not succeed, exception message: ' . $e->getMessage());
        }
        else {

            Core_Debug($e->getMessage(), '___Pdo_ExecuteStatement - did not succeed, exception message');
            ___Pdo_SetLastError($e->getMessage(), $internal_connection);
        }
    }

    ___Pdo_SetInternalConnection($internal_connection);

    return $statement;
}

function ___Pdo_SetLastError($error_message, &$internal_connection = FALSE) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    if ($internal_connection === FALSE) {

        $___pdo['last_error'] = $error_message;
    }
    else {

        $___pdo['last_error'] = FALSE;
        $internal_connection['last_error'] = $error_message;
    }
}

function ___Pdo_GetLastError($internal_connection = FALSE) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    $last_error = '';

    if ($___pdo['last_error']) {

        $last_error = $___pdo['last_error'];
    }
    elseif ($internal_connection) {

        $last_error = $internal_connection['last_error'];
    }

    return $last_error;
}

function ___Pdo_Connect($dsn, $user, $password, $internal_connection = []) {

    global $___;

    try {

        $pdo_connection = new \PDO(
            $dsn,
            $user,
            $password,
            [\PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION]
        );
    } catch (\PDOException $e) {

        $___pdo =& $___['persistent']['pdo'];

        if ($___pdo['error_on_failure']) {

            ___Core_TriggerError('___Pdo_Connect - could not connect: ' . $e->getMessage());
        }
        else {

            ___Pdo_SetLastError($e->getMessage());
            Core_Debug($e->getMessage(), '___Pdo_Connect - could not connect');
        }

        return FALSE;
    }

    $new_internal_connection = [
        'dsn' => $dsn,
        'user' => $user,
        'password' => $password,
        'pdo_connection' => $pdo_connection
    ];

    if ($internal_connection) {

        $new_internal_connection = \array_merge($new_internal_connection, $internal_connection);
    }

    return $new_internal_connection;
}

function Pdo_Connect($dsn, $user, $password) {

    $internal_connection = ___Pdo_Connect($dsn, $user, $password);

    return ___Pdo_SetInternalConnection($internal_connection);
}

function Pdo_Disconnect($k5z_connection_id = TRUE) {

    $internal_connection = ___Pdo_GetInternalConnection($k5z_connection_id);

    if ($internal_connection == FALSE) {

        Core_Debug('Pdo_Disconnect - no connection');

        return FALSE;
    }

    ___Pdo_RemoveInternalConnection($k5z_connection_id);

    return TRUE;
}

function Pdo_FreeResult($k5z_statement_id) {

    $internal_statement = ___Pdo_GetInternalStatement($k5z_statement_id);

    if ($internal_statement == FALSE) {

        return FALSE;
    }

    ___Pdo_RemoveInternalStatement($k5z_statement_id);

    return TRUE;
}

function ___Pdo_Query($sql, $params = [], $k5z_connection_id = TRUE, $internal_statement = []) {

    $pdo_statement = ___Pdo_ExecuteStatement($sql, $params, $k5z_connection_id);

    if ($pdo_statement === FALSE) {

        return FALSE;
    }

    if (strtoupper(substr($sql, 0, 6)) === 'SELECT') {

        $new_internal_statement = [
            'sql' => $sql,
            'params' => $params,
            'k5z_connection_id' => $k5z_connection_id,
            'pdo_statement' => $pdo_statement,
            'position' => 0,
            'number_of_rows' => $pdo_statement->rowCount()
        ];
    }
    else {

        $new_internal_statement = [
            'do_not_restore' => TRUE,
            'pdo_statement' => $pdo_statement
        ];
    }

    if ($internal_statement) {

        $new_internal_statement = \array_merge($new_internal_statement, $internal_statement);
    }

    return $new_internal_statement;
}

function Pdo_Query($sql, $params = [], $k5z_connection_id = TRUE) {

    $internal_statement = ___Pdo_Query($sql, $params, $k5z_connection_id);

    return ___Pdo_SetInternalStatement($internal_statement);
}

function Pdo_FetchAssociativeArray($k5z_statement_id) {

    $internal_statement = ___Pdo_GetInternalStatement($k5z_statement_id);

    if ($internal_statement == FALSE) {

        return FALSE;
    }

    if ($internal_statement['position'] > ($internal_statement['number_of_rows'] - 1)) {

        return FALSE;
    }

    $pdo_statement = $internal_statement['pdo_statement'];
    /* @var $pdo_statement \PDOStatement */

    $result = $pdo_statement->fetch(\PDO::FETCH_ASSOC);

    if (!is_array($result)) {

        return FALSE;
    }

    $internal_statement['position']++;

    ___Pdo_SetInternalStatement($internal_statement);

    return $result;
}

function Pdo_LastError($k5z_connection_id = FALSE) {

    if ($k5z_connection_id != FALSE) {

        $internal_connection = ___Pdo_GetInternalConnection($k5z_connection_id);
    }
    else {

        $internal_connection = FALSE;
    }

    return ___Pdo_GetLastError($internal_connection);
}

function Pdo_NumberOfRows($k5z_statement_id) {

    $internal_statement = ___Pdo_GetInternalStatement($k5z_statement_id);

    if ($internal_statement == FALSE) {

        return FALSE;
    }

    return $internal_statement['number_of_rows'];
}

function ___Pdo_ConnectFromConfigurationItem($configuration_item_name, $internal_connection = []) {

    $configuration_item = Core_GetConfigurationItem($configuration_item_name, FALSE);

    if ($configuration_item == FALSE) {

        Core_Debug('___Pdo_ConnectFromConfigurationItem - configuration item not present');

        return FALSE;
    }

    if (
        !isset($configuration_item['dsn']) ||
        !isset($configuration_item['user']) ||
        !isset($configuration_item['password'])
    ) {

        Core_Debug('___Pdo_ConnectFromConfigurationItem - something is not set');

        return FALSE;
    }

    $dsn = $configuration_item['dsn'];
    $user = $configuration_item['user'];
    $password = $configuration_item['password'];

    try {

        $pdo_connection = new \PDO(
            $dsn,
            $user,
            $password,
            [\PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION]
        );
    } catch (\PDOException $e) {

        Core_Debug($e->getMessage(), '___Pdo_ConnectFromConfigurationItem - could not connect:');

        return FALSE;
    }

    $new_internal_connection = [
        'configuration_item_name' => $configuration_item_name,
        'pdo_connection' => $pdo_connection
    ];

    if ($internal_connection) {

        $new_internal_connection = \array_merge($new_internal_connection, $internal_connection);
    }

    return $new_internal_connection;
}

function Pdo_ConnectFromConfigurationItem($configuration_item_name) {

    $internal_connection = ___Pdo_ConnectFromConfigurationItem($configuration_item_name);

    return ___Pdo_SetInternalConnection($internal_connection);
}

function Pdo_LastInsertId($k5z_connection_id = TRUE) {

    $internal_connection = ___Pdo_GetInternalConnection($k5z_connection_id);

    if ($internal_connection == FALSE) {

        Core_Debug('Pdo_LastInsertId - no connection');

        return FALSE;
    }

    $pdo_connection = $internal_connection['pdo_connection'];
    /* @var $pdo_connection \PDO */

    $last_insert_id = $pdo_connection->lastInsertId();

    return $last_insert_id;
}

function Pdo_DoSelect($sql, $params = [], $k5z_connection_id = TRUE) {

    $pdo_statement = ___Pdo_ExecuteStatement($sql, $params, $k5z_connection_id);

    if ($pdo_statement == FALSE) {

        return FALSE;
    }

    $result = [];

    $row = $pdo_statement->fetch(\PDO::FETCH_ASSOC);

    if ($row == FALSE) {

        $pdo_statement->closeCursor();

        return [];
    }

    if (isset($row['___key'])) {

        if (isset($row['___value'])) {

            $result[$row['___key']] = $row['___value'];

            $num_count = $pdo_statement->rowCount() - 1;

            for ($i = 0; $i != $num_count; $i++) {

                $row = $pdo_statement->fetch(\PDO::FETCH_ASSOC);
                $result[$row['___key']] = $row['___value'];
            }
        }
        else {

            $result[$row['___key']] = $row;

            $num_count = $pdo_statement->rowCount() - 1;

            for ($i = 0; $i != $num_count; $i++) {

                $row = $pdo_statement->fetch(\PDO::FETCH_ASSOC);
                $result[$row['___key']] = $row;
            }
        }
    }
    elseif (isset($row['___pack'])) {

        $result[] = $row['___pack'];

        /** @noinspection PhpAssignmentInConditionInspection */
        while ($row = $pdo_statement->fetch(\PDO::FETCH_ASSOC)) {

            $result[] = $row['___pack'];
        }
    }
    else {

        $result[] = $row;
        /** @noinspection PhpAssignmentInConditionInspection */
        while ($row = $pdo_statement->fetch(\PDO::FETCH_ASSOC)) {

            $result[] = $row;
        }
    }

    $pdo_statement->closeCursor();

    return $result;
}

function Pdo_DoSelectRow($sql, $params = [], $k5z_connection = TRUE) {

    $pdo_statement = ___Pdo_ExecuteStatement($sql, $params, $k5z_connection);

    if (!$pdo_statement) {

        return FALSE;
    }

    if ($pdo_statement->rowCount() == 0) {

        $pdo_statement->closeCursor();

        return [];
    }

    $result = $pdo_statement->fetch(\PDO::FETCH_ASSOC);

    $pdo_statement->closeCursor();

    return $result;
}

function Pdo_DoSelectField($sql, $params = [], $k5z_connection = TRUE) {

    $pdo_statement = ___Pdo_ExecuteStatement($sql, $params, $k5z_connection);

    if (!$pdo_statement) {

        return FALSE;
    }

    if ($pdo_statement->rowCount() == 0) {

        $pdo_statement->closeCursor();

        return FALSE;
    }

    $result = $pdo_statement->fetchColumn(0);

    $pdo_statement->closeCursor();

    return $result;
}

function Pdo_ErrorOnFailure($value) {

    global $___;

    $___pdo =& $___['persistent']['pdo'];

    $___pdo['error_on_failure'] = $value;
}
