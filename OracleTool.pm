=encoding utf8
=cut
use     utf8;
package OracleTool;
=head1 NAME

OracleTool

=head1 DESCRIPTION

Making some tasks on Oracle a bit easier, at least for me...

=head1 AUTHOR

René Nyffenegger


=cut

use warnings;
use strict;

use Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA          = qw(Exporter);
$VERSION      = 0.01;
@EXPORT       = qw();
@EXPORT_OK    = qw(connect_db);
%EXPORT_TAGS  = ();

use DBD::Oracle;

=head1 FUNCTIONS
=cut

sub connect_db { # {{{

=head2 C<connect_db>


Connects to an Oracle databse, returns a C<DBI::db> object.

 my $dbh = connect_db('username/password');
 my $dbh = connect_db('username/password@database');

=cut

  my $logon = shift;

  my ($username, $password, $db) = $logon =~ m!(.*)/(.[^@]*)@?(.*)!;

  my $dbh = DBI->connect("dbi:Oracle:$db", $username, $password) or die;

  die unless $dbh;

  $dbh->{AutoCommit} = 0;
  $dbh->{HandleError} = \&error_handler;
  $dbh->{PrintError} = 0;

  return $dbh;
  
} # }}}

sub error_handler { # {{{
=head2 C<error_handler>

Handle Oracle errors - currently, just prints the error message to STDOUT.

=cut

  my $error = shift;

  print "\n\n$error\n\n";

} # }}}


"tq84";
