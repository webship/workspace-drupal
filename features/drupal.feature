Feature: The Drupal plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Drupal builder, the
  AI Agents folder lists the Drupal agents, and the Plugins page lists the plugin with its steps.

  Scenario: The plugin is listed on the Plugins page
    Given I am on "/settings/plugins"
     Then I should see "Drupal"
      And I should see "@webship.co/workspace-drupal"

  Scenario: A sites folder offers the Drupal builder
    Given I am on "/dev"
     Then "option[value='cmd-drupal-project.sh']" should be attached

  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents"
     Then I should see "drupal-site-builder"
      And I should see "drupal-tester"
