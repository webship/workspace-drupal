#!/usr/bin/env bash

# workspace-name: Drupal (11, 12 or a release)

# Installed by the Drupal plugin (plugins.sh --install drupal); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Drupal core site in a container: the latest Drupal 11, or what --version names (12, a
# release, a development branch), at https://<name>.ddev.site. With --install the site is installed
# with the workspace account as its administrator; with --add-users it also gets the default
# accounts: an administrator, a content editor and an account with no role.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Set site version: the major whose latest release is built when --version says nothing.
site_version="11";

# Distribution.
distribution_name="drupal";
distribution_title="Drupal";
distribution_webroot="web";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/drupal/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/drupal/args/arg-drupal.sh || exit 1 ;

shift $#;

drupal_build ;
