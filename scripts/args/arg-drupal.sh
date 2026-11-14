#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-v', '--version',
                    default="${site_version}",
                    help='The Drupal to build: a major for its latest release (11, 12), a release (11.4.12), or a development branch (11.x-dev). Example: --version 12 [default %(default)s]')
parser.add_argument('-p', '--profile',
                    default="standard",
                    choices=['standard', 'minimal'],
                    help='The install profile. The default accounts and the first feature are made for standard. Example: --profile minimal [default %(default)s]')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Install the site, with the workspace account as the administrator.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts: an administrator, a content editor and an account with no role, the ones the test scenarios log in as.')
parser.add_argument('-r', '--require',
                    default="_none_",
                    nargs='+',
                    help='More packages to require with composer. Example: --require drupal/token drupal/pathauto')
parser.add_argument('-e', '--enable',
                    default="_none_",
                    nargs='+',
                    help='With --install, modules to install right after the site. Example: --enable media media_library token')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the site in a browser when it is ready.')
parser.add_argument('--php-version',
                    default="",
                    choices=['8.5', '8.4', '8.3', '8.2', '8.1'],
                    help='PHP version for the project container; empty means what the Drupal version needs, and the default of the container tool under that. Example: --php-version 8.4')
parser.add_argument('--dry-run',
                    action='store_true',
                    default=False,
                    help='Say what would be built (the code, the container, Drush, the profile) and build nothing.')
ARGEOF
