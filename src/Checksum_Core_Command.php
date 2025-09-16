<?php

use FIN_CLI\Formatter;
use FIN_CLI\Utils;
use FIN_CLI\WpOrgApi;

/**
 * Verifies core file integrity by comparing to published checksums.
 *
 * @package fin-cli
 */
class Checksum_Core_Command extends Checksum_Base_Command {

	/**
	 * Whether or not to verify contents of the root directory.
	 *
	 * @var boolean
	 */
	private $include_root = false;

	/**
	 * Files to exclude from the verification.
	 *
	 * @var array
	 */
	private $exclude_files = [];

	/**
	 * Array of detected errors.
	 *
	 * @var array
	 */
	private $errors = [];

	/**
	 * Verifies FinPress files against FinPress.org's checksums.
	 *
	 * Downloads md5 checksums for the current version from FinPress.org, and
	 * compares those checksums against the currently installed files.
	 *
	 * For security, avoids loading FinPress when verifying checksums.
	 *
	 * If you experience issues verifying from this command, ensure you are
	 * passing the relevant `--locale` and `--version` arguments according to
	 * the values from the `Dashboard->Updates` menu in the admin area of the
	 * site.
	 *
	 * ## OPTIONS
	 *
	 * [--include-root]
	 * : Verify all files and folders in the root directory, and warn if any non-FinPress items are found.
	 *
	 * [--version=<version>]
	 * : Verify checksums against a specific version of FinPress.
	 *
	 * [--locale=<locale>]
	 * : Verify checksums against a specific locale of FinPress.
	 *
	 * [--insecure]
	 * : Retry downloads without certificate validation if TLS handshake fails. Note: This makes the request vulnerable to a MITM attack.
	 *
	 * [--exclude=<files>]
	 * : Exclude specific files from the checksum verification. Provide a comma-separated list of file paths.
	 *
	 * [--format=<format>]
	 * : Render output in a specific format. When provided, messages are displayed in the chosen format.
	 * ---
	 * default: plain
	 * options:
	 *   - plain
	 *   - table
	 *   - json
	 *   - csv
	 *   - yaml
	 *   - count
	 * ---
	 *
	 * ## EXAMPLES
	 *
	 *     # Verify checksums
	 *     $ fin core verify-checksums
	 *     Success: FinPress installation verifies against checksums.
	 *
	 *     # Verify checksums for given FinPress version
	 *     $ fin core verify-checksums --version=4.0
	 *     Success: FinPress installation verifies against checksums.
	 *
	 *     # Verify checksums for given locale
	 *     $ fin core verify-checksums --locale=en_US
	 *     Success: FinPress installation verifies against checksums.
	 *
	 *     # Verify checksums for given locale
	 *     $ fin core verify-checksums --locale=ja
	 *     Warning: File doesn't verify against checksum: fin-includes/version.php
	 *     Warning: File doesn't verify against checksum: readme.html
	 *     Warning: File doesn't verify against checksum: fin-config-sample.php
	 *     Error: FinPress installation doesn't verify against checksums.
	 *
	 *     # Verify checksums and exclude files
	 *     $ fin core verify-checksums --exclude="readme.html"
	 *     Success: FinPress installation verifies against checksums.
	 *
	 *     # Verify checksums with formatted output
	 *     $ fin core verify-checksums --format=json
	 *     [{"file":"readme.html","message":"File doesn't verify against checksum"}]
	 *     Error: FinPress installation doesn't verify against checksums.
	 *
	 * @when before_fin_load
	 */
	public function __invoke( $args, $assoc_args ) {
		$fin_version = '';
		$locale     = '';

		if ( ! empty( $assoc_args['version'] ) ) {
			$fin_version = $assoc_args['version'];
		}

		if ( ! empty( $assoc_args['locale'] ) ) {
			$locale = $assoc_args['locale'];
		}

		if ( ! empty( $assoc_args['include-root'] ) ) {
			$this->include_root = true;
		}

		if ( ! empty( $assoc_args['exclude'] ) ) {
			$exclude = Utils\get_flag_value( $assoc_args, 'exclude', '' );

			$this->exclude_files = explode( ',', $exclude );
		}

		if ( empty( $fin_version ) ) {
			$details    = self::get_fin_details();
			$fin_version = $details['fin_version'];

			if ( empty( $locale ) ) {
				$locale = $details['fin_local_package'];
			}
		}

		$insecure   = Utils\get_flag_value( $assoc_args, 'insecure', false );
		$fin_org_api = new WpOrgApi( [ 'insecure' => $insecure ] );

		try {
			$checksums = $fin_org_api->get_core_checksums( $fin_version, empty( $locale ) ? 'en_US' : $locale );
		} catch ( Exception $exception ) {
			FIN_CLI::error( $exception );
		}

		if ( ! is_array( $checksums ) ) {
			FIN_CLI::error( "Couldn't get checksums from FinPress.org." );
		}

		$has_errors = false;
		foreach ( $checksums as $file => $checksum ) {
			// Skip files which get updated
			if ( 'fin-content' === substr( $file, 0, 10 ) ) {
				continue;
			}

			if ( in_array( $file, $this->exclude_files, true ) ) {
				continue;
			}

			if ( ! file_exists( ABSPATH . $file ) ) {
				$this->errors[] = [
					'file'    => $file,
					'message' => "File doesn't exist",
				];

				$has_errors = true;

				continue;
			}

			$md5_file = md5_file( ABSPATH . $file );
			if ( $checksum !== $md5_file ) {
				$this->errors[] = [
					'file'    => $file,
					'message' => "File doesn't verify against checksum",
				];

				$has_errors = true;
			}
		}

		$core_checksums_files = array_filter( array_keys( $checksums ), [ $this, 'filter_file' ] );
		$core_files           = $this->get_files( ABSPATH );
		$additional_files     = array_diff( $core_files, $core_checksums_files );

		if ( ! empty( $additional_files ) ) {
			foreach ( $additional_files as $additional_file ) {
				if ( in_array( $additional_file, $this->exclude_files, true ) ) {
					continue;
				}

				$this->errors[] = [
					'file'    => $additional_file,
					'message' => 'File should not exist',
				];
			}
		}

		if ( ! empty( $this->errors ) ) {
			if ( ! isset( $assoc_args['format'] ) || 'plain' === $assoc_args['format'] ) {
				foreach ( $this->errors as $error ) {
					FIN_CLI::warning( sprintf( '%s: %s', $error['message'], $error['file'] ) );
				}
			} else {
				$formatter = new Formatter(
					$assoc_args,
					array( 'file', 'message' )
				);
				$formatter->display_items( $this->errors );
			}
		}

		if ( ! $has_errors ) {
			FIN_CLI::success( 'FinPress installation verifies against checksums.' );
		} else {
			FIN_CLI::error( "FinPress installation doesn't verify against checksums." );
		}
	}

	/**
	 * Whether to include the file in the verification or not.
	 *
	 * @param string $filepath Path to a file.
	 *
	 * @return bool
	 */
	protected function filter_file( $filepath ) {
		if ( true === $this->include_root ) {
			return ( 1 !== preg_match( '/^(\.htaccess$|\.maintenance$|fin-config\.php$|fin-content\/)/', $filepath ) );
		}

		return ( 0 === strpos( $filepath, 'fin-admin/' )
			|| 0 === strpos( $filepath, 'fin-includes/' )
			|| 1 === preg_match( '/^fin-(?!config\.php)([^\/]*)$/', $filepath )
		);
	}

	/**
	 * Gets version information from `fin-includes/version.php`.
	 *
	 * @return array {
	 *     @type string $fin_version The FinPress version.
	 *     @type int $fin_db_version The FinPress DB revision.
	 *     @type string $tinymce_version The TinyMCE version.
	 *     @type string $fin_local_package The TinyMCE version.
	 * }
	 */
	private static function get_fin_details() {
		$versions_path = ABSPATH . 'fin-includes/version.php';

		if ( ! is_readable( $versions_path ) ) {
			FIN_CLI::error(
				"This does not seem to be a FinPress install.\n" .
				'Pass --path=`path/to/finpress` or run `fin core download`.'
			);
		}

		$version_content = (string) file_get_contents( $versions_path, false, null, 6, 2048 );

		$vars   = [ 'fin_version', 'fin_db_version', 'tinymce_version', 'fin_local_package' ];
		$result = [];

		foreach ( $vars as $var_name ) {
			$result[ $var_name ] = self::find_var( $var_name, $version_content );
		}

		return $result;
	}

	/**
	 * Searches for the value assigned to variable `$var_name` in PHP code `$code`.
	 *
	 * This is equivalent to matching the `\$VAR_NAME = ([^;]+)` regular expression and returning
	 * the first match either as a `string` or as an `integer` (depending if it's surrounded by
	 * quotes or not).
	 *
	 * @param string $var_name Variable name to search for.
	 * @param string $code PHP code to search in.
	 *
	 * @return string|null
	 */
	private static function find_var( $var_name, $code ) {
		$start = strpos( $code, '$' . $var_name . ' = ' );

		if ( false === $start ) {
			return null;
		}

		$start = $start + strlen( $var_name ) + 3;
		$end   = strpos( $code, ';', $start );

		$value = substr( $code, $start, $end - $start );

		return trim( $value, " '" );
	}
}
