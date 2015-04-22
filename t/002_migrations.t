use Mojo::Base -strict;

BEGIN {
	$ENV{MOJO_MIGRATION_TMP  } ||= 'testtmp';
	$ENV{MOJO_MIGRATION_SHARE} ||= 'testshare';
};
 
use Test::More;
use lib 'lib';
use DBI;
use File::Path qw(make_path remove_tree);
use Mojo::Asset::File;
use Data::Dumper;
 
plan skip_all => 'set TEST_ONLINE to enable this test'
	unless $ENV{TEST_ONLINE};

use_ok 'Mojolicious::Command::migration';

my $config = do 't/mysql.conf';

remove_tree 'testtmp'   if -d 'testtmp';
remove_tree 'testshare' if -d 'testshare';

my $db = DBI->connect('dbi:mysql:'.$config->{datasource}->{database}, $config->{user}, $config->{password});
$db->do('drop table if exists test') if @{$db->selectall_arrayref('show tables', { Slice => {} })};

mkdir $_ for qw/testtmp testshare/;

my $migration = Mojolicious::Command::migration->new;
$migration->config($config);

is_deeply $migration->deployed, {}, 'right deployed';

my $deployed = {
	version => '1.12',
};

$migration->deployed($deployed);
$migration->save_deployed;

$migration = Mojolicious::Command::migration->new;
$migration->config($config);

is_deeply $migration->deployed, $deployed, 'right deployed';

is $migration->get_last_version, undef, 'right get_last_version';

my $buffer = '';

unlink $migration->paths->{deploy_status} if -e $migration->paths->{deploy_status};

$migration = Mojolicious::Command::migration->new;
$migration->config($config);

{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('status');
}
like $buffer, qr/Migration dont initialized/,
  'right output';


$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('install');
}
like $buffer, qr/Migration dont initialized/,
  'right install';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('upgrade');
}
like $buffer, qr/Migration dont initialized/,
  'right install';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('prepare');
}
like $buffer, qr/Initialization/,
  'right output';
like $buffer, qr/Nothing to prepare/,
  'right output';

$db->do('create table test (id int(11))');

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('prepare');
}
like $buffer, qr/Initialization/,
  'right output';
like $buffer, qr/New schema version: 1/,
  'right output';

ok -s $migration->paths->{source_deploy}."/1/001_auto.yml", 'deploy _source exists';
ok -s $migration->paths->{db_deploy    }."/1/001_auto.sql", 'deploy mysql exists';

my $file = Mojo::Asset::File->new(path => $migration->paths->{db_deploy}."/1/001_auto.sql")->slurp;
like $file, qr/CREATE TABLE `test`/,
  'right mysql deploy';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('status');
}
like $buffer, qr/Schema version: 1/,
  'right status';
like $buffer, qr/Database is not deployed/,
  'right status';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('prepare');
}
like $buffer, qr/Schema version: 1/,
  'right output';
like $buffer, qr/Nothing to upgrade/,
  'right output';

$db->do('alter table test add name varchar(255) not null default ""');

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('prepare');
}
like $buffer, qr/Schema version: 1/,
  'right output';
like $buffer, qr/New schema version: 2/,
  'right output';
ok -s $migration->paths->{source_deploy}."/2/001_auto.yml", 'deploy _source exists';
ok -s $migration->paths->{db_deploy    }."/2/001_auto.sql", 'deploy mysql exists';
ok -s $migration->paths->{db_upgrade   }."/1-2/001_auto.sql", 'upgrade mysql exists';
ok -s $migration->paths->{db_downgrade }."/2-1/001_auto.sql", 'downgrade mysql exists';

$file = Mojo::Asset::File->new(path => $migration->paths->{db_upgrade}."/1-2/001_auto.sql")->slurp;
like $file, qr/ALTER TABLE test ADD COLUMN name varchar\(255\) NOT NULL DEFAULT ''/,
  'right mysql upgrade';

$file = Mojo::Asset::File->new(path => $migration->paths->{db_downgrade}."/2-1/001_auto.sql")->slurp;
like $file, qr/ALTER TABLE test DROP COLUMN name/,
  'right mysql downgrade';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('status');
}
like $buffer, qr/Schema version: 2/,
  'right status';
like $buffer, qr/Database is not deployed/,
  'right status';



$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('install');
}
like $buffer, qr/Database is not empty/,
  'right install';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('install', '--force');
}
is_deeply $migration->params, {}, 'params was cleaned';

like $buffer, qr/Force deploy to 2/,
  'right force install';

is $migration->get_last_version, $migration->deployed->{version}, 'right deployed';

unlink $migration->paths->{deploy_status} if -e $migration->paths->{deploy_status};
$migration->deployed({});

$db->do('drop table if exists test');

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('install');
}
like $buffer, qr/Deploy database to 2/,
  'right install';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('prepare');
}
like $buffer, qr/Schema version: 2/,
  'right output';
like $buffer, qr/Deployed database is 2/,
  'right output';
like $buffer, qr/Nothing to upgrade/,
  'right output';

unlink $migration->paths->{deploy_status} if -e $migration->paths->{deploy_status};
$migration->deployed({});

$db->do('drop table if exists test');

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('install', '--to-version', 10);
}
like $buffer, qr/Schema 10 not exists/,
  'right install';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('install', '--to-version', 1);
}
like $buffer, qr/Schema version: 2/,
  'right output';
like $buffer, qr/Deploy database to 1/,
  'right install';

is $migration->deployed->{version}, 1, 'right deployed';

unlink $migration->paths->{deploy_status} if -e $migration->paths->{deploy_status};
$migration->deployed({});

$db->do('drop table if exists test');

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('upgrade');
}
like $buffer, qr/Database is not installed/,
  'right upgrade';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('downgrade');
}
like $buffer, qr/Database is not installed/,
  'right downgrade';

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('install', '--to-version', 1);
}

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('upgrade', '--to-version', 1);
}
like $buffer, qr/Database is already deployed to 1/,
  'right upgrade';
is $migration->deployed->{version}, 1, 'right deployed';

$buffer = '';
my $current = $migration->deployed->{version};
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('upgrade');
}
is $migration->deployed->{version}, $migration->get_last_version, 'right deployed';

like $buffer, qr/Database version: $current/,
  'right upgrade';

for my $upgrade ($current + 1 .. $migration->get_last_version) {
	next unless -s $migration->paths->{db_upgrade}."/$current-$upgrade/001_auto.sql";


	like $buffer, qr/Upgrade to $upgrade/,
	  'right upgrade to XXX';

	$current++;
}

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('downgrade');
}
like $buffer, qr/Schema version: 2/,
  'right output';
like $buffer, qr/Database version: 2/,
  'right output';
is $migration->deployed->{version}, 1, 'right deployed';

for my $downgrade ($current - 1) {
	next unless -s $migration->paths->{db_downgrade}."/$current-$downgrade/001_auto.sql";


	like $buffer, qr/Downgrade to $downgrade/,
	  'right downgrade to XXX';

	$current--;
}

$buffer = '';
{
	open my $handle, '>', \$buffer;
	local *STDOUT = $handle;
	$migration->run('downgrade');
}
like $buffer, qr/Schema version: 2/,
  'right output';
like $buffer, qr/Nothing to downgrade/,
  'right output';

done_testing;