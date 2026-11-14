#!/usr/bin/env bash

# Drupal for the Webship Workspace: build a Drupal core site, run Drush on it, add its default
# accounts, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install drupal` in core/scripts/plugins/drupal/functions/, where
# bootstrap sources it after the core's own functions. Everything runs in the project's container
# (DDEV by default: `ddev composer …`, `ddev drush …`), never on the host. The container tool
# writes the database settings (settings.ddev.php), so nothing here writes a $databases block.
#
# The plugin is the whole of the platform: it builds with its own functions (drupal_*) and calls
# only the workspace's general helpers (trim_project_name, drop_database, ddev_up,
# ddev_nodejs_version). It reads none of the Drupal functions the workspace base still carries.
#
# Four names are the ones the core's tools look for, under the name `drupal`:
#   set_drupal_users           the default accounts          (cmd-tools-add-users.sh <project> drupal)
#   add_drupal_users           create them with Drush        (the same tool, and --add-users of the builder)
#   cancel_drupal_users        delete them                   (cmd-tools-cancel-users.sh <project> drupal)
#   testing_configure_drupal   the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a Drupal core project is tested with, and the release line it is required at.
readonly DRUPAL_STEPS_PACKAGE='@webship-js/drupal-core-steps';
readonly DRUPAL_STEPS_VERSION='^2.2.0';

# The project template every Drupal core site is created from.
readonly DRUPAL_PROJECT_TEMPLATE='drupal/recommended-project';

# The default accounts of a Standard site: an administrator, a content editor and an account with
# no role, the three a scenario logs in as. Accounts are configuration, created once on the site;
# a test suite never creates or deletes one. `_none_` is an account with no role.
function drupal_default_users() {
  users=(administrator editor authenticated);
  user_administrator_name="administrator";
  user_administrator_mail="administrator@example.com";
  user_administrator_password="dD.123123ddd";
  user_administrator_role="administrator";
  user_editor_name="editor";
  user_editor_mail="editor@example.com";
  user_editor_password="dD.123123ddd";
  user_editor_role="content_editor";
  user_authenticated_name="authenticated";
  user_authenticated_mail="authenticated@example.com";
  user_authenticated_password="dD.123123ddd";
  user_authenticated_role="_none_";
}

# The name the core's tools ask for the list by.
function set_drupal_users() {
  drupal_default_users ;
}

# The docroot of a project, from its own container configuration (web when it says nothing).
function drupal_docroot() {
  local project_path="$1" docroot ;
  docroot=$(grep -E '^docroot:' "${project_path}/.ddev/config.yaml" 2>/dev/null | head -1 | sed -E 's/^docroot:[[:space:]]*//; s/"//g; s/[[:space:]]*$//') ;
  printf '%s' "${docroot:-web}" ;
}

# Is this folder a Drupal project of any kind? Its DDEV project type says so.
function drupal_is_project() {
  local project_path="$1";
  grep -qE '^type:[[:space:]]*"?drupal[0-9]*"?[[:space:]]*$' "${project_path}/.ddev/config.yaml" 2>/dev/null ;
}

# Is it a Drupal core site: not a distribution (an install profile under profiles/contrib), not
# Drupal CMS (its packages in composer.json), not a project that ships a testing command of its
# own? Those have their own plugins and their own step packs.
function drupal_is_core_site() {
  local project_path="$1" docroot ;
  drupal_is_project "${project_path}" || return 1 ;
  docroot="$(drupal_docroot "${project_path}")" ;
  [ -n "$(ls -A "${project_path}/${docroot}/profiles/contrib" 2>/dev/null)" ] && return 1 ;
  grep -qE '"drupal/(cms|drupal_cms_[a-z0-9_]+)"' "${project_path}/composer.json" 2>/dev/null && return 1 ;
  [ -f "${project_path}/.ddev/commands/web/init-full-automated-testing" ] && return 1 ;
  return 0 ;
}

# Go to the project a tool was asked about, or say why not.
function drupal_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! drupal_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Drupal project (its .ddev/config.yaml does not say type: drupal)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# What a version asks for. `--version 11` is the latest release of that major, `--version 11.4.12`
# is that release, `--version 11.x-dev` is the development branch. Sets:
#   drupal_major        10, 11 or 12
#   drupal_constraint   what composer create-project is given
#   drupal_stability    the lowest stability composer may take ('' is composer's own: stable)
#   drupal_php          the PHP the major needs when the container tool's default is not enough ('' otherwise)
#   drupal_drush        the Drush that sits beside that major
# Returns 1, with a line that says why, for a version it does not know.
function drupal_resolve_version() {
  local version="${1:-11}" ;
  drupal_major="" ; drupal_constraint="" ; drupal_stability="" ; drupal_php="" ; drupal_drush="" ;

  if [[ "${version}" =~ ^[0-9]+$ ]] ; then
    drupal_major="${version}" ;
    drupal_constraint="^${version}" ;
  elif [[ "${version}" =~ ^([0-9]+)\.([0-9]+|x)\.x-dev$ ]] || [[ "${version}" =~ ^([0-9]+)\.x-dev$ ]] ; then
    drupal_major="${BASH_REMATCH[1]}" ;
    drupal_constraint="${version}" ;
    drupal_stability="dev" ;
  elif [[ "${version}" =~ ^([0-9]+)\.[0-9]+\.[0-9]+(-(alpha|beta|rc)[0-9]*)?$ ]] ; then
    drupal_major="${BASH_REMATCH[1]}" ;
    drupal_constraint="${version}" ;
    drupal_stability="${BASH_REMATCH[3]}" ;
    [ "${drupal_stability}" == 'rc' ] && drupal_stability="RC" ;
  else
    echo "--version ${version} is not a version this builder reads: a major (11, 12), a release (11.4.12, 12.0.0-beta2) or a development branch (11.x-dev)." ;
    return 1 ;
  fi

  case "${drupal_major}" in
    10)
      drupal_drush="^12 || ^13" ;
      ;;
    11)
      drupal_drush="^13" ;
      ;;
    12)
      # Drupal 12 needs PHP 8.5, more than the default of the container tool.
      drupal_php="8.5" ;
      # Until 12.0.0 is out, the latest release of the major is a pre-release; composer takes the
      # highest match, so the first stable release wins by itself the day it lands.
      [ -z "${drupal_stability}" ] && drupal_stability="${DRUPAL_12_STABILITY:-beta}" ;
      # No tagged Drush sits beside Drupal 12 yet: the development branch of Drush 14 does.
      drupal_drush="${DRUPAL_12_DRUSH:-14.x-dev}" ;
      ;;
    *)
      echo "--version ${version}: this builder knows Drupal 10, 11 and 12." ;
      return 1 ;
      ;;
  esac
  return 0 ;
}

# The DDEV project type of a major: drupal<major> when this DDEV offers it, else the general one.
function drupal_ddev_project_type() {
  local major="$1" ;
  if ddev config --help 2>/dev/null | grep -qE "[ ,]drupal${major}[,)]" ; then
    printf 'drupal%s' "${major}" ;
  else
    printf 'drupal' ;
  fi
}

# composer install, once more if it fails: the first install of a fresh project can fail on a
# network or cache hiccup and pass on the second try. A real dependency problem fails both times.
function drupal_composer_install_retry() {
  ddev composer install --no-interaction && return 0 ;
  echo "composer install failed once, trying it again before giving up." ;
  ddev composer install --no-interaction ;
}

# composer create-project in the current project folder, which holds only its .ddev directory.
function drupal_composer_create_project() {
  local package="$1" stability="$2" ;
  if ddev composer create-project "${package}" --no-interaction ${stability:+--stability=${stability}} ; then
    return 0 ;
  fi
  # When the project reached the install step, composer.json is already there: install once more.
  if [ -f composer.json ] && drupal_composer_install_retry ; then
    echo "composer create-project needed a second install, which worked." ;
    return 0 ;
  fi
  return 1 ;
}

# Drush in the project, and `ddev drush` answering. DDEV rewrites its shared command directory
# whenever any project on the machine starts, and `ddev drush` is missing from it for a moment:
# wait for it, instead of failing the install on its first line.
function drupal_add_drush() {
  local drush="$1" attempt ;
  if [ ! -d vendor/drush/drush ] ; then
    ddev composer require "drush/drush:${drush}" --no-interaction || return 1 ;
  fi
  for attempt in 1 2 3 4 5 6 7 8 9 10 ; do
    ddev drush --version > /dev/null 2>&1 && return 0 ;
    echo "ddev drush is not available yet (attempt ${attempt} of 10), waiting." ;
    sleep 6 ;
  done
  echo "ddev drush is still not available." ;
  return 1 ;
}

# The configuration sync directory, outside the docroot. The database settings are the container
# tool's (settings.ddev.php): this writes none.
function drupal_set_config_sync() {
  local project_path="$1" docroot="$2" ;
  local settings_file="${project_path}/${docroot}/sites/default/settings.php" ;
  mkdir -p "${project_path}/config/sync" ;
  if [ -f "${settings_file}" ] && ! grep -qE "^[[:space:]]*\\\$settings\['config_sync_directory'\]" "${settings_file}" ; then
    echo "\$settings['config_sync_directory'] = '../config/sync';" >> "${settings_file}" ;
  fi
}

# Is the site installed and answering Drush?
function drupal_is_installed() {
  ddev drush status --field=bootstrap 2>/dev/null | grep -qi successful ;
}

# Does a role exist on the site?
function drupal_role_exists() {
  ddev drush config:get "user.role.$1" id > /dev/null 2>&1 ;
}

# Does an account exist on the site?
function drupal_user_exists() {
  ddev drush user:information "$1" > /dev/null 2>&1 ;
}

# Build a Drupal core site from nothing: the container, the code, and with --install the site itself.
function drupal_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local version="${VERSION:-${site_version:-11}}" ;
  local profile="${PROFILE:-standard}" ;

  drupal_resolve_version "${version}" || exit 1 ;
  local php_version="${PHP_VERSION:-${drupal_php}}" ;
  local project_type ; project_type="$(drupal_ddev_project_type "${drupal_major}")" ;
  local package="${DRUPAL_PROJECT_TEMPLATE}:${drupal_constraint}" ;

  echo "Drupal ${drupal_major} for ${doc_name}/${PROJECT_NAME}:" ;
  echo "  code       ${package}${drupal_stability:+ (stability ${drupal_stability})}" ;
  echo "  container  project type ${project_type}, PHP ${php_version:-the default of the container tool}, Node.js $(ddev_nodejs_version)" ;
  echo "  Drush      drush/drush:${drupal_drush}" ;
  echo "  profile    ${profile}$([ "${INSTALL}" == 'yes' ] && echo ', installed' || echo ', not installed')$([ "${ADD_USERS}" == 'yes' ] && echo ', with the default accounts')" ;
  echo "  address    ${base_url}" ;
  if [ "${DRY_RUN}" == 'yes' ] ; then
    echo "A dry run: nothing was built." ;
    return 0 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;

  if ! ddev config --project-type=${project_type} --docroot=web --project-name=${PROJECT_NAME} \
    --nodejs-version=$(ddev_nodejs_version) ${php_version:+--php-version=${php_version}} --auto ; then
    echo "The container could not be configured." ;
    [ -n "${php_version}" ] && echo "If PHP ${php_version} is refused, this DDEV is older than the PHP that Drupal ${drupal_major} needs: update DDEV, then build again." ;
    exit 1 ;
  fi
  ddev_up start -y || exit 1 ;

  if ! drupal_composer_create_project "${package}" "${drupal_stability}" ; then
    echo "composer create-project failed for ${package}: the build stops here, nothing was installed." ;
    exit 1 ;
  fi

  # A pre-release major brings development versions with it (Drush, and what Drush needs).
  if [ -n "${drupal_stability}" ] ; then
    ddev composer config minimum-stability dev ;
    ddev composer config prefer-stable true ;
  fi

  # argparse hands a list option over as a bash array; [0] still reads the default when none was given.
  if [ ! "${REQUIRE[0]:-_none_}" == '_none_' ] ; then
    ddev composer require ${REQUIRE[*]} --no-interaction || { echo "composer require failed for: ${REQUIRE[*]}" ; exit 1 ; } ;
  fi

  drupal_add_drush "${drupal_drush}" || { echo "Drush could not be added: the build stops here." ; exit 1 ; } ;
  drupal_set_config_sync "${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" web ;

  if [ "${INSTALL}" == 'yes' ] ; then
    if ! ddev drush site:install "${profile}" --yes --site-name="${doc_name} ${PROJECT_NAME}" \
      --account-name="${account_name}" --account-pass="${account_pass}" --account-mail="${account_mail}" \
      --locale=en install_configure_form.enable_update_status_emails=NULL ; then
      echo "The install of ${doc_name} ${PROJECT_NAME} failed: drush site:install did not finish." ;
      echo "The project is kept for a look: ${base_url} (ddev logs, ddev drush status)." ;
      exit 1 ;
    fi
    if ! drupal_is_installed ; then
      echo "${doc_name} ${PROJECT_NAME} was installed, but the site does not bootstrap. Run: ddev drush status ; ddev logs." ;
      exit 1 ;
    fi

    if [ ! "${ENABLE[0]:-_none_}" == '_none_' ] ; then
      ddev drush pm:install ${ENABLE[*]} --yes || echo "Some of these could not be installed: ${ENABLE[*]}" ;
    fi

    if [ "${ADD_USERS}" == 'yes' ] ; then
      add_drupal_users ;
      cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
    fi
    ddev drush cache:rebuild ;

    echo "${doc_name} ${PROJECT_NAME} has been installed: Drupal $(ddev drush status --field=drupal-version 2>/dev/null), the ${profile} profile.";
    echo "Go to ${base_url}/user/login and log in as ${account_name}";
  else
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: there is no site to add accounts to yet." ;
    echo "${doc_name} ${PROJECT_NAME} is ready to install.";
    echo "Go to ${base_url}";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts with Drush. An account that is already there is left as it is, and
# a role the site does not have (the Minimal profile has no content editor) is said and skipped.
#
# The list is always this plugin's own: the workspace base still carries an older list under the
# same name, and its tools load that one just before they call this function.
function add_drupal_users() {
  drupal_enter_project || return 1 ;
  drupal_default_users ;
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo " ================================================================= ";

    if drupal_user_exists "${!user_name}" ; then
      echo "   ${!user_name} is already there." ;
    else
      ddev drush user:create "${!user_name}" --mail="${!user_mail}" --password="${!user_password}" ;
    fi
    if [ "${!user_role}" == '_none_' ] ; then
      echo "   No role for this account." ;
    elif drupal_role_exists "${!user_role}" ; then
      ddev drush user:role:add "${!user_role}" "${!user_name}" ;
    else
      echo "   The site has no ${!user_role} role: ${!user_name} is left without one." ;
    fi
  done
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Delete the default accounts, and what they wrote.
function cancel_drupal_users() {
  drupal_enter_project || return 1 ;
  drupal_default_users ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
    if drupal_user_exists "${!user_name}" ; then
      ddev drush user:cancel --delete-content "${!user_name}" --yes ;
    else
      echo "   ${!user_name} is not there." ;
    fi
  done
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# What cmd-tools-drupal-cli.sh does: the first of --run, --update, --cache-rebuild, --login,
# --add-users, --cancel-users that was asked for; with none of them, what the site is. It works on
# any Drupal project of the folder, whatever built it.
function drupal_cli_tool() {
  trim_project_name ;
  drupal_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # Handed to the shell of the container as one line, so an argument in quotes stays one
    # argument: --run "sql:query 'select name from users_field_data'".
    ddev exec "drush ${RUN}" ;
    exit $? ;
  fi

  if [ "${UPDATE}" == 'yes' ] ; then
    ddev composer update --with-all-dependencies --no-interaction || exit 1 ;
    ddev drush updatedb --yes ;
    ddev drush cache:rebuild ;
  elif [ "${CACHE_REBUILD}" == 'yes' ] ; then
    ddev drush cache:rebuild ;
  elif [ "${LOGIN}" == 'yes' ] ; then
    echo "A one-time login link for the site's first account:" ;
    ddev drush user:login --no-browser ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    add_drupal_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    cancel_drupal_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}:" ;
    ddev drush status --fields=drupal-version,uri,install-profile,theme,admin-theme,php-version,db-driver,bootstrap ;
    echo "" ; echo "Accounts:" ;
    ddev drush sql:query "SELECT u.name, u.mail, COALESCE(GROUP_CONCAT(r.roles_target_id), '') AS roles FROM users_field_data u LEFT JOIN user__roles r ON r.entity_id = u.uid WHERE u.uid > 0 GROUP BY u.uid, u.name, u.mail ORDER BY u.uid" ;
    echo "" ; echo "Pending database updates:" ;
    ddev drush updatedb:status ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Drupal core project. The core's testing_configure calls
# this in the project folder once webship-js is scaffolded and before the dependencies are
# installed; for a project that is not a Drupal core site (another platform, a distribution,
# Drupal CMS) it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's
# own, gives cucumber.js the users registry of the default accounts (a handle a scenario reads,
# mapped to an account; never the workspace account), and writes a first feature when the project
# has none of its own. Every part is skipped when it is already there, so a second run adds what
# the first missed, never lists the pack twice and never resets a suite.
function testing_configure_drupal() {
  local project_path="$1";
  drupal_is_core_site "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Drupal: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Drupal core step pack (${DRUPAL_STEPS_PACKAGE} ${DRUPAL_STEPS_VERSION}).";
  drupal_default_users ;
  # handle | the name of its environment variables | account | password | mail | role
  local registry="" user user_name user_password user_mail user_role handle ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_password="user_${user}_password";
    user_mail="user_${user}_mail"; user_role="user_${user}_role";
    # The pack's features call the administrator "admin".
    handle="${user}" ; [ "${user}" == 'administrator' ] && handle="admin" ;
    registry="${registry}${handle}|${handle^^}|${!user_name}|${!user_password}|${!user_mail}|${!user_role}"$'\n' ;
  done

  python3 - "${project_path}" "${DRUPAL_STEPS_PACKAGE}" "${DRUPAL_STEPS_VERSION}" "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, registry = sys.argv[1:5]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=2) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, and the users registry.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
    if not world:
        sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
    pad = world.group(1) + '  '
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    block = [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this site (the default",
        pad + "// accounts: cmd-tools-add-users.sh). Override one with DRUPAL_<HANDLE>_USER, DRUPAL_<HANDLE>_PASS",
        pad + "// and DRUPAL_<HANDLE>_MAIL.",
        pad + "users: {",
    ]
    for handle, env, name, password, mail, role in rows:
        key = handle if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', handle) else "'%s'" % handle
        roles = '[]' if role == '_none_' else "['%s']" % role
        block.append(pad + "  %s: { username: process.env.DRUPAL_%s_USER || '%s', password: process.env.DRUPAL_%s_PASS || '%s', email: process.env.DRUPAL_%s_MAIL || '%s', roles: %s },"
                     % (key, env, name, env, password, env, mail, roles))
    block.append(pad + "},")
    src = src[:world.end()] + '\n' + '\n'.join(block) + src[world.end():]
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet: the front page, the login page,
  # each default account and what its role may reach.
  local feature="${WORKSPACE_SCRIPTS}/plugins/drupal/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the site" ;
  fi

  # The scenarios log in as the default accounts: make sure an installed site has them.
  if drupal_is_installed ; then
    ( add_drupal_users > /dev/null ) && echo "  the default accounts are on the site (${users[*]})" ;
  fi
}
