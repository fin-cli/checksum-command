<?php

if ( ! class_exists( 'FP_CLI' ) ) {
	return;
}

$fpcli_checksum_autoloader = __DIR__ . '/vendor/autoload.php';
if ( file_exists( $fpcli_checksum_autoloader ) ) {
	require_once $fpcli_checksum_autoloader;
}

FP_CLI::add_command( 'core', 'Core_Command_Namespace' );
FP_CLI::add_command( 'core verify-checksums', 'Checksum_Core_Command' );

FP_CLI::add_command( 'plugin', 'Plugin_Command_Namespace' );
FP_CLI::add_command( 'plugin verify-checksums', 'Checksum_Plugin_Command' );
