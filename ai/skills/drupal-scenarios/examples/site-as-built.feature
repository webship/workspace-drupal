Feature: The site is built the way the build says
  As the owner of the site
  I want the modules, the theme, the menu, the front page and the status report checked
  So that a build or an update that changed the site is caught by the suite

  Scenario: The modules and the theme of the build are in place
    Given I am a logged in user with the "admin" user
    Then the "node" module should be installed
    And the "navigation" module should be installed
    And the "toolbar" module should not be installed
    And the default theme should be "Olivero"

  Scenario: The main menu and the front page are the ones of the build
    Given I am a logged in user with the "admin" user
    Then the "Main navigation" menu should list "Home"
    And the front page path should be "/node"

  Scenario: The status report has no errors
    Given I am a logged in user with the "admin" user
    And I am on the status report page
    Then I should see the page title "Status report"
    And the status report should have no errors
    And the page should not have PHP errors
