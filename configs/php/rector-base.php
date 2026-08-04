<?php

declare(strict_types=1);

use Rector\Config\RectorConfig;
use RectorLaravel\Set\LaravelLevelSetList;
use RectorLaravel\Set\LaravelSetList;

/**
 * Shared Rector baseline for the harness's Laravel projects, mirroring
 * `vindo-api`'s actual `rector.php` (PHP 8.3, Laravel 13). Unlike an
 * earlier draft of this file, this one deliberately enables the *full*
 * set of prepared rule sets (including codingStyle and typeDeclarations)
 * because that's what's actually run against a real codebase in this
 * stack — if a future project wants a more conservative subset, that's a
 * per-project decision layered on top via `withSkip()`, not the baseline.
 *
 * Requires `driftingly/rector-laravel` in the consuming project (that's
 * where `RectorLaravel\Set\*` come from) in addition to `rector/rector`.
 *
 * A project extends this by requiring the harness (e.g. via
 * `bin/sync-config.sh laravel`) and importing it from the project's own
 * rector.php:
 *
 *   <?php
 *
 *   use Rector\Config\RectorConfig;
 *
 *   return RectorConfig::configure()
 *       ->withSets([__DIR__ . '/harness/configs/php/rector-base.php'])
 *       ->withPaths([__DIR__ . '/app', __DIR__ . '/routes'])
 *       ->withSkip([
 *           // project-specific exclusions layered on top of the baseline
 *           __DIR__ . '/app/Legacy',
 *       ]);
 */
return RectorConfig::configure()
    ->withPhpSets(php83: true)
    ->withPreparedSets(
        codeQuality: true,
        codingStyle: true,
        deadCode: true,
        earlyReturn: true,
        privatization: true,
        typeDeclarations: true,
    )
    ->withSets([
        LaravelLevelSetList::UP_TO_LARAVEL_130,
        LaravelSetList::ARRAY_STR_FUNCTIONS_TO_STATIC_CALL,
        LaravelSetList::LARAVEL_CODE_QUALITY,
        LaravelSetList::LARAVEL_COLLECTION,
        LaravelSetList::LARAVEL_ELOQUENT_MAGIC_METHOD_TO_QUERY_BUILDER,
        LaravelSetList::LARAVEL_FACADE_ALIASES_TO_FULL_NAMES,
        LaravelSetList::LARAVEL_IF_HELPERS,
        LaravelSetList::LARAVEL_TYPE_DECLARATIONS,
    ])
    ->withSkip([
        // First-class callable syntax reads worse for Laravel's magic
        // static/facade methods than the arrow-function form Rector would
        // otherwise leave alone.
        \Rector\Php81\Rector\Array_\FirstClassCallableRector::class,
        __DIR__ . '/tests/TestCase.php',
        __DIR__ . '/bootstrap/cache',
    ]);
