use warnings;
use strict;

use OracleTool qw(connect_db utl_file_get);

my $connection_string = shift;

my $dbh = connect_db($connection_string);

$dbh -> do("create directory TEST_TEMP as 'c:\\temp'");

create_a_file();


my $file_content = utl_file_get($dbh, 'TEST_TEMP', 'test.txt');

die $file_content unless $file_content eq "First line\nSecond line\nThird line";

$dbh -> do("drop directory TEST_TEMP");
$dbh -> rollback;

sub create_a_file { # {{{
  
  $dbh -> do (q{
  
    declare
      f utl_file.file_type;
    begin
  
      f := utl_file.fopen('TEST_TEMP', 'test.txt', 'W');
      
      utl_file.put_line(f, 'First line');
      utl_file.put_line(f, 'Second line');
      utl_file.put_line(f, 'Third line');
      utl_file.fclose(f);
  
    end;
  
  });
  
    
} # }}}
