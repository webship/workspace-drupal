#!/usr/bin/env bash

# Installed by the Drupal plugin (plugins.sh --install drupal); __WORKSPACE__ is the workspace it was installed into.
#
# Drush for one Drupal project of this workspace, in its container: say what the site is, run a
# Drush command, update the code and the database, rebuild the cache, print a one-time login
# link, add or remove the default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="drupal";

ARGPARSE_DESCRIPTION="Run Drush on a Drupal project of __WORKSPACE__: status, a command, updates, the cache, a login link, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/drupal/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/drupal/args/arg-drupal-cli.sh || exit 1 ;

shift $#;

drupal_cli_tool ;
