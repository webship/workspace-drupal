---
name: drupal-scenarios
description: Write and run webship-js scenarios for a Drupal core site of the Webship Workspace with the Drupal core step pack (`@webship-js/drupal-core-steps`) — the phrases of the pack by area (sessions, the named pages, access and the navigation sidebar, how the site is built, terms and menu links, content), the handles of the users registry, and the workspace command that runs them in the site's container. Use when asked to "write a scenario for this Drupal site", "test the content editor role", "which step is there for a permission", "add a feature for creating content", or when a `.feature` file of a Drupal core project is being written or fixed.
argument-hint: '<site> [what to cover]'
---

# drupal-scenarios

Scenarios for a Drupal core site of a Webship Workspace (`~/workspace`, container-based, DDEV by
default), written from the steps of [`@webship-js/drupal-core-steps`](https://github.com/webship/drupal-core-steps)
and of [webship-js](https://github.com/webship/webship-js) itself, and run in the site's container
by the workspace's own command. It comes with the Drupal plugin (`@webship.co/workspace-drupal`),
like the builder (`cmd-drupal-project.sh`), the Drush tool (`cmd-tools-drupal-cli.sh`) and the
agents `drupal-site-builder` and `drupal-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The site | `~/workspace/<folder>/<site>`, at `https://<site>.ddev.site` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| The suite's configuration | `<site>/cucumber.js`: the step definitions it loads and the users registry (`worldParameters.users`) |
| The features | `<site>/tests/features/*.feature` (`site.feature` is the first one the setup wrote) |
| The pack's steps | `<site>/node_modules/@webship-js/drupal-core-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<site>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<site>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site>
   ```
   It adds webship-js, the step pack, the users registry and `tests/features/site.feature`, and
   makes sure the default accounts are on the site. It is safe to run again: it adds what is
   missing and keeps what was changed. It wires the pack into a Drupal core site only: a
   distribution and a Drupal CMS site belong to their own plugins.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the pack
   moves, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<site>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/drupal-core-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with five examples above it; open the file when a phrase
   is not obvious, and to see whether a step takes a label or a machine name.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a page you have not seen. A scenario written without having seen the page asserts
   what you imagine.
4. **Write the feature** in `<site>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --tags "@critical"
   bash cmd-tools-testing.sh <site> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

A scenario logs in by a handle of the users registry. The default accounts are on the site
already (`bash cmd-tools-drupal-cli.sh <site> --add-users` adds them again if they were removed):

| Handle | Account | Role |
| --- | --- | --- |
| `admin` | `administrator` | administrator |
| `editor` | `editor` | content_editor |
| `authenticated` | `authenticated` | none |

```gherkin
Given I am a logged in user with the "editor" user
Then I should be logged in
And the page should return HTTP status 200
```

## The phrases, by area

Each line is a phrase the pack defines, and each one passed on a site built with
`bash cmd-drupal-project.sh <site> --install --add-users` (Drupal 11.4, the Standard profile; the
names in quotes are that site's). Most `should` steps also take the negative: `should not see`,
`should not be`, `should not list`.

### Sessions

```gherkin
Given I am an anonymous user
Given I am not logged in
Given I am on the login page
Given I am a logged in user with the "editor" user
When I log out
Then I should see the login form
Then I should be logged in
Then I should not be logged in
Then the page should return HTTP status 200
```

### The named pages

A page is opened by its name, never by its path:

```gherkin
Given I am on the administration page
Given I am on the content overview page
Given I am on the people page
Given I am on the modules page
Given I am on the appearance page
Given I am on the status report page
Given I am on the add content page
Given I am on the site information page
Given I am on the user profile page
Given I am on the password reset page
Then I should be on an admin page
Then I should see the page title "Content"
Then I should see the site information form
Then I should see the password reset form
Then I should see the breadcrumb
Then I should see the local tasks
Then I should be on the front page
```

### Access, and the navigation sidebar

```gherkin
Then I should be allowed access to "/admin/content"
Then I should be denied access to "/admin/people"
Then I should be on the access denied page
Then the page should not have PHP errors
Then I should see the navigation sidebar
Then the navigation sidebar should list "Content"
Then the navigation sidebar should not list "Extend"
When I click "Content" in the navigation sidebar
```

The access steps ask the site with the session of the scenario and leave the page on screen
alone; a refused path leaves the browser on the access denied page.

### How the site is built

Read as an administrator: the steps fetch the administration pages with the session's cookies.

```gherkin
Then the "node" module should be installed
Then the "toolbar" module should not be installed
Then the default theme should be "Olivero"
Then the "Content editor" role should exist
Then the "Content editor" role should have the "Access the Content overview page" permission
Then the "Content editor" role should not have the "Administer users" permission
Then the "Main navigation" menu should list "Home"
Then the front page path should be "/node"
Then the status report should have no errors
Then the core JavaScript settings should be initialized
```

A module is named by its machine name, a theme, a role, a permission and a menu by the label
their administration page shows.

### Terms and menu links

```gherkin
When I create a "tags" term named "A term written by a scenario"
When I delete the "tags" term named "A term written by a scenario"
When I add a menu link titled "A link written by a scenario" to "/user" in the "main" menu
When I delete the menu link titled "A link written by a scenario" from the "main" menu
Then I should see a status message
```

### Content

A site built with Drupal 11.4 or later has **no content type**: the Standard profile installs
none. Add the ones the scenarios need through the Drush tool, from core's own recipes, before
writing a content scenario:

```bash
cd ~/workspace/<folder>
bash cmd-tools-drupal-cli.sh <site> --run "recipe core/recipes/article_content_type"
bash cmd-tools-drupal-cli.sh <site> --run "recipe core/recipes/page_content_type"
```

With both applied, these passed as the `admin` handle:

```gherkin
Then the "Article" content type should exist
When I create an "article" content item titled "An article written by a scenario"
Then I should be on an "article" page
Then the content should be published
When I edit the content item I created
When I view the content item I created
Then the top bar should offer the "Edit" action
When I delete the content item I created
Given I am adding a "page" content item
When I fill in "Title" with "A page written by a scenario"
When I fill in the rich text editor field "Body" with "This page is written and removed by the suite."
When I save the content
Then I should see a status message "Basic page A page written by a scenario has been created."
When I delete the content item I am viewing
When I try to save the content
Then the "Title" field should block submission as required
Then I should see an empty listing
```

`I am an anonymous user`, `I am on the homepage`, `I fill in "<field>" with "<value>"`,
`I should see "<text>"` and `the response status code should be 200` are webship-js's own steps;
its status codes, classes, landmarks and accessibility audits are used as they are and never
redefined for this platform.

## Traps found on a real site

- **A label in one step, a machine name in the next.** `the "Article" content type should exist`
  reads the label; `I create an "article" content item` and `I am adding a "page" content item`
  open `/node/add/<machine name>`: `"Article"` and `"Basic page"` answer 404 there. The same for
  a vocabulary (`"tags"`, not `"Tags"`) and for a menu whose form a step opens (`"main"`), while
  `the "Main navigation" menu should list` reads the label. The failed step says so in its `Hint`.
- **The content editor may not create content.** The recipes add the types and give the role no
  permission on them: `I should be denied access to "/node/add/article"` passes for `editor`. A
  scenario in which the editor writes needs the permissions first:
  `bash cmd-tools-drupal-cli.sh <site> --run "role:perm:add content_editor 'create article content,edit own article content,delete own article content'"`.
- **The content editor can add a term and cannot delete it** with the pack's step: the step reads
  the vocabulary's overview, which answers 403 for that role. The step stops there and says so
  (`This account may not open …, so nothing was deleted`), and the term stays on the site. Add
  and delete terms as `admin`, log in as `admin` for the cleanup, or delete what was left with
  `bash cmd-tools-drupal-cli.sh <site> --run "entity:delete taxonomy_term <id>"`.
- **The password reset form is for a visitor.** With a session, the password reset page is the
  account's own form: assert `I should see the password reset form` after `Given I am an anonymous user`.
- **The site has the navigation sidebar, not the toolbar.** The Standard profile installs the
  Navigation module: use the `navigation sidebar` phrases, and for a visitor or an account with
  no role `I should not see the navigation sidebar`.
- **The page cache steps** (`the page should be served from the page cache`) fail on a site set
  up for testing: the first request of a scenario is a miss. Leave them out of a suite that runs
  against a development site.
- A scenario that failed after it created something left it behind: delete it through the Drush
  tool before the next run, or the next run finds it.

## Rules

- **No account is created in a suite.** No `drush user:create` in a hook, no registration
  scenario that leaves an account behind. A role the registry does not have is asked for, not
  made.
- **Never the workspace account.** The site's own administrator is not in the registry; `admin`
  is the `administrator` default account.
- **No password in a feature file**, except where a wrong password is the subject.
- **No platform name in a step phrase**: `I am on the login page`, never a phrase that names the
  platform. The same holds for a custom step.
- **No selector when a step says it**: `I should see a status message`, not the class of the
  message.
- **What a scenario creates, it removes** in the same scenario, under a title nobody else uses.
- **A custom step is the last resort**: look in the pack and in webship-js first, write it in
  `<site>/tests/step-definitions/` with a comment block and examples, and say it may belong in
  the pack.
- **Everything runs in the container**, through `cmd-tools-testing.sh`. Never `npx cucumber-js`
  or `npx playwright` on the host.
- **A failing scenario is a result.** No `@wip`, no longer timeout, no looser assertion to turn a
  run green: say what the site did.

## Examples that run

`examples/` holds three features that pass on a site built with
`bash cmd-drupal-project.sh <site> --install --add-users`, with no content type added. Copy one
into the suite and run it:

```bash
cp ~/workspace/ai-skills/drupal-scenarios/examples/roles-and-access.feature ~/workspace/<folder>/<site>/tests/features/
cd ~/workspace/<folder>
bash cmd-tools-testing.sh <site> --run --path tests/features/roles-and-access.feature
```

| Feature | What it shows |
| --- | --- |
| `examples/roles-and-access.feature` | Each default account reaching, or being refused, a path; the navigation sidebar of a role; the permissions of a role |
| `examples/site-as-built.feature` | The modules, the default theme, the main menu, the front page and the status report of the build |
| `examples/terms-and-menu-links.feature` | An administrator adding and deleting a term and a menu link: what a scenario creates, it removes |
