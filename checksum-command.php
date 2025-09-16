<?php

if ( ! class_exists( 'FIN_CLI' ) ) {
	return;
}

$fincli_checksum_autoloader = __DIR__ . '/vendor/autoload.php';
if ( file_exists( $fincli_checksum_autoloader ) ) {
	require_once $fincli_checksum_autoloader;
}

FIN_CLI::add_command( 'core', 'Core_Command_Namespace' );
FIN_CLI::add_command( 'core verify-checksums', 'Checksum_Core_Command' );

FIN_CLI::add_command( 'plugin', 'Plugin_Command_Namespace' );
FIN_CLI::add_command( 'plugin verify-checksums', 'Checksum_Plugin_Command' );
