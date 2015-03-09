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
$VERSION      = 0.02;
@EXPORT       = qw();
@EXPORT_OK    = qw(
                  connect_db
                  describe_table
                  sequence_nextval
                  username
                  utl_file_get);
%EXPORT_TAGS  = ();

use DBD::Oracle;

use OracleTool::UtlFile;

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
  $dbh->{LongReadLen} = 32000; # the default of 80 is way too small, I think
  
  $dbh->do("alter session set nls_date_format = 'yyyy.mm.dd hh24:mi:ss'");

  return $dbh;
  
} # }}}

sub username { # {{{

=head2 C<connect_db>

returns the username part of a connection string

 my $user  = username('someUser/password@somewhere'); // return 'someUser'

=cut

  my $logon = shift;
  my ($username, $password, $db) = $logon =~ m!(.*)/(.[^@]*)@?(.*)!;
  return $username;

} # }}}

sub describe_table { # {{{

=head2 C<describe_table>

Describes a table.

 my $description = describe_table($dbh, 'FOO_TABLE', 'FOO_OWNER');

 ... $description->{cols}->[$col_no]->{name};
 ... $description->{cols}->[$col_no]->{data_type};
 ... $description->{cols}->[$col_no]->{virt};

 ... $description->{cols}->[$col_no]->{pk}

 ... $description->{fks}->[$fk_no]->{name}
 ... $description->{fks}->[$fk_no]->{tab}
 ... $description->{fks}->[$fk_no]->{cols}->[$col_no]

=cut

  my $dbh         = shift;
  my $table_name  = shift;
  my $owner       = shift;

  my $ret;

  #   Columns and Primary Keys {{{

  my $sth = $dbh -> prepare (qq {

    select
      cl.column_name,
      cl.data_type,
      cl.column_id,
      pc.position                  -1 pk_position,
      case cl.virtual_column
           when 'YES' then 1
                      else 0 end      virt
    from
      all_tab_cols    cl                                              left join
      all_constraints pk  on cl.table_name      = pk. table_name and
                             cl.owner           = pk.owner       and
                             pk.constraint_type = 'P'                 left join
      all_cons_columns pc on pk.constraint_name = pc.constraint_name and
                             pk.owner           = pc.owner           and
                             cl.column_name     = pc.column_name
    where
      cl.table_name = ? and 
      cl.owner      = ?
    order by 
      cl.column_id
      });
      
  

  $sth -> execute($table_name, $owner);


  while (my $r = $sth-> fetchrow_hashref) {

    push @{$ret->{cols}}, {
      name => $r->{COLUMN_NAME},
      pk   => $r->{PK_POSITION},
      type => $r->{DATA_TYPE},
      virt => $r->{VIRT}
    } 
  }

  # }}}
  
  # {{{ Foreign keys

    my $sth_fk = $dbh -> prepare("
    
         select
           fk.constraint_name   constraint_name_fk,
           pk.constraint_name   constraint_name_pk,
           pk.table_name        table_name_pk
         from
           dba_constraints fk                                                  join
           dba_constraints pk on fk.r_constraint_name = pk.constraint_name 
         where
           fk.table_name = ? and
           fk.owner      = ?
    
    ");

    my $sth_fk_columns = $dbh -> prepare ("

         select
           ft.column_id   -1  position,
           fk.column_name     fk_column,
           pk.column_name     pk_column
         from
           dba_cons_columns    fk                                    join
           dba_cons_columns    pk on fk.position    = pk.position    join
           dba_tab_columns     ft on fk.column_name = ft.column_name 
         where
           fk.constraint_name =  ? and
           pk.constraint_name =  ? and
           ft.table_name      =  ?

        ");

    $sth_fk -> execute ($table_name, $owner);


#   my @ret =();

    while (my $r = $sth_fk -> fetchrow_hashref) {

      my $fk_ = {tab => $r->{TABLE_NAME_PK}, name=>$r->{CONSTRAINT_NAME_FK}};

      $sth_fk_columns -> execute($r->{CONSTRAINT_NAME_FK}, $r->{CONSTRAINT_NAME_PK}, $table_name);

      while (my $q = $sth_fk_columns -> fetchrow_hashref) {
         push @{ $fk_->{cols} }, {fk => $q->{FK_COLUMN}, pk => $q->{PK_COLUMN}, pos => $q->{POSITION}};
      }

      push @{$ret->{fks}}, $fk_;
    }

    $sth_fk         -> finish;
    $sth_fk_columns -> finish;

  # }}}


  return $ret;

} # }}}

sub utl_file_get { # {{{

    my $dbh            = shift;
    my $directory_name = shift;
    my $file_name      = shift;

    my $line;
    my $ret  ='';

    my $utl_file = OracleTool::UtlFile -> fopen($dbh, $directory_name, $file_name, 'r');
    while ($utl_file->get_line($line)) {
      $ret .= "\n" if $ret;
      $ret .= $line;
    }

    return $ret;
    
} # }}}

sub sequence_nextval { # {{{

    my $dbh      = shift;
    my $sequence = shift;
    my $nextval  = shift;  

    my $owner='';

   ($owner, $sequence) = split /\./, $sequence if $sequence =~ /\./;

    $owner    = uc $owner;
    $sequence = uc $sequence;



    $dbh -> do (qq{

      declare
        inc_orig number;
        inc_new  number;
        own      varchar2(30);
        nv       number := $sequence.nextval;
      begin
 
        select sequence_owner, increment_by into own, inc_orig
          from all_sequences
         where sequence_owner = nvl('$owner', user) and
               sequence_name  = '$sequence';

        inc_new := $nextval - nv - inc_orig;
        execute immediate 'alter sequence ' || own || '.' || '$sequence' || ' increment by ' || inc_new;
        execute immediate 'select ' || own || '.$sequence.nextval from dual' into nv;
        execute immediate 'alter sequence ' || own || '.' || '$sequence' || ' increment by ' || inc_orig;

      end;


    });
     

    
} # }}}

sub error_handler { # {{{
=head2 C<error_handler>

Handle Oracle errors - currently, just prints the error message to STDOUT.

=cut

  my $error = shift;

  print "\n\n$error\n\n";

} # }}}


"tq84";
