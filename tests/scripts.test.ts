import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-drupal.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/** A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. */
function project(type: string, composer: Record<string, unknown> = { require: { 'drupal/core-recommended': '^11' } }) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'drupal-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${type}\ndocroot: web\n`);
  fs.writeFileSync(path.join(dir, 'composer.json'), JSON.stringify(composer, null, 2));
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'drupal'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'drupal', 'site.feature'));
  return { root, dir, scripts };
}

// `ddev` replaced by a recorder: the site is installed, no account is there yet, every role exists
// but the one named in NO_ROLE, and `ddev config --help` offers the project types in DDEV_TYPES.
const DDEV = `ddev() {
  echo "ddev $*" >> "\${DDEV_LOG:-/dev/null}" ;
  [ "$1 $2" == "config --help" ] && { echo "      --project-type string   (one of \${DDEV_TYPES:-drupal, drupal10, drupal11, php})." ; return 0 ; } ;
  [ "$1 $2 $3" == "drush status --field=bootstrap" ] && { echo Successful ; return 0 ; } ;
  [ "$1 $2" == "drush user:information" ] && return 1 ;
  [ "$1 $2" == "drush config:get" ] && { [ "$3" == "user.role.\${NO_ROLE:-}" ] && return 1 ; return 0 ; } ;
  return 0 ;
}`;

/** Run bash with the plugin's functions sourced and `ddev` replaced by the recorder. */
function bash(script: string, env: Record<string, string> = {}) {
  return spawnSync('bash', ['-c', `${DDEV}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

test('the default accounts are an administrator, a content editor and an account with no role, with example addresses', () => {
  const r = bash('set_drupal_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; l="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!l}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'editor', 'authenticated']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['administrator', 'content_editor', '_none_']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 8);
  }
});

test('a version is read as a major, a release or a development branch, with what that major needs', () => {
  const plan = (v: string) => bash(`drupal_resolve_version "${v}" ; echo "rc=$?|$drupal_major|$drupal_constraint|$drupal_stability|$drupal_php|$drupal_drush"`).stdout.trim().split('\n').pop();
  assert.strictEqual(plan('11'), 'rc=0|11|^11|||^13');
  assert.strictEqual(plan('11.4.12'), 'rc=0|11|11.4.12|||^13');
  assert.strictEqual(plan('11.x-dev'), 'rc=0|11|11.x-dev|dev||^13');
  assert.strictEqual(plan('10'), 'rc=0|10|^10|||^12 || ^13');
  assert.strictEqual(plan('12'), 'rc=0|12|^12|beta|8.5|14.x-dev', 'Drupal 12: PHP 8.5, a pre-release floor, the development Drush');
  assert.strictEqual(plan('12.0.0-beta2'), 'rc=0|12|12.0.0-beta2|beta|8.5|14.x-dev');
  assert.strictEqual(plan('12.0.0'), 'rc=0|12|12.0.0|beta|8.5|14.x-dev');
  assert.match(plan('9') as string, /^rc=1\|/);
  assert.match(plan('latest') as string, /^rc=1\|/);
});

test('the project type is the major\'s own when the container tool offers it, and the general one when it does not', () => {
  assert.strictEqual(bash('drupal_ddev_project_type 11').stdout, 'drupal11');
  assert.strictEqual(bash('drupal_ddev_project_type 12').stdout, 'drupal');
  assert.strictEqual(bash('drupal_ddev_project_type 12', { DDEV_TYPES: 'drupal, drupal11, drupal12, php' }).stdout, 'drupal12');
});

test('a dry run says what would be built and touches nothing', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'drupal-plugin-'));
  fs.mkdirSync(path.join(root, 'dev'));
  const log = path.join(root, 'ddev.log');
  const r = bash('trim_project_name() { :; } ; ddev_nodejs_version() { echo 24 ; } ; drop_database() { echo DROPPED ; } ; PROJECT_NAME=site1 ; VERSION=12 ; PROFILE=standard ; INSTALL=yes ; ADD_USERS=yes ; DRY_RUN=yes ; drupal_build',
    { WORKSPACE_ROOT: root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr);
  assert.match(r.stdout, /drupal\/recommended-project:\^12 \(stability beta\)/);
  assert.match(r.stdout, /project type drupal, PHP 8\.5, Node\.js 24/);
  assert.match(r.stdout, /drush\/drush:14\.x-dev/);
  assert.match(r.stdout, /standard, installed, with the default accounts/);
  assert.match(r.stdout, /A dry run: nothing was built\./);
  assert.doesNotMatch(r.stdout, /DROPPED/);
  assert.ok(!fs.existsSync(path.join(root, 'dev', 'site1')));
  assert.strictEqual(fs.readFileSync(log, 'utf8').trim(), 'ddev config --help', 'the container tool was only asked what it offers');
});

test('a build configures the container, creates the code, adds Drush, installs with the workspace account and adds the accounts', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'drupal-plugin-'));
  fs.mkdirSync(path.join(root, 'dev'));
  const log = path.join(root, 'ddev.log');
  const r = bash('trim_project_name() { :; } ; ddev_nodejs_version() { echo 24 ; } ; drop_database() { :; } ; ddev_up() { mkdir -p .ddev ; printf "type: drupal11\\ndocroot: web\\n" > .ddev/config.yaml ; } ; sleep() { :; } ;'
    + ' PROJECT_NAME=site1 ; VERSION=11 ; PROFILE=standard ; INSTALL=yes ; ADD_USERS=yes ; REQUIRE=_none_ ; ENABLE=(media token) ; account_name=owner ; account_pass=secret ; account_mail=owner@example.com ; drupal_build',
    { WORKSPACE_ROOT: root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const calls = fs.readFileSync(log, 'utf8');
  assert.match(calls, /ddev config --project-type=drupal11 --docroot=web --project-name=site1 --nodejs-version=24 --auto/);
  assert.match(calls, /ddev composer create-project drupal\/recommended-project:\^11 --no-interaction\n/);
  assert.match(calls, /ddev composer require drush\/drush:\^13 --no-interaction/);
  assert.match(calls, /ddev drush site:install standard --yes --site-name=dev site1 --account-name=owner --account-pass=secret --account-mail=owner@example\.com/);
  assert.doesNotMatch(calls, /db-url/);
  assert.match(calls, /ddev drush pm:install media token --yes/);
  assert.match(calls, /ddev drush user:create editor --mail=editor@example\.com/);
  assert.match(calls, /ddev drush user:role:add content_editor editor/);
  assert.doesNotMatch(calls, /user:role:add \S+ authenticated/, 'the account with no role gets none');
  assert.ok(fs.existsSync(path.join(root, 'dev', 'site1', 'config', 'sync')));
});

test('a role the site does not have is said, and the account is still added', () => {
  const p = project('drupal11');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('add_drupal_users', { WORKSPACE_ROOT: p.root, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, NO_ROLE: 'content_editor' });
  assert.strictEqual(r.status, 0, r.stderr);
  assert.match(r.stdout, /The site has no content_editor role: editor is left without one\./);
  const calls = fs.readFileSync(log, 'utf8');
  assert.match(calls, /ddev drush user:create editor /);
  assert.doesNotMatch(calls, /user:role:add content_editor/);
});

test('the accounts are this plugin\'s own even after the base loaded its older list under the same name', () => {
  const p = project('drupal11');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_drupal_users() { users=(old) ; user_old_name="Old" ; } ; set_drupal_users ; add_drupal_users > /dev/null ; echo "${users[*]}"',
    { WORKSPACE_ROOT: p.root, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  assert.strictEqual(r.stdout.trim(), 'administrator editor authenticated');
  assert.doesNotMatch(fs.readFileSync(log, 'utf8'), /user:create Old/);
});

test('the testing hook adds the step pack, the users registry and a first feature to a Drupal core project, once', () => {
  const p = project('drupal11');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_drupal ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/drupal-core-steps'], '^2.2.1');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/drupal-core-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /admin: \{ username: process\.env\.DRUPAL_ADMIN_USER \|\| 'administrator', password: process\.env\.DRUPAL_ADMIN_PASS \|\| '[^']+', email: process\.env\.DRUPAL_ADMIN_MAIL \|\| 'administrator@example\.com', roles: \['administrator'\] \},/);
  assert.match(cucumber, /editor: \{ username: process\.env\.DRUPAL_EDITOR_USER \|\| 'editor'.*roles: \['content_editor'\] \},/);
  assert.match(cucumber, /authenticated: \{ username: process\.env\.DRUPAL_AUTHENTICATED_USER \|\| 'authenticated'.*roles: \[\] \},/);
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users)]))`], { encoding: 'utf8' });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['admin', 'editor', 'authenticated']);
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /ddev drush user:create editor --mail=editor@example\.com/, 'an installed site gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  const again = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  assert.strictEqual(again, cucumber);
  assert.strictEqual(again.split('@webship-js/drupal-core-steps').length - 1, 1, 'the pack is listed once');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8').split('@webship-js/drupal-core-steps').length - 1, 1);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook adds nothing a project already lists', () => {
  const p = project('drupal11');
  const listed = SCAFFOLD.replace("      'tests/step-definitions/**/*.js',", "      'node_modules/@webship-js/drupal-core-steps/tests/step-definitions/**/*.js',\n      'tests/step-definitions/**/*.js',");
  fs.writeFileSync(path.join(p.dir, 'cucumber.js'), listed);
  fs.writeFileSync(path.join(p.dir, 'package.json'), JSON.stringify({ name: 'site1', dependencies: { '@webship-js/drupal-core-steps': '^2.1.0' } }, null, 2));
  const r = bash(`cd ${p.dir} && testing_configure_drupal ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.dependencies['@webship-js/drupal-core-steps'], '^2.1.0', 'the version the project chose stays');
  assert.strictEqual(pkg.devDependencies, undefined);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8').split('@webship-js/drupal-core-steps').length - 1, 1);
});

test('the testing hook leaves alone a project of another platform, a distribution, Drupal CMS and a project with its own testing command', () => {
  const others = [
    project('wordpress'),
    project('drupal11', { require: { 'drupal/drupal_cms_starter': '^2' } }),
    project('drupal11', { require: { 'drupal/cms': '^2' } }),
    (() => { const p = project('drupal11'); fs.mkdirSync(path.join(p.dir, 'web', 'profiles', 'contrib', 'webship'), { recursive: true }); return p; })(),
    (() => { const p = project('drupal11'); fs.mkdirSync(path.join(p.dir, '.ddev', 'commands', 'web'), { recursive: true }); fs.writeFileSync(path.join(p.dir, '.ddev', 'commands', 'web', 'init-full-automated-testing'), ''); return p; })(),
  ];
  for (const p of others) {
    const r = bash(`cd ${p.dir} && testing_configure_drupal ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
    assert.strictEqual(r.status, 0);
    assert.strictEqual(r.stdout, '');
    assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
    assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
  }
});

test('the Drush tool refuses a project that is not Drupal, and runs a command on one that is', () => {
  const other = project('wordpress');
  const refused = bash('PROJECT_NAME=site1 ; RUN="pm:list" ; trim_project_name() { :; } ; drupal_cli_tool', { WORKSPACE_ROOT: other.root, doc_name: 'dev' });
  assert.strictEqual(refused.status, 1);
  assert.match(refused.stdout, /is not a Drupal project/);
  const p = project('drupal11');
  const log = path.join(p.root, 'ddev.log');
  const ran = bash('PROJECT_NAME=site1 ; RUN="pm:list --status=enabled" ; trim_project_name() { :; } ; drupal_cli_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(ran.status, 0, ran.stderr);
  assert.match(fs.readFileSync(log, 'utf8'), /ddev exec drush pm:list --status=enabled\n/);
  const link = bash('PROJECT_NAME=site1 ; RUN=_none_ ; LOGIN=yes ; trim_project_name() { :; } ; drupal_cli_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(link.status, 0, link.stderr);
  assert.match(fs.readFileSync(log, 'utf8'), /ddev drush user:login --no-browser/);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /drupal/i, s);
  assert.doesNotMatch(feature, /password "/);
  assert.doesNotMatch(feature, /user:create|I register|testing users/i, 'a suite never creates an account');
});
