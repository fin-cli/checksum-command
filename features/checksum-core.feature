Feature: Validate checksums for FinPress install

  @require-php-7.0
  Scenario: Verify core checksums
    Given a FP install

    When I run `fp core update`
    Then STDOUT should not be empty

    When I run `fp core verify-checksums`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """

  Scenario: Core checksums don't verify
    Given a FP install
    And "FinPress" replaced with "Finpress" in the readme.html file

    When I try `fp core verify-checksums`
    Then STDERR should be:
      """
      Warning: File doesn't verify against checksum: readme.html
      Error: FinPress installation doesn't verify against checksums.
      """

    When I run `rm readme.html`
    Then STDERR should be empty

    When I try `fp core verify-checksums`
    Then STDERR should be:
      """
      Warning: File doesn't exist: readme.html
      Error: FinPress installation doesn't verify against checksums.
      """
    And the return code should be 1

  Scenario: Core checksums don't verify because fp-cli.yml is present
    Given a FP install
    And a fp-cli.yml file:
      """
      plugin install:
        - user-switching
      """

    When I try `fp core verify-checksums`
    Then STDERR should be:
      """
      Warning: File should not exist: fp-cli.yml
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

    When I run `rm fp-cli.yml`
    Then STDERR should be empty

    When I run `fp core verify-checksums`
    Then STDERR should be empty
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums without loading FinPress
    Given an empty directory
    And I run `fp core download --version=4.3`

    When I run `fp core verify-checksums`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """

    When I run `fp core verify-checksums --version=4.3 --locale=en_US`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """

    When I try `fp core verify-checksums --version=4.2 --locale=en_US`
    Then STDERR should contain:
      """
      Error: FinPress installation doesn't verify against checksums.
      """

  Scenario: Verify core checksums for a non US local
    Given an empty directory
    And I run `fp core download --locale=en_GB --version=4.3.1 --force`
    Then STDOUT should contain:
      """
      Success: FinPress downloaded.
      """
    And the return code should be 0

    When I run `fp core verify-checksums`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  @require-php-7.0
  Scenario: Verify core checksums with extra files
    Given a FP install

    When I run `fp core update`
    Then STDOUT should not be empty

    Given a fp-includes/extra-file.txt file:
      """
      hello world
      """
    Then the fp-includes/extra-file.txt file should exist

    When I try `fp core verify-checksums`
    Then STDERR should be:
      """
      Warning: File should not exist: fp-includes/extra-file.txt
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums when extra files prefixed with 'fp-' are included in FinPress root
    Given a FP install
    And a fp-extra-file.php file:
      """
      hello world
      """

    When I try `fp core verify-checksums`
    Then STDERR should be:
      """
      Warning: File should not exist: fp-extra-file.php
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums when extra files are included in FinPress root and --include-root is passed
    Given a FP install
    And a .htaccess file:
      """
      # BEGIN FinPress
      """
    And a .maintenance file:
      """
      <?php
      $upgrading = time();
      """
    And a extra-file.php file:
      """
      hello world
      """
    And a unknown-folder/unknown-file.php file:
      """
      taco burrito
      """
    And a fp-content/unknown-file.php file:
      """
      foobar
      """

    When I try `fp core verify-checksums --include-root`
    Then STDERR should contain:
      """
      Warning: File should not exist: unknown-folder/unknown-file.php
      """
    And STDERR should contain:
      """
      Warning: File should not exist: extra-file.php
      """
    And STDERR should not contain:
      """
      Warning: File should not exist: .htaccess
      """
    And STDERR should not contain:
      """
      Warning: File should not exist: .maintenance
      """
    And STDERR should not contain:
      """
      Warning: File should not exist: fp-content/unknown-file.php
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

    When I run `fp core verify-checksums`
    Then STDERR should not contain:
      """
      Warning: File should not exist: unknown-folder/unknown-file.php
      """
    And STDERR should not contain:
      """
      Warning: File should not exist: extra-file.php
      """
    And STDERR should not contain:
      """
      Warning: File should not exist: fp-content/unknown-file.php
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums with a plugin that has fp-admin
    Given a FP install
    And a fp-content/plugins/akismet/fp-admin/extra-file.txt file:
      """
      hello world
      """

    When I run `fp core verify-checksums`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And STDERR should be empty

  Scenario: Verify core checksums with excluded files
    Given a FP install
    And "FinPress" replaced with "PressWord" in the readme.html file
    And a fp-includes/some-filename.php file:
      """
      sample content of some file
      """

    When I try `fp core verify-checksums --exclude='readme.html,fp-includes/some-filename.php'`
    Then STDERR should be empty
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums with missing excluded file
    Given a FP install
    And "FinPress" replaced with "PressWord" in the readme.html file
    And a fp-includes/some-filename.php file:
      """
      sample content of some file
      """

    When I try `fp core verify-checksums --exclude='fp-includes/some-filename.php'`
    Then STDERR should be:
      """
      Warning: File doesn't verify against checksum: readme.html
      Error: FinPress installation doesn't verify against checksums.
      """
    And the return code should be 1

  Scenario: Core checksums verify with format parameter
    Given a FP install
    And "FinPress" replaced with "Modified FinPress" in the fp-includes/functions.php file
    And a fp-includes/test.log file:
      """
      log content
      """

    When I try `fp core verify-checksums --format=table`
    Then STDOUT should be a table containing rows:
      | file                       | message                              |
      | fp-includes/functions.php  | File doesn't verify against checksum |
      | fp-includes/test.log  | File should not exist |
    And the return code should be 1

    When I try `fp core verify-checksums --format=csv`
    Then STDOUT should contain:
      """
      file,message
      fp-includes/functions.php,"File doesn't verify against checksum"
      fp-includes/test.log,"File should not exist"
      """
    And the return code should be 1

    When I try `fp core verify-checksums --format=json`
    Then STDOUT should contain:
      """
      "file":"fp-includes\/functions.php","message":"File doesn't verify against checksum"
      """
    And the return code should be 1

    When I try `fp core verify-checksums --format=count`
    Then STDOUT should be:
      """
      2
      """
    And the return code should be 1

    When I try `fp core verify-checksums --format=json --exclude=fp-includes/test.log`
    Then STDOUT should contain:
      """
      "file":"fp-includes\/functions.php","message":"File doesn't verify against checksum"
      """
    And the return code should be 1

    When I try `fp core verify-checksums --format=json --exclude=fp-includes/functions.php,fp-includes/test.log`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0
