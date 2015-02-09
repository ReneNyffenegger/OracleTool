package OracleTool::UtlFile;


sub fopen { # {{{
    my $self           = {};

    bless $self , shift;

    my $dbh            = shift;
    my $directory_name = shift;
    my $file_name      = shift;
    my $mode           = shift;


    $self -> {dbh} = $dbh;

    my $stmt = $self->{dbh}->prepare (q{
      declare
        f  utl_file.file_type;
      begin

        f := utl_file.fopen(:location, :filename, :open_mode);

        :f_id       := f.id;
        :f_datatype := f.datatype;
        :f_bytemode := case when f.byte_mode then 1 else 0 end;

      end;

    });

    $self -> {f} -> {id}       = 0;
    $self -> {f} -> {datatype} = 0;
    $self -> {f} -> {bytemode} = 0;

    $stmt -> bind_param(':location' , $directory_name);
    $stmt -> bind_param(':filename' , $file_name     );
    $stmt -> bind_param(':open_mode', $mode          );

    $stmt -> bind_param_inout(':f_id'      , \$self->{f}->{id}      , 10);
    $stmt -> bind_param_inout(':f_datatype', \$self->{f}->{datatype}, 10);
    $stmt -> bind_param_inout(':f_bytemode', \$self->{f}->{bytemode}, 10);

    $stmt -> execute;

    return $self;

} # }}}

sub get_line { # {{{
    my $self = shift;

    unless (exists $self->{sth}->{get_line}) {
      $self->{sth}->{get_line} = $self->{dbh}->prepare(q{
        declare
          f   utl_file.file_type;
        begin
          f.id        := :f_id;
          f.datatype  := :f_datatype;
          f.byte_mode := :f_bytemode = 1;

          utl_file.get_line(f, :line);

         :end_of_file := 0;
        exception when no_data_found then
         :end_of_file := 1;
        end;
      });
    }

    $self->{sth}->{get_line} -> bind_param(':f_id'       , $self->{f}->{id}      );
    $self->{sth}->{get_line} -> bind_param(':f_datatype' , $self->{f}->{datatype});
    $self->{sth}->{get_line} -> bind_param(':f_bytemode' , $self->{f}->{bytemode});

    $self->{sth}->{get_line} -> bind_param_inout(':end_of_file', \my $eof ,   10);
    $self->{sth}->{get_line} -> bind_param_inout(':line'       , \my $line, 4000);

    $self->{sth}->{get_line} -> execute;

    $_[0] = $line;

    return 1-$eof;

} # }}}

"tq84";
