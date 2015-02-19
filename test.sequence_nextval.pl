use warnings;
use strict;

use OracleTool qw(connect_db sequence_nextval);

my $connection_string = shift;
my $dbh = connect_db($connection_string);

$dbh -> do ('drop sequence tq84_test_sequence');
$dbh -> do ('create sequence tq84_test_sequence start with 500 increment by 100');

my $sth = $dbh -> prepare ('select tq84_test_sequence.nextval from dual');

my $nv;


test_nextval(500);
test_nextval(600);

sequence_nextval($dbh, 'tq84_test_sequence', 11111);

test_nextval(11111);
test_nextval(11211);

$dbh->rollback;


sub test_nextval { # {{{
    my $expected = shift;

    $sth -> execute;
    my ($nv) = $sth->fetchrow_array;

    die unless $nv == $expected;

} # }}}
