Feature: Each account reaches the pages it may use
  As the owner of the site
  I want every default account to open its own pages and to be refused the others
  So that a change of permissions is caught by the suite

  # The accounts are the default ones; a scenario logs in by a handle of the users registry.

  Scenario: The content editor reaches the content and nothing above it
    Given I am a logged in user with the "editor" user
    Then I should be allowed access to "/admin/content"
    And I should be denied access to "/admin/people"
    And I should be denied access to "/admin/modules"

  Scenario: The navigation sidebar of the content editor lists Content and not Extend
    Given I am a logged in user with the "editor" user
    And I am on the content overview page
    Then I should see the navigation sidebar
    And the navigation sidebar should list "Content"
    And the navigation sidebar should not list "Extend"

  Scenario: An account with no role has no administration
    Given I am a logged in user with the "authenticated" user
    Then I should be denied access to "/admin/content"
    And I should be on the access denied page
    And I should not see the navigation sidebar

  Scenario: A visitor is sent away from the administration
    Given I am an anonymous user
    And I am on the homepage
    Then I should not be logged in
    And I should be denied access to "/admin"

  Scenario: The content editor role holds what it should and no more
    Given I am a logged in user with the "admin" user
    Then the "Content editor" role should exist
    And the "Content editor" role should have the "Access the Content overview page" permission
    And the "Content editor" role should not have the "Administer users" permission
