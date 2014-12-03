use warnings;
use strict;

use OracleTool qw(connect_db);

my $connection_string = shift;


my $dbh = connect_db($connection_string);

my $sth = $dbh -> prepare("select to_char(sysdate, 'hh24:mi:ss dd.mm.yyyy') from dual") or die;
$sth -> execute;

my ($sysdate) = $sth -> fetchrow_array;

$sth -> finish;
$dbh -> disconnect;

print "\n  sysdate: $sysdate\n";
