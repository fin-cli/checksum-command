Feature: Validate checksums for FinPress install

  @require-php-7.0
  Scenario: Verify core checksums
    Given a FIN install

    When I run `fin core update`
    Then STDOUT should not be empty

    When I run `fin core verify-checksums`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """

  Scenario: Core checksums don't verify
    Given a FIN install
    And "FinPress" replaced with "Finpress" in the readme.html file

    When I try `fin core verify-checksums`
    Then STDERR should be:
      """
      Warning: File doesn't verify against checksum: readme.html
      Error: FinPress installation doesn't verify against checksums.
      """

    When I run `rm readme.html`
    Then STDERR should be empty

    When I try `fin core verify-checksums`
    Then STDERR should be:
      """
      Warning: File doesn't exist: readme.html
      Error: FinPress installation doesn't verify against checksums.
      """
    And the return code should be 1

  Scenario: Core checksums don't verify because fin-cli.yml is present
    Given a FIN install
    And a fin-cli.yml file:
      """
      plugin install:
        - user-switching
      """

    When I try `fin core verify-checksums`
    Then STDERR should be:
      """
      Warning: File should not exist: fin-cli.yml
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

    When I run `rm fin-cli.yml`
    Then STDERR should be empty

    When I run `fin core verify-checksums`
    Then STDERR should be empty
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums without loading FinPress
    Given an empty directory
    And I run `fin core download --version=4.3`

    When I run `fin core verify-checksums`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """

    When I run `fin core verify-checksums --version=4.3 --locale=en_US`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """

    When I try `fin core verify-checksums --version=4.2 --locale=en_US`
    Then STDERR should contain:
      """
      Error: FinPress installation doesn't verify against checksums.
      """

  Scenario: Verify core checksums for a non US local
    Given an empty directory
    And I run `fin core download --locale=en_GB --version=4.3.1 --force`
    Then STDOUT should contain:
      """
      Success: FinPress downloaded.
      """
    And the return code should be 0

    When I run `fin core verify-checksums`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  @require-php-7.0
  Scenario: Verify core checksums with extra files
    Given a FIN install

    When I run `fin core update`
    Then STDOUT should not be empty

    Given a fin-includes/extra-file.txt file:
      """
      hello world
      """
    Then the fin-includes/extra-file.txt file should exist

    When I try `fin core verify-checksums`
    Then STDERR should be:
      """
      Warning: File should not exist: fin-includes/extra-file.txt
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums when extra files prefixed with 'fin-' are included in FinPress root
    Given a FIN install
    And a fin-extra-file.php file:
      """
      hello world
      """

    When I try `fin core verify-checksums`
    Then STDERR should be:
      """
      Warning: File should not exist: fin-extra-file.php
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums when extra files are included in FinPress root and --include-root is passed
    Given a FIN install
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
    And a fin-content/unknown-file.php file:
      """
      foobar
      """

    When I try `fin core verify-checksums --include-root`
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
      Warning: File should not exist: fin-content/unknown-file.php
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

    When I run `fin core verify-checksums`
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
      Warning: File should not exist: fin-content/unknown-file.php
      """
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums with a plugin that has fin-admin
    Given a FIN install
    And a fin-content/plugins/akismet/fin-admin/extra-file.txt file:
      """
      hello world
      """

    When I run `fin core verify-checksums`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And STDERR should be empty

  Scenario: Verify core checksums with excluded files
    Given a FIN install
    And "FinPress" replaced with "PressWord" in the readme.html file
    And a fin-includes/some-filename.php file:
      """
      sample content of some file
      """

    When I try `fin core verify-checksums --exclude='readme.html,fin-includes/some-filename.php'`
    Then STDERR should be empty
    And STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0

  Scenario: Verify core checksums with missing excluded file
    Given a FIN install
    And "FinPress" replaced with "PressWord" in the readme.html file
    And a fin-includes/some-filename.php file:
      """
      sample content of some file
      """

    When I try `fin core verify-checksums --exclude='fin-includes/some-filename.php'`
    Then STDERR should be:
      """
      Warning: File doesn't verify against checksum: readme.html
      Error: FinPress installation doesn't verify against checksums.
      """
    And the return code should be 1

  Scenario: Core checksums verify with format parameter
    Given a FIN install
    And "FinPress" replaced with "Modified FinPress" in the fin-includes/functions.php file
    And a fin-includes/test.log file:
      """
      log content
      """

    When I try `fin core verify-checksums --format=table`
    Then STDOUT should be a table containing rows:
      | file                       | message                              |
      | fin-includes/functions.php  | File doesn't verify against checksum |
      | fin-includes/test.log  | File should not exist |
    And the return code should be 1

    When I try `fin core verify-checksums --format=csv`
    Then STDOUT should contain:
      """
      file,message
      fin-includes/functions.php,"File doesn't verify against checksum"
      fin-includes/test.log,"File should not exist"
      """
    And the return code should be 1

    When I try `fin core verify-checksums --format=json`
    Then STDOUT should contain:
      """
      "file":"fin-includes\/functions.php","message":"File doesn't verify against checksum"
      """
    And the return code should be 1

    When I try `fin core verify-checksums --format=count`
    Then STDOUT should be:
      """
      2
      """
    And the return code should be 1

    When I try `fin core verify-checksums --format=json --exclude=fin-includes/test.log`
    Then STDOUT should contain:
      """
      "file":"fin-includes\/functions.php","message":"File doesn't verify against checksum"
      """
    And the return code should be 1

    When I try `fin core verify-checksums --format=json --exclude=fin-includes/functions.php,fin-includes/test.log`
    Then STDOUT should be:
      """
      Success: FinPress installation verifies against checksums.
      """
    And the return code should be 0
