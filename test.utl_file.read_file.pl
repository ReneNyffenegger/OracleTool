use warnings;
use strict;

use OracleTool qw(connect_db);
use OracleTool::UtlFile;

my $connection_string = shift;

my $dbh = connect_db($connection_string);

$dbh -> do("create directory TEST_TEMP as 'c:\\temp'");

create_a_file();

my $utl_file =  OracleTool::UtlFile->fopen($dbh, 'TEST_TEMP', 'test.txt', 'r');

my $line;
die if     $utl_file -> get_line($line); die unless $line eq 'First line';
die if     $utl_file -> get_line($line); die unless $line eq 'Second line';
die if     $utl_file -> get_line($line); die unless $line eq 'Third line';
die unless $utl_file -> get_line($line);

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
