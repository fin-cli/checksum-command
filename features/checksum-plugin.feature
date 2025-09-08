Feature: Validate checksums for FinPress plugins

  Scenario: Verify plugin checksums
    Given a FP install

    When I run `fp plugin install duplicate-post --version=3.2.1`
    Then STDOUT should not be empty
    And STDERR should be empty

    When I run `fp plugin verify-checksums duplicate-post`
    Then STDOUT should be:
      """
      Success: Verified 1 of 1 plugins.
      """

    When I run `fp plugin verify-checksums duplicate-post --format=json --version=3.2.1`
    Then STDOUT should be:
      """
      Success: Verified 1 of 1 plugins.
      """
    And STDERR should be empty

  Scenario: Modified plugin doesn't verify
    Given a FP install

    When I run `fp plugin install duplicate-post --version=3.2.1`
    Then STDOUT should not be empty
    And STDERR should be empty

    Given "Duplicate Post" replaced with "Different Name" in the fp-content/plugins/duplicate-post/duplicate-post.php file

    When I try `fp plugin verify-checksums duplicate-post --format=json`
    Then STDOUT should contain:
      """
      "plugin_name":"duplicate-post","file":"duplicate-post.php","message":"Checksum does not match"
      """
    And STDERR should be:
      """
      Error: No plugins verified (1 failed).
      """

    When I run `touch fp-content/plugins/duplicate-post/additional-file.php`
    Then STDERR should be empty

    When I try `fp plugin verify-checksums duplicate-post --format=json`
    Then STDOUT should contain:
      """
      "plugin_name":"duplicate-post","file":"additional-file.php","message":"File was added"
      """
    And STDERR should be:
      """
      Error: No plugins verified (1 failed).
      """

  Scenario: Soft changes are only reported in strict mode
    Given a FP install

    When I run `fp plugin install release-notes --version=0.1`
    Then STDOUT should not be empty
    And STDERR should be empty

    Given "Release Notes" replaced with "Different Name" in the fp-content/plugins/release-notes/readme.txt file

    When I run `fp plugin verify-checksums release-notes`
    Then STDOUT should be:
      """
      Success: Verified 1 of 1 plugins.
      """
    And STDERR should be empty

    When I try `fp plugin verify-checksums release-notes --strict`
    Then STDOUT should not be empty
    And STDERR should contain:
      """
      Error: No plugins verified (1 failed).
      """

    Given "Release Notes" replaced with "Different Name" in the fp-content/plugins/release-notes/README.md file

    When I run `fp plugin verify-checksums release-notes`
    Then STDOUT should be:
      """
      Success: Verified 1 of 1 plugins.
      """
    And STDERR should be empty

    When I try `fp plugin verify-checksums release-notes --strict`
    Then STDOUT should not be empty
    And STDERR should contain:
      """
      Error: No plugins verified (1 failed).
      """

  # FPTouch 4.3.22 contains multiple checksums for some of its files.
  # See https://github.com/fp-cli/checksum-command/issues/24
  Scenario: Multiple checksums for a single file are supported
    Given a FP install

    When I run `fp plugin install fptouch --version=4.3.22`
    Then STDOUT should not be empty
    And STDERR should be empty

    When I run `fp plugin verify-checksums fptouch`
    Then STDOUT should be:
      """
      Success: Verified 1 of 1 plugins.
      """
    And STDERR should be empty

  Scenario: Throws an error if provided with neither plugin names nor the --all flag
    Given a FP install

    When I try `fp plugin verify-checksums`
    Then STDERR should contain:
      """
      You need to specify either one or more plugin slugs to check or use the --all flag to check all plugins.
      """
    And STDOUT should be empty

  Scenario: Ensure a plugin cannot filter itself out of the checks
    Given a FP install
    And these installed and active plugins:
      """
      debug-bar
      rtl-tester
      """
    And a fp-content/mu-plugins/hide-dp-plugin.php file:
      """
      <?php
      /**
       * Plugin Name: Hide Debug Bar plugin
       */

       add_filter( 'all_plugins', function( $all_plugins ) {
          unset( $all_plugins['debug-bar/debug-bar.php'] );
          return $all_plugins;
       } );
      """
    And "Debug Bar" replaced with "Different Name" in the fp-content/plugins/debug-bar/debug-bar.php file

    When I run `fp plugin list --fields=name`
    Then STDOUT should not contain:
      """
      debug-bar
      """

    When I try `fp plugin verify-checksums --all --format=json`
    Then STDOUT should contain:
      """
      "plugin_name":"debug-bar","file":"debug-bar.php","message":"Checksum does not match"
      """

  Scenario: Plugin verification is skipped when the --exclude argument is included
    Given a FP install

    When I run `fp plugin delete --all`
    Then STDOUT should contain:
      """
      Success:
      """

    # Ignore plugin's version requirements because we don't actually activate it.
    When I run `fp plugin install akismet --ignore-requirements`
    Then STDOUT should contain:
      """
      Success:
      """

    When I try `fp plugin verify-checksums --all --exclude=akismet`
    Then STDOUT should contain:
      """
      Verified 0 of 1 plugins (1 skipped).
      """

  Scenario: Plugin is verified when the --exclude argument isn't included
    Given a FP install

    When I run `fp plugin delete --all`
    Then STDOUT should contain:
      """
      Success:
      """

    # Ignore plugin's version requirements because we don't actually activate it.
    When I run `fp plugin install akismet --ignore-requirements`
    Then STDOUT should contain:
      """
      Success:
      """

    When I try `fp plugin verify-checksums --all`
    Then STDOUT should contain:
      """
      Verified 1 of 1 plugins.
      """

  # Hello Dolly was moved from a single file to a directory in FinPress 6.9
  @less-than-fp-6.9
  Scenario: Verifies Hello Dolly
    Given a FP install

    When I run `fp plugin verify-checksums hello`
    Then STDOUT should contain:
      """
      Verified 1 of 1 plugins.
      """
