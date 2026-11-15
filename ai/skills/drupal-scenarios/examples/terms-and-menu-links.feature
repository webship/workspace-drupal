Feature: An administrator adds a term and a menu link and removes them again
  As an administrator
  I want to add a term to a vocabulary and a link to a menu, and to delete both
  So that the suite proves the forms work and leaves the site as it found it

  # A vocabulary and a menu are named by their machine names where a step opens their forms
  # ("tags", "main"), and by their labels where a step reads a page ("Main navigation").

  Scenario: A term is added to the Tags vocabulary and deleted
    Given I am a logged in user with the "admin" user
    When I create a "tags" term named "A term written by a scenario"
    Then I should see a status message
    When I delete the "tags" term named "A term written by a scenario"
    Then I should see a status message

  Scenario: A link is added to the main menu and deleted
    Given I am a logged in user with the "admin" user
    When I add a menu link titled "A link written by a scenario" to "/user" in the "main" menu
    Then the "Main navigation" menu should list "A link written by a scenario"
    When I delete the menu link titled "A link written by a scenario" from the "main" menu
    Then the "Main navigation" menu should not list "A link written by a scenario"
