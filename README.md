# @webship.co/workspace-drupal

Drupal for the [Webship Workspace](https://github.com/webship/workspace) dashboard: one builder
that makes a real Drupal core site in a container (Drupal 11, Drupal 12 or a release you name), a
Drush tool for the sites of a folder, the default accounts, the
[Drupal core step pack](https://github.com/webship/drupal-core-steps) wired into the workspace's
testing setup, and two AI agents that know all of it.

The workspace is container-based (DDEV by default): a Drupal project is a row like any other, so
the row menus the core draws (start, stop, launch, backup, clone, remove, tests) work on it unchanged.

It is made from the reference platform plugin,
[`@webship.co/workspace-wordpress`](https://github.com/webship/workspace-wordpress), and it is the
whole of the platform: the build, the accounts and the testing hook are the plugin's own functions.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require github:webship/workspace-drupal   # npm install into the dashboard
bash core/scripts/plugins.sh --activate drupal                            # plugins.drupal in settings.yml
bash core/scripts/plugins.sh --install drupal                             # commands, functions, args, agents
bash core/scripts/plugins.sh --configure drupal                           # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an agent you edited stays.

The commands land in the sites folders that are in the workspace (`dev`, `test`, `sandboxes`,
`demos`); the agents land in the AI Agents folder (`ai-agents/`) when the workspace has one, and are
installed into `~/.claude/agents` from there like any other agent.

It needs a Webship Workspace 1.0.7 or later.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, the AI Agents folder its two agents are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate drupal --with-needs   # dev and ai-agents are required, activated and installed first
bash core/scripts/plugins.sh --install drupal
```

Everything the builder runs for a site runs in the site's own container, through the container tool the workspace already needs; the plugin asks for no command of its own on the machine.

A workspace that knows none of this (Webship Workspace 1.0.8 and older) ignores the keys: add a sites folder and the AI Agents folder yourself, then `--install drupal` again.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-drupal-project.sh` | The builder, in the Build list as **Drupal (11, 12 or a release)**, installed into every sites folder |
| `commands/cmd-tools-drupal-cli.sh` | Drush for one project: what the site is, a command, updates, the cache, a one-time login link, the default accounts |
| `scripts/functions/fun-drupal.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_drupal_users`, `add_drupal_users`, `cancel_drupal_users`, `testing_configure_drupal`) |
| `scripts/args/arg-drupal.sh`, `arg-drupal-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `testing/site.feature` | The first feature a Drupal core project gets when testing is set up |
| `agents/drupal-site-builder.md` | The agent that builds and maintains Drupal core sites with these commands |
| `agents/drupal-tester.md` | The agent that writes and runs scenarios with the Drupal core step pack |
| `src/index.ts` | `register(api)`: what the assistant is told about Drupal here |
| `features/drupal.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## How this relates to the folder builders

The sites folders (`dev`, `test`, `sandboxes`, `demos`) are plugins too, and they place builders of
their own: `cmd-drupal11-recommended-project.sh`, `cmd-drupal12-recommended-project.sh`,
`cmd-drupal10-recommended-project.sh` and the like, one file per release line. Those builders call
build functions that the workspace base still carries. This plugin does not move, replace or change
any of them, and a workspace that never installs it works as before.

This plugin sits beside them as the platform's own package:

- **One builder, with arguments.** `cmd-drupal-project.sh <name> --version 11|12|<release>` is one
  file for every release line. Its name collides with no file a folder places, so both sets are in
  the Build list of a folder at the same time and `--uninstall` leaves the folder's files as they were.
- **Its own functions.** The build (`drupal_build`), the accounts and the testing hook are in
  `fun-drupal.sh`. They call only the workspace's general helpers (the project name, the clean
  slate of a rebuild, the start of the container, the Node.js of the workspace) and none of the
  Drupal functions of the base, so the base can drop its own later without touching this plugin.
- **One shared name, on purpose.** The core's account tools look for `add_<name>_users` and
  `cancel_<name>_users`. With this plugin installed, `cmd-tools-add-users.sh <project> drupal` and
  `--add-users` of a folder builder for Drupal core add **this plugin's accounts** (below) in place
  of the base's older list. Uninstall the plugin and the older list is back.
- **The testing setup.** The base adds no step pack to a Drupal project. With this plugin,
  `cmd-tools-testing.sh <project>` adds the Drupal core step pack to a Drupal core site, whichever
  builder made it. It leaves alone a distribution (an install profile under `profiles/contrib`),
  a Drupal CMS site and a project that ships a testing command of its own: those belong to their
  own plugins.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a site

```bash
cd ~/workspace/dev
bash cmd-drupal-project.sh mysite --install --add-users
bash cmd-drupal-project.sh mysite --version 12 --install --add-users
bash cmd-drupal-project.sh mysite --version 12 --dry-run        # what would be built, and nothing built
```

| Flag | What it does |
| --- | --- |
| `--version <x>` | A major for its latest release (`11`, the default, `12`, `10`), a release (`11.4.12`, `12.0.0-beta2`) or a development branch (`11.x-dev`) |
| `--profile <name>` | `standard` (the default) or `minimal` |
| `--install` | Install the site, with the workspace account as its administrator |
| `--add-users` | With `--install`: add the default accounts |
| `--require <packages>` | More packages to require with composer before the install |
| `--enable <modules>` | With `--install`: modules to install right after the site |
| `--php-version <x>` | The PHP of the project container; empty is what the version needs |
| `--dry-run` | Say the code, the container, Drush and the profile, and build nothing |
| `--launch` | Open the site when it is ready |

The site answers at `https://mysite.ddev.site`, the login at `/user/login`. The build runs
`ddev config` with the project type of the major (`drupal11`; the general `drupal` type when the
container tool does not know the major yet) and the Node.js of the workspace (24), creates the
code from `drupal/recommended-project` with composer in the container, adds Drush, and installs
with Drush. The database settings are the container tool's (`settings.ddev.php`): the build writes
none and hands the installer no database address. A project of the same name is deleted first.

What each major brings:

| Major | Code | PHP | Drush |
| --- | --- | --- | --- |
| 11 | `drupal/recommended-project:^11` | the default of the container tool | `^13` |
| 12 | `drupal/recommended-project:^12`, stability `beta` until 12.0.0 is out | 8.5 | `14.x-dev`, until a release supports Drupal 12 |
| 10 | `drupal/recommended-project:^10` | the default of the container tool | `^12 \|\| ^13` |

**What was proven, and what was not.** Drupal 11 was built, installed and tested with this builder
(11.4.12, Standard, PHP 8.3, DDEV 1.24.7): the site answers, the accounts log in, the first feature
is green. **Drupal 12 was not built.** It needs PHP 8.5, which DDEV offers from 1.25, and the machine
this plugin was proven on runs DDEV 1.24.7. What is verified for `--version 12` is the plan the
builder makes (`--dry-run`, and the unit tests): the constraint, the stability, PHP 8.5 and the
development Drush, which are the values the Drupal core step pack builds its Drupal 12 site with.
On an older container tool the build stops at its first step and says that the tool is too old.

### Work on a site

```bash
bash cmd-tools-drupal-cli.sh mysite                                    # version, profile, themes, accounts, pending updates
bash cmd-tools-drupal-cli.sh mysite --run "pm:install pathauto --yes"
bash cmd-tools-drupal-cli.sh mysite --update                           # composer update, the database updates, the cache
bash cmd-tools-drupal-cli.sh mysite --cache-rebuild
bash cmd-tools-drupal-cli.sh mysite --login                            # a one-time login link
bash cmd-tools-drupal-cli.sh mysite --add-users                        # the default accounts
bash cmd-tools-drupal-cli.sh mysite --cancel-users                     # delete them, and what they wrote
```

The tool works on any Drupal project of the folder, whichever builder made it.

### The default accounts

| Account | Role | Handle in the tests |
| --- | --- | --- |
| `administrator` | administrator | `admin` |
| `editor` | content_editor | `editor` |
| `authenticated` | none | `authenticated` |

Each has the address `<account>@example.com` and the password of the workspace's other default
lists. They are for local sites and for tests; the site's own administrator is the workspace
account and is never written into a test. `bash cmd-tools-add-users.sh mysite drupal` and
`bash cmd-tools-cancel-users.sh mysite drupal` add and remove the same list. The row's Users menu
names this list for a Drupal core site once the workspace carries
[webship/workspace#178](https://github.com/webship/workspace/issues/178); a Workspace 1.0.7 names
another one there, so use the commands. The content editor
role comes with the Standard profile: on a Minimal site `editor` is added without a role, and the
tool says so.

### Test a site

```bash
bash cmd-tools-testing.sh mysite                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh mysite --run           # run the suite in the container
bash cmd-tools-testing.sh mysite --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Drupal core project it also adds
`@webship-js/drupal-core-steps` to `package.json`, lists its step definitions in `cucumber.js` after
webship-js's own, writes the users registry (the handles above, overridable with
`DRUPAL_<HANDLE>_USER`, `DRUPAL_<HANDLE>_PASS` and `DRUPAL_<HANDLE>_MAIL`), places
`tests/features/site.feature` when the project has none, and makes sure the default accounts are on
the site. Run it again and it adds what is missing, lists nothing twice and keeps what you changed.
The first feature is made for a Standard site.

## The agents

| Agent | Use it to |
| --- | --- |
| `drupal-site-builder` | Build, update, maintain or remove a Drupal core site with the commands above, in containers only |
| `drupal-tester` | Set the testing stack up, look at the site in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |

After `--install` they are in the AI Agents folder of the dashboard; **Install** there puts one into
`~/.claude/agents`, or from the command line:

```bash
cd ~/workspace/ai-agents
bash cmd-tools-ai-items.sh drupal-tester --install
```

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the agents, the functions against a scaffolded project
```
