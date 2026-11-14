Feature: The site answers and its accounts work
  As the owner of the site
  I want the front page, the login page and each default account to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-add-users.sh); a scenario logs in by a handle of
  # the users registry in cucumber.js, so no password is written here. It is made for a site
  # installed with the Standard profile, which has the content editor role.

  @critical
  Scenario: The front page is served
    Given I am an anonymous user
    And I am on the homepage
    Then the response status code should be 200
    And I should be on the front page
    And the page should not have PHP errors

  @critical
  Scenario: The login page is served with its form
    Given I am on the login page
    Then the response status code should be 200
    And I should see the login form

  Scenario Outline: Each default account logs in
    Given I am a logged in user with the "<handle>" user
    Then I should be logged in
    And the page should return HTTP status 200

    Examples:
      | handle        |
      | admin         |
      | editor        |
      | authenticated |

  Scenario: The administrator reaches the administration
    Given I am a logged in user with the "admin" user
    Then I should be allowed access to "/admin/people"
    And I should be allowed access to "/admin/reports/status"
    And the "Content editor" role should exist

  Scenario: The content editor reaches the content and nothing above it
    Given I am a logged in user with the "editor" user
    Then I should be allowed access to "/admin/content"
    And I should be denied access to "/admin/people"

  Scenario: An account with no role stays out of the administration
    Given I am a logged in user with the "authenticated" user
    Then I should be denied access to "/admin/content"
    And I should be on the access denied page

  Scenario: An anonymous visitor has no session and no way in
    Given I am not logged in
    Then I should not be logged in
    And I should be denied access to "/admin"
