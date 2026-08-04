<?php

declare(strict_types=1);

use Rector\CodeQuality\Rector\Class_\CompleteDynamicPropertiesRector;
use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\SetList;

/**
 * Shared, safe Rector baseline for the harness's Laravel projects.
 *
 * Deliberately conservative: language-level upgrade rules (up to PHP 8.4),
 * dead-code removal, and non-coercive code-quality rules only. No
 * `TypeDeclarationSetList` / strict-types-inference rule sets and no
 * `CodingStyleSetList` — those tend to fight Pint or introduce type
 * assumptions that aren't actually safe to auto-apply across an
 * action-class + Eloquent codebase.
 *
 * A project extends this by requiring the harness (e.g. via
 * `bin/sync-config.sh laravel`, or a composer path repository) and
 * importing it from the project's own rector.php:
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
    ->withSets([
        SetList::PHP_84,
        SetList::DEAD_CODE,
        SetList::CODE_QUALITY,
    ])
    ->withSkip([
        // Excluded because it infers dynamic properties into typed
        // properties, which can silently change behavior on Eloquent
        // models that rely on magic __get/__set.
        CompleteDynamicPropertiesRector::class,
    ])
    ->withPhpSets(php84: true)
    ->withImportNames(removeUnusedImports: true);
