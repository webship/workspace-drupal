/**
 * Drupal for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the
 * Drush tool in the sites folders, their functions and argparse under core/scripts/plugins/drupal/,
 * its AI items (ai/ in this package) in the folder of their kind:
 * the agents in AI Agents, the skill in AI Skills, the command in AI Commands, the prompt in AI Prompts.
 * The dashboard needs nothing drawn for it: the builder is in the
 * Build list because it is a cmd-*-project.sh, the row menus are the core's, the AI items are listed
 * like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name, which is also the name its functions and its user list are called by. */
export const PLATFORM = 'drupal';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-drupal-project.sh', 'cmd-tools-drupal-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['drupal-site-builder', 'drupal-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['drupal-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['drupal-test'];

/** The prompt the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['drupal-build-and-test'];

/** What the assistant is told about Drupal in this workspace. */
export function assistantContext(): string {
  return [
    'Drupal (a plugin, @webship.co/workspace-drupal): a Drupal core site is built with',
    '`bash cmd-drupal-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos),',
    'in a container like every other project, at https://<name>.ddev.site.',
    '`--version` takes a major (11, the default, or 12), a release (11.4.12) or a development branch (11.x-dev);',
    '`--profile` takes standard or minimal; `--dry-run` says what would be built and builds nothing.',
    '`bash cmd-tools-drupal-cli.sh <name>` says what the site is; `--run "<drush command>"` runs Drush in it,',
    '`--update` updates the code and the database, `--cache-rebuild` rebuilds the cache, `--login` prints a one-time login link,',
    '`--add-users` adds the default accounts (administrator, editor, authenticated).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Drupal core step pack; `--run` runs the suite.',
    `For Drupal work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompt ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run composer, drush, npm or mysql on the host for a project; never write a $databases block into settings.php.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
