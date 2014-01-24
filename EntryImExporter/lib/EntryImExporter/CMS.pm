package EntryImExporter::CMS;

use strict;
use warnings;
use lib qw( addons/Commercial.pack/lib );

use MT::App;
use MT::Blog;
use MT::Website;
use MT::Author;
use MT::Entry;
use MT::Category;
use MT::Log;
use MT::Plugin;
use MT::ObjectTag;
use MT::Tag;
use MT::I18N;
use MT::Request;

# CAN'T work without CustomField
use CustomFields::Util qw( get_meta save_meta );
use CustomFields::Field;

use File::Basename;
use HTTP::Date qw( parse_date );
use MT::Util qw( format_ts is_valid_date );
use Text::CSV_PP;
use Data::Dumper;

use base qw( MT::App );

our $CACHE_KEY = 'EntryImExporter::_allow_blogs';

my $plugin = MT->instance->component( 'EntryImExporter' ); #11827 add instance;

########################################################################
#   CMS application methods
########################################################################
sub disp_entry {
    my $app = shift;

    return $app->return_to_dashboard( permission => 1 )
         unless _permission_check();

    my $tmpl = $plugin->load_tmpl( 'entry_im_exporter.tmpl' );

    my %param;
    $param{page_title} = $plugin->translate( 'Entry management' );
    $param{page_mode} = 'entry';
    $param{entry_flg} = 1;

    #encoding settings
    my $settings = $plugin->get_config_hash;
    $param{export_as_sjis} = $settings->{entry_im_exporter_use_sjis_export};
    $param{import_as_sjis} = $settings->{entry_im_exporter_use_sjis_import};

    my $blog_id = $app->param('blog_id') || 0;
    $param{blog_id} = $blog_id;
    $MT::VERSION >= 5.0
         ? _param_exports( $blog_id , \%param )
         : _mt4_param_exports( $blog_id , \%param );

    #&_print_mt_log(Dumper($settings), 0, $blog_id  );

    return $app->build_page( $tmpl, \%param );
}

sub disp_page {
    my $app = shift;

    return $app->return_to_dashboard( permission => 1 )
         unless _permission_check();

    my $tmpl = $plugin->load_tmpl( 'entry_im_exporter.tmpl' );

    my %param;
    $param{page_title} = $plugin->translate( 'Page management' );
    $param{page_mode} = 'page';
    $param{entry_flg} = 0;

    #encoding settings
    my $settings = $plugin->get_config_hash;
    $param{export_as_sjis} = $settings->{entry_im_exporter_use_sjis_export};
    $param{import_as_sjis} = $settings->{entry_im_exporter_use_sjis_import};

    my $blog_id = $app->param('blog_id') || 0;
    $param{blog_id} = $blog_id;
    $MT::VERSION >= 5.0
         ? _param_exports( $blog_id , \%param )
         : _mt4_param_exports( $blog_id , \%param );

    return $app->build_page( $tmpl, \%param );
}

sub _mt4_param_exports {
    my ( $blog_id , $param ) = @_;

    my @exports;
    my $iter = MT::Blog->load_iter();
    while ( $iter->() ) {
          push @exports , {
              id     => sprintf ( "%d:%d" , $_->id , 0 ) ,
              name   => $_->name,
              indent => 0,
          };
    }
    unshift @exports , {
        id     => "0:1",
        name   => $plugin->translate( 'All blogs' ),
        indent => 0, 
    };

    $param->{exports} = \@exports;
    return $param->{exports_count} = scalar @exports;
}

sub _export_class_filter {
   my $class = shift;
   return 1 if $MT::VERSION >= 6;
   return $class ne 'entry';
}

sub _param_exports {
    my ( $blog_id , $param ) = @_;
    my @exports;
    my $class = $param->{page_mode};
    my $terms = { class => 'website' };
    my $iter = MT::Blog->load_iter( $terms );
    my $allow = _allow_blogs();
    my $allow_website = 0;
    my $allow_blog    = 0;
    while ( my $website = $iter->() ) {

         my $children = $website->blogs;
         my $child_deny  = scalar grep { $allow->{$_->id} == 0 } @$children;
         my $child_allow = scalar grep { $allow->{$_->id} } @$children;
         my $this_allow  = exists $allow->{$website->id} && $allow->{$website->id} ? 1 : 0;
         $allow_website++ if $this_allow;

         push @exports , {
            id       => sprintf ( "%d:%d" , $website->id , 1 ),
            name     => $plugin->translate( 'Website and belonged blog to [_1]' , $website->name ),
            indent   => 0,
            selected => 0,
         } if $children && _export_class_filter( $class ) && $child_allow && $this_allow;

         push @exports , {
            id       => sprintf ( "%d:%d" , $website->id , 2 ),
            name     => $plugin->translate( 'Belonged blog to [_1]' , $website->name ),
            indent   => 0,
            selected => $class eq 'entry' && $blog_id == $website->id ? 1 : 0,
         } if $children && $child_allow;

         push @exports , {
            id       => sprintf ( "%d:%d" , $website->id , 0 ),
            name     => $website->name,
            indent   => 0,
            selected => $blog_id == $website->id ? 1 : 0,
         } if _export_class_filter( $class ) && $this_allow;

         for ( @$children ) {
              next unless exists $allow->{$_->id} && $allow->{$_->id};
              push @exports , {
                   id       => sprintf ( "%d:%d" , $_->id , 0 ),
                   name     => $_->name,
                   indent   => 1,
                   selected => $blog_id == $_->id ? 1: 0,
              };
              $allow_blog++;
         }
    }
    unshift @exports , {
          id       => "0:2",
          name     => $plugin->translate( 'All blogs' ),
          indent   => 0,
          selected => 0,
    } if $allow_blog;

    unshift @exports , {
          id       => "0:1",
          name     => $plugin->translate( 'All websites' ),
          indent   => 0,
          selected => 0,
    } if _export_class_filter( $class ) && $allow_website;

    unshift @exports , {
          id       => "0:0",
          name     => $plugin->translate( 'All' ),
          indent   => 0,
          selected => 0,
    } if _export_class_filter( $class );

    $param->{exports} = \@exports;
    return $param->{exports_count} = scalar @exports;
}

sub export_blogs {
    my ( $id , $flag )  = split ':' , $_[0];  
    my $v5   = $MT::VERSION >= 5.0 ? 1 : 0;  
    my $terms = {};
    my @blogs;
    unless ( $v5 ) {
       $terms->{id} = $id if $id;
       @blogs = MT::Blog->load( $terms );
       return wantarray ? @blogs : \@blogs;
    }
    unless ( $id ) {
       $terms->{class} = '*';
       $terms->{class} = 'website' if $flag == 1;
       $terms->{class} = 'blog'    if $flag == 2;
       @blogs = MT::Blog->load( $terms );
       return wantarray ? @blogs : \@blogs;
    }
    my $blog = MT::Blog->load( $id );
    if ( $blog ) {
       if ( $blog->is_blog == 0 && $flag ) {
          push @blogs , $_ for @{ $blog->blogs };
       }
       unshift @blogs , $blog if $flag != 2;
    }
    return wantarray ? @blogs : \@blogs;
}

sub csv_export {
    my $app = shift;
    my $q = $app->{query};

    my $entry = MT::Entry->new;
    my $entry_columns = $entry->column_names;
    my @entry_columns = @$entry_columns;
    my $param_blog_id = $q->param( 'blog_id' ) || 0;
    my $param_id = $q->param('id') || '0:0';
    my $param_class = $q->param( 'class' ) || 'entry';
    $param_class = 'entry'
        unless $param_class eq 'entry' || $param_class eq 'page';

    # encoding settings
    my $param_use_sjis = $q->param('export_as_sjis');
    $plugin->set_config_value('entry_im_exporter_use_sjis_export', $param_use_sjis || 0);

    ## パーミッション
    return $app->return_to_dashboard( permission => 1 )
        unless _permission_check();

    $app->validate_magic or return;

    local $| = 1;

    ### ダウンロード後のファイル名
    my $file_enc = $param_use_sjis ? 'sjis' : 'utf8';
    my $file = $param_class eq 'page'
        ? "page_data_$file_enc.csv"
        : "entry_data_$file_enc.csv";

    # ブログの列挙
    my $allow = _allow_blogs();
    my @blogs = grep { exists $allow->{$_->id} && $allow->{$_->id} == 1 } export_blogs( $param_id );

    # カスタムフィールドのソート
    my $cf_sort_key = 'basename';
    my $cf_sort_direction = 'ascend';

    # カスタムフィールドの列挙
    my @buf_columns;
    foreach my $blog (@blogs) {
        my @CustomFields = CustomFields::Field->load({ blog_id => $blog->id, obj_type => $param_class } , { sort => $cf_sort_key , direction => $cf_sort_direction });
        foreach my $CustomField (@CustomFields) {
            my $basename = $CustomField->basename;
            push @buf_columns, $basename;
        }
    }
    #
    my @CustomFields = CustomFields::Field->load({ blog_id => 0, obj_type => $param_class } , { sort => $cf_sort_key , direction => $cf_sort_direction });
    foreach my $CustomField (@CustomFields) {
        my $basename = $CustomField->basename;
        push @buf_columns, $basename;
    }
    # Get Unique
    my %tmp; my @custom_columns = grep( !$tmp{$_}++, @buf_columns );

    ## version4 >> version5 Encode::utf8_off
    my $encode_switch = '';
    my $encoding = $param_use_sjis ? 'sjis' : 'utf-8';
    if ( $app->version_number =~ /^5/){
        $encode_switch = sub {
            no warnings 'uninitialized'; 
            return _encode_text($_[2], $_[3], MT::I18N::utf8_off($_[0]), $_[1], $encoding ); };
    }else{
        $encode_switch = sub {
            no warnings 'uninitialized';
            return _encode_text($_[2], $_[3], $_[0], $_[1], $encoding ); };
    }

    ### ダウンロードの開始
    $app->{no_print_body} = 1;
    $app->set_header("Content-Disposition" => "attachment; filename=$file");
    $app->send_http_header( "text/csv; charset=$encoding" );

    my $line_count = 1;

    ### タイトル行の生成
    my @title_columns;
    foreach my $column (@entry_columns) {
        if( $column ne 'meta' ) {
            push @title_columns, 'entry_'. $column;
        }
    }
    foreach my $custom (@custom_columns) {
        push @title_columns, $custom;
    }
    push @title_columns, 'tags';
    push @title_columns, 'entry_category_basename';
    my $title_line = join ',', map { (s/"/""/g or /[\r\n,]/) ? qq("$_") : $_ } @title_columns; #"
    ## ヘッダの出力
    $app->print( Encode::encode( $encoding , $title_line . "\n" ) );

    ## use combine
    my $csv = Text::CSV_PP->new({ binary => 1 });

    ## イレギュラーコードはファイルの最後に回す(エクセルで見やすくするため)
    my @last_print = ();

    ## ソートキーの設定
    my $export_sort_key = MT->config('EntryImExporterSortKey') || 'id';
    my $export_sort_direction = MT->config('EntryImExporterSortDirection') || 'ascend';
 
    foreach my $blog (@blogs) {
        my @entries = MT::Entry->load({ blog_id => $blog->id, class => $param_class } , { sort => $export_sort_key , direction => $export_sort_direction });
        foreach my $entry (@entries) {
            my @line_val;
            ### MT::Entry columns
            my $entry_column_val = $entry->column_values();
            foreach my $entry_column (@entry_columns) {
                my $val = $entry_column_val->{$entry_column};
                if ( $entry_column eq 'authored_on' || $entry_column eq 'created_on' || $entry_column eq 'modified_on' ) {
                    if ( $val ) {
                       $val = MT::Util::format_ts( '%Y-%m-%d %H:%M:%S', $val, undef, undef );
                    }
                }
                elsif ( $entry_column eq 'unpublished_on' ) {
                    if ( $val ) {
                       $val = MT::Util::format_ts( '%Y-%m-%d %H:%M:%S', $val, undef, undef );
                    }
                }
                elsif ( $entry_column eq 'meta' ) {
                   next;
                }
                elsif ( $entry_column eq 'category_id' ) {
                    $val = '';
                    my @places = MT::Placement->load({ entry_id => $entry->id });
                    for my $place (@places) {
                        if ( $val ) {
                            if ( $place->is_primary ) {
                                $val = $place->category_id . ",$val";
                            }
                            else {
                                $val .= ',' . $place->category_id;
                            }
                        }
                        else {
                            $val = $place->category_id;
                        }
                    }
                }
                push( @line_val, $val );
            }
            ### CustomFields columns
            my $meta = get_meta( $entry );
            foreach my $custom (@custom_columns) {
                my $val = '';
                foreach my $field (keys %$meta) {
                    if ( $field eq $custom ) {
                        $val = $meta->{$field};
                        if ( $val ) {
                            my $customfield = CustomFields::Field->load({ basename => $field });
                            if ( $customfield->type eq 'datetime' ) {
                                $val = MT::Util::format_ts( '%Y-%m-%d %H:%M:%S', $val, undef, undef );
                                # 無効な日時なら、空白データを出力
                                unless ( is_valid_date( $val ) ) {
                                    $val = '';
                                }
                            }
                        }
                    }
                }
                push( @line_val, $val );
            }
            ### Tags of Entry
            my @tags = ();
            my $tags_iter = MT::ObjectTag->load_iter({
                blog_id => $blog->id,
                object_datasource => MT::Entry->datasource,
                object_id => $entry->id,
            });
            while (my $object_tag = $tags_iter->()) {
                my $tag = MT::Tag->load({
                    id => $object_tag->tag_id,
                })  or next;
                push @tags, $tag->name =~ m!,! 
                    ? '"' . $tag->name . '"'
                    : $tag->name;
            }
            push @line_val, join( ',', @tags ) || '';

            ### Category Path
			my $category_path = "";
			if(my $entry_category = $entry->category) {
				$category_path = $entry_category->category_path;
			}
			push @line_val, $category_path;

            my @enc_line = ();
            my $max_cell_count = 0;
            for ( @line_val ){
                no warnings 'uninitialized';
                push @enc_line , &$encode_switch( $_ , get_system_charset ( $app ), $entry->id, $entry->blog_id );
                $max_cell_count = length( $_ ) if $max_cell_count < length( $_ );
            }

            ## イレギュラーコードは最後に表示 ここではスキップ
            if( $max_cell_count >= 32767 ){
                 push @last_print , \@enc_line;
                 next;
            }

            ## Create new line.
            $csv->combine(@enc_line);
            $app->print( sprintf( "%s\n",$csv->string() ) );
            $line_count++;
        }
    }

    ## イレギュラーコードの表示
    foreach my $last_code ( @last_print ){
       $csv->combine( @{$last_code} );
       $app->print( sprintf ( "%s\n",$csv->string() ) );
       &_print_mt_log(
            $plugin->translate('The CSV is not open in Exel. Exceeded the character limit of the cell.'). ' '.
            $plugin->translate('[_1] lines' , $line_count ) .
           ' (ID:'.$last_code->[0].')' );
       $line_count++;
    }
}

### convert encoding
sub _encode_text {
  my ( $entry_id, $param_blog_id, $str, $from, $to) = @_;

  no warnings 'uninitialized';
 
  # For UTF-8 code point map problems on Window, 
  # convert code point of below characters.
  # WAVE DASH  <- FULLWIDTH TILDE
  # MINUS SIGN <- FULLWIDTH HYPHEN
  # DOUBLE VERTICAL LINE <- PARALLEL TO
  # etc ....
  if ($from eq 'utf8' && $to eq 'sjis') {
    $str =~ s/\xef\xbd\x9e/_found_bad_character('U+FF5E FULLWIDTH TILDE', $param_blog_id, $entry_id); "\xe3\x80\x9c"/gie; # ～ U+FF5E(FULLWIDTH TILDE) → U+301C(WAVE DASH)
    $str =~ s/\xe2\x88\xa5/_found_bad_character("U+2225 PARALLEL TO", $param_blog_id, $entry_id); "\xe2\x80\x96"/gie; # ∥ U+2225(PARALLEL TO) → U+2016(DOUBLE VERTICAL LINE)
    $str =~ s/\xef\xbc\x8d/_found_bad_character("U+FF0D FULLWIDTH HYPHEN-MINUS", $param_blog_id, $entry_id); "\xe2\x88\x92"/gie; # － U+FF0D(FULLWIDTH HYPHEN-MINUS) → U+2212(MINUS SIGN)
    $str =~ s/\xef\xbf\xa0/_found_bad_character("U+FFE0 FULLWIDTH CENT SIGN", $param_blog_id, $entry_id); "\xc2\xa2"/gie;    # ￠ U+FFE0(FULLWIDTH CENT SIGN) → U+00A2(CENT SIGN)
    $str =~ s/\xef\xbf\xa1/_found_bad_character("U+FFE1 FULLWIDTH POUND SIGN", $param_blog_id, $entry_id); "\xc2\xa3"/gie;    # ￡ U+FFE1(FULLWIDTH POUND SIGN) → U+00A3(POUND SIGN)
    $str =~ s/\xef\xbf\xa2/_found_bad_character("U+FFE2 FULLWIDTH NOT SIGN", $param_blog_id, $entry_id); "\xc2\xac"/gie;    # ￢ U+FFE2(FULLWIDTH NOT SIGN) → U+00AC(NOT SIGN)
  } elsif ($from eq 'sjis' && $to eq 'utf8') {
    $str =~ s/\xe3\x80\x9c/\xef\xbd\x9e/gi; # ～ U+FF5E(FULLWIDTH TILDE) → U+301C(WAVE DASH)
    $str =~ s/\xe2\x80\x96/\xe2\x88\xa5/gi; # ∥ U+2225(PARALLEL TO) → U+2016(DOUBLE VERTICAL LINE)
    $str =~ s/\xe2\x88\x92/\xef\xbc\x8d/gi; # － U+FF0D(FULLWIDTH HYPHEN-MINUS) → U+2212(MINUS SIGN)
    $str =~ s/\xc2\xa2/\xef\xbf\xa0/gi;    # ￠ U+FFE0(FULLWIDTH CENT SIGN) → U+00A2(CENT SIGN)
    $str =~ s/\xc2\xa3/\xef\xbf\xa1/gi;    # ￡ U+FFE1(FULLWIDTH POUND SIGN) → U+00A3(POUND SIGN)
    $str =~ s/\xc2\xac/\xef\xbf\xa2/gi;    # ￢ U+FFE2(FULLWIDTH NOT SIGN) → U+00AC(NOT SIGN)

  }

  MT::I18N::encode_text($str, $from, $to);
}

# handler for bad character.
sub _found_bad_character {
  my ($str, $blog_id, $entry_id) = @_;

  _print_mt_log("Entry ID:$entry_id Bad character found: $str", 0, $blog_id  );

  $str;
}

### data import run
sub csv_import {
    my $app = shift;

    my $q = $app->{query};
    my $update_flg = $q->param( 'update_flg' ) || 0;
    my $class = $q->param( 'class' ) || 'entry';
    $class = 'entry'
        unless $class eq 'entry' || $class eq 'page';

    my $blog_id = $app->param('blog_id') || 0;

    # パーミッション
    return $app->return_to_dashboard( permission => 1 )
        unless _permission_check();

    $app->validate_magic or return;

    # encoding settings
    my $param_use_sjis = $q->param('import_as_sjis');
    $plugin->set_config_value('entry_im_exporter_use_sjis_import', $param_use_sjis || 0);

    my %param;
    $param{blog_id} = $blog_id;
    if ($class eq 'page'){
        $param{page_title} = $plugin->translate( 'Page management' );
        $param{page_mode} = 'page';
        $param{entry_flg} = 0;
    }
    else{
        $param{page_title} = $plugin->translate( 'Entry management' );
        $param{page_mode} = 'entry';
        $param{entry_flg} = 1;
    }

    #encoding settings
    my $settings = $plugin->get_config_hash;
    $param{export_as_sjis} = $settings->{entry_im_exporter_use_sjis_export};
    $param{import_as_sjis} = $settings->{entry_im_exporter_use_sjis_import};

    $MT::VERSION >= 5.0
       ? _param_exports( $blog_id , \%param )
       : _mt4_param_exports( $blog_id , \%param );

    my $fh = $q->upload('upload_file');
    my $tmpl = '';
    if (!$fh) {
        $param{SKR_ERROR_MSG} = $plugin->translate( 'File upload error' ). '<br />';
        $tmpl = $plugin->load_tmpl( 'entry_im_exporter.tmpl' );
        return $app->build_page( $tmpl, \%param );
    }

    my $suffix = _get_suffix( $fh );
    unless (scalar $suffix =~ m/(csv)$/i) {
        $param{SKR_ERROR_MSG} = $plugin->translate( 'CSV file type error' ). " [$suffix]";
        $tmpl = $plugin->load_tmpl( 'entry_im_exporter.tmpl' );
        return $app->build_page( $tmpl, \%param );
    }

    # do importing
    my $ret = _import_csv_file ($blog_id, $app, $fh, \%param, $update_flg, $class);
    if (defined $ret) {
        $tmpl = $plugin->load_tmpl( $ret );
        return $app->build_page( $tmpl, \%param );
    }

    # done
    $tmpl = $plugin->load_tmpl( 'entry_im_exporter.tmpl' );
    return $app->build_page( $tmpl, \%param );
}

### Importing core block
sub _import_csv_file {
    my ($log_blog_id, $app, $fh , $param_ref, $update_flg, $class, $filename, $encoding) = @_;

    my @data_buf;
    my $error_count = 0;
    my @title_fields;
    my $line_count = 0;
    my $title_count = 0;

    ## version4 >> version5 Encode::utf8_off

    # encoding setting
    my $use_sjis_csv = $plugin->get_config_value('entry_im_exporter_use_sjis_import');
    # command line support.
    if ($encoding eq 'utf8') {
       $use_sjis_csv = 0;
    }  

    my $encode_switch;
    if ($use_sjis_csv) {
      $encode_switch = sub { Encode::decode ('sjis', $_[0]) };
    } else {
      $encode_switch = sub { Encode::decode ('utf-8', $_[0]) };
    }

    ### Text::CSV_PP used
    my $csv = Text::CSV_PP->new({ binary => 1 });
    $filename ||= $app->param->tmpFileName( $fh );

    require IO::File;
    my $handle;
    unless ( $handle = IO::File->new( $filename , 'r' ) ){
        $param_ref->{SKR_ERROR_MSG} = $plugin->translate( 'Did not read the uploaded file.' );
        return 'entry_im_exporter.tmpl';
    }

    my $system_encode = get_system_charset($app);
    while (not $handle->eof) {
        my $values = $csv->getline($handle);
        my @values = map { &$encode_switch( $_,  $system_encode ) } @{$values};

        if ($line_count == 0){
            @title_fields = @values;
            $title_count = @title_fields;

            unless (&_check_field( \@title_fields , 'entry_id' )) {
                $param_ref->{SKR_ERROR_MSG} = $plugin->translate( 'Title fields not found [_1]', 'entry_id' );
                $handle->close;
                return 'entry_im_exporter.tmpl';
            }
            unless (&_check_field( \@title_fields , 'entry_blog_id' )) {
                $param_ref->{SKR_ERROR_MSG} = $plugin->translate( 'Title fields not found [_1]', 'entry_blog_id' );
                $handle->close;
                return 'entry_im_exporter.tmpl';
            }
            unless (&_check_field( \@title_fields , 'entry_author_id' )) {
                $param_ref->{SKR_ERROR_MSG} = $plugin->translate( 'Title fields not found [_1]', 'entry_author_id' );
                $handle->close;
                return 'entry_im_exporter.tmpl';
            }
            unless (&_check_field( \@title_fields , 'entry_title' )) {
                $param_ref->{SKR_ERROR_MSG} = $plugin->translate( 'Title fields not found [_1]', 'entry_title' );
                $handle->close;
                return 'entry_im_exporter.tmpl';
            }
            unless (&_check_field( \@title_fields , 'entry_basename' )) {
                $param_ref->{SKR_ERROR_MSG} = $plugin->translate( 'Title fields not found [_1]', 'entry_basename' );
                $handle->close;
                return 'entry_im_exporter.tmpl';
            }
        }
        else {
            my $data_count = @values;
            if ($title_count ne $data_count){
                &_print_mt_log ($plugin->translate ('Fields count and title count are different'). ' '. $plugin->translate('[_1] lines', $line_count + 1));
                $error_count++;
            }
            else {
                my %data_rec;
                for (my $i = 0; $i < $title_count; $i++) {
                    my $data_title = $title_fields[$i];
                    my $data_value = $values[$i];
                    $data_rec{$data_title} = $data_value;
                }
                push @data_buf, \%data_rec;
            }
        }
        $line_count++;
    }
    $handle->close;

    ##
    my $allow_blogs = _allow_blogs();

    ###
    my $add_count = 0;
    my $update_count = 0;
    my $skip_count = 0;
    my $total_count = 0;
    $line_count = 1;
    foreach my $data (@data_buf) {
        my $entry_id = $data->{entry_id};
        my $blog_id  = $data->{entry_blog_id};
        $line_count++;
        my $ret;

        ## 権限のあるブログのみインポートを許可
        unless ( $allow_blogs && exists $allow_blogs->{$blog_id} && $allow_blogs->{$blog_id} ) {
           &_print_mt_log (
                 $plugin->translate('[_1] Line' , $line_count )
                  . ' '
                  . $plugin->translate( 'Posted a blog(id:[_1]) without permission.' , $blog_id )
                  , 0 , $blog_id );
           $error_count++;
           $total_count++;
           next;
        }

        ## ウェブサイトへのブログ記事の登録はエラーとする。
        my $blog = MT::Blog->load ($blog_id);
        if ( $MT::VERSION < 6 ) {
            if ($blog && $blog->can('is_blog') && !$blog->is_blog
                && defined $data->{entry_class} && $data->{entry_class} eq 'entry') {
               &_print_mt_log (
                  $plugin->translate ('[_1] Line', $line_count). ' '.
                  $plugin->translate ('Against Website (id:[_1]), entry can\'t be registered.', $blog_id),
                  0, $blog_id);
               $error_count++;
               $total_count++;
               next;
            }
        }

        eval {
            $ret = &_save_entry( $plugin, $data, $update_flg, $class , $line_count, $allow_blogs);
        };
        if ($@) {
            & _print_mt_log (
                    $plugin->translate ('[_1] Line', $line_count). ' '.
                    $plugin->translate ('CSV post error'). " [$@]",
                    0, $blog_id);
            $ret = 0;
        }
        if ($ret == 1) {
            $add_count++;
        }
        elsif ($ret == 2) {
            $update_count++;
        }
        elsif ($ret == 3) {
            $skip_count++;
        }
        else {
            $error_count++;
        }
        $total_count++;
    }
    my $msg = $plugin->translate( 'CSV all posted' ). "<br />" . $plugin->translate( 'all [_1] count', $total_count ); #15875
    if ($add_count > 0) {
        $msg .= '<br />'. $plugin->translate( 'add [_1] count', $add_count );
    }
    if ($update_count > 0) {
        $msg .= '<br />'. $plugin->translate( 'update [_1] count', $update_count );
    }
    if ($skip_count > 0) {
        $msg .= '<br />'. $plugin->translate( 'skip [_1] count', $skip_count );
    }
    if ($error_count > 0) {
        $msg .= '<br />'. $plugin->translate( 'error [_1] count', $error_count );
        $msg .= sprintf'&nbsp;<a href="mt.cgi?__mode=list&amp;_type=log&amp;blog_id=%d">%s</a>', $log_blog_id, $plugin->translate('detail log');
    }
    $param_ref->{SKR_MSG} = $msg;

    &_print_mt_log(
        $plugin->translate( 'CSV all posted' ). ', '.
        $plugin->translate( 'all [_1] count', $total_count ). ', '.
        $plugin->translate( 'add [_1] count', $add_count ). ', '.
        $plugin->translate( 'update [_1] count', $update_count ). ', '.
        $plugin->translate( 'error [_1] count', $error_count ),
        MT::Log::INFO());

    return undef;# Succeeded
}

########################################################################
#   Common functions
########################################################################

sub _permission_check {
     my @allow = _allow_blogs();
     return scalar @allow ? 1 : 0;
} 

sub _allow_blogs {

    my $r = MT::Request->instance;
    my $cache = $r->cache( $CACHE_KEY );
    if ( $cache ) {
        return wantarray ? grep { $cache->{$_} } keys %$cache : $cache;
    }

    my $app  = MT->instance;
    my $flag = UNIVERSAL::isa( $app , 'MT::App' ) ? 1 : 0;
    if ( $flag ) {
        eval{ $app->user or die; };
        $flag = 0 if $@;
    }
    my %allow_blogs;
    my $terms = $MT::VERSION >= 5.0 ? { class => '*' } : {};
    my @blogs = MT::Blog->load( $terms );

    ## CommandLine
    unless ( $flag ) {
   
       $allow_blogs{$_->id} = 1 for @blogs;
       $r->cache( $CACHE_KEY, \%allow_blogs );
       return wantarray ? grep { $allow_blogs{$_} } keys %allow_blogs : \%allow_blogs;

    }

    ## WEB Request
    my $check_permission = sub {
         my ( $author , $blog ) = @_;

         return 1 if $author->is_superuser;
         my $perm = $author->permissions(0);
         return 1 if $perm->can_do('administer');
         $perm = $author->permissions( $blog->id ) or return 0;
         if ( $MT::VERSION >= 5.0 ) {
              return $blog->is_blog
                  ? $perm->can_do('administer_blog')
                  : $perm->can_do('administer_website');
         }
         return $perm->can_do('administer_blog');

    };
    $allow_blogs{$_->id} = $check_permission->( $app->user , $_ ) for @blogs;
    $r->cache( $CACHE_KEY, \%allow_blogs );
    return wantarray ? grep { $allow_blogs{$_} } keys %allow_blogs : \%allow_blogs;
}

### import data save
sub _save_entry {
    my ($plugin, $data, $update_flg, $class, $line_count, $allow_blogs) = @_;
    my $app = MT->instance;
    my $entry;
    my $entry_id = $data->{entry_id};
    my $blog_id  = $data->{entry_blog_id};

    my @category_ids = split ',', $data->{entry_category_id};
    my $primary_cate = '';
    $primary_cate = $category_ids[0] if @category_ids;

    # data check
    my $err_msg = &_data_check( $plugin, $data, $entry_id, $blog_id, $class, $allow_blogs );
    if ($err_msg) {
        $err_msg = $plugin->translate('[_1] Line', $line_count) . ' ' . $err_msg;
        & _print_mt_log( $err_msg . " entry_id=[" . $entry_id . "]", 0, $blog_id);
        return 0;
    }
    my $blog = MT::Blog->load( $blog_id );
    my $author = MT::Author->load( $data->{'entry_author_id'});

    my @ts = MT::Util::offset_time_list( time, $blog );
    my $ts = sprintf '%04d%02d%02d%02d%02d%02d', $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];

    my $save_mode = 1;
    if ($entry_id){
        $entry = MT::Entry->load( $entry_id );
        if (!$entry) {
            $entry = MT::Entry->new;
            $entry->id( $entry_id );
        }
        else {
            if (!$update_flg){
               return 3;
            }
            $save_mode = 2;
        }
    }
    else {
        my $e = $app->model( $class );
        $entry = $e->new;
    }

    my $entry_columns = $entry->column_names;
    my @entry_columns = @$entry_columns;
    while (my ($key, $value) = each (%$data)) {

        if ($key eq 'entry_category_basename') {
#            @category_ids = (); # clear it
#            $primary_cate = ''; # clear it
            $value =~ s!^/+|/+$!!g; # omit the leading and ending slash
            my $cat;
			my @category_paths = split /\s*\/\s*/, $value;
			# retrieve a category matched with category path.
			if(@category_paths) {
				my $last_path = $category_paths[-1];
				my $terms = {
					class =>  ($class eq 'entry' ? 'category' : 'folder'),
					blog_id => $blog_id,
					basename => $last_path,
				};
				my $cat_iter = MT::Category->load_iter($terms);
				while (my $test_cat = $cat_iter->() ) {
					if($value eq $test_cat->category_path) {
						$cat = $test_cat;
						last;
					}
				}
			}
			# fix for preserving subcategories.
			if ( $cat && ! grep { $_ eq $cat->id } @category_ids ) {
				push @category_ids, ($primary_cate = $cat->id);
			}
            next;
        }

        if ($key eq 'entry_category_label') {
 #           @category_ids = (); # clear it
 #           $primary_cate = ''; # clear it
            $value =~ s!^/+|/+$!!g; # omit the leading and ending slash
            my $cat;
            foreach (split /\s*\/\s*/, $value) {
                $cat = _get_category_by (
                    'label',
                    $_,
                    $blog_id,
                    $class eq 'entry' ? 'category' : 'folder',
                    $cat ? $cat->id : 0) or return 3; # skip
            }
			# fix for preserving subcategories.
			if ( $cat && ! grep { $_ eq $cat->id } @category_ids ) {
				push @category_ids, ($primary_cate = $cat->id);
			}
            next;
        }

        # Standard columns of MT::Entry
        foreach my $column (@entry_columns) {
             if ($key eq 'entry_' . $column){
                 if ($column eq 'category_id') {
                     if ($primary_cate) {
                         $value = $primary_cate;
                     }
                 }
                 elsif ($column eq 'status') {
                     if (!$value) {
                         $value = $blog->status_default;
                     }
                 }
                 elsif ($column eq 'allow_comments') {
                     if (!$value && $value =~ /^$/) {
                         $value = $blog->allow_comments_default;
                     }
                 }
                 elsif ($column eq 'allow_pings') {
                     if (!$value && $value =~ /^$/ ) {
                         $value = $blog->allow_pings_default;
                     }
                 }
                 elsif ($column eq 'authored_on'){
                     if ($value) {
                         $value = _format_and_check_ts( $value ) || $ts;
                     }
                 }
                 elsif ($column eq 'created_by') {
                     if (!$value) {
                         $value = $app->user->id if $save_mode == 1;
                     }
                 }
                 elsif ($column eq 'created_on') {
                     if ($value) {
                         $value = _format_and_check_ts( $value ) || $ts;
                     }
                     else {
                         $value = $ts if $save_mode == 1;
                     }
                 }
                 elsif ($column eq 'modified_by') {
                     if (!$value) {
                        if ( $app->can('user')) {
                            $value = $app->user->id if $save_mode == 2;
                        }
                        else {
                            $value = 0;
                        }
                     }
                 }
                 elsif ($column eq 'modified_on') {
                     if ($value) {
                         $value = _format_and_check_ts( $value ) || $ts;
                     }
                     else {
                         $value = $ts if $save_mode == 2;
                     }
                 }
                 ## r34689 for mt6
                 elsif ( $column eq 'unpublished_on' ) {
                     if ( $value ) {
                         $value = _format_and_check_ts( $value ) || undef;
                     }
                     else {
                         $value = undef;
                     }
                 }
                 elsif( $column eq 'week_number') {
                     if (!$value) {
                         if (my $dt = $entry->authored_on_obj) {
                             my ($yr, $w) = $dt->week;
                             $value = $yr * 100 + $w;
                         }
                     }
                 }
                 elsif( $column eq 'current_revision') {
                    if (!$value) {
                        $value = 0;
                    }
                 }
                 elsif ($column eq 'meta' || $column eq 'id') {
                     last;
                 }
                 if (($entry->column_defs->{$column}->{'type'} eq 'integer')
                  || ($entry->column_defs->{$column}->{'type'} eq 'float')
                  || ($entry->column_defs->{$column}->{'type'} eq 'blob')){
                     unless ($value =~ /^(-|\+|)\d+\.?\d*(E\+\d+|E\-\d+)?$/i){
                         $value = undef;
                     }
                 }
                 # treat emtpy string as NULL if column type is datetime
                 # ( sgsindt for MS SQL type cast error)
                 if ($entry->column_defs->{$column}->{'type'} eq 'datetime') {
                     if (!$value && defined($value) && ($value eq '')) {
                         $value =  undef;
                     }
                 }
                 $entry->$column( $value );
                 last;
             }
        }
    }
    if ( $MT::VERSION >= 6 ) {
        if ( $entry->status == 6 ) {
            my $unpublish_date = $entry->unpublished_on();
            unless ( defined $unpublish_date && $unpublish_date) {

                _print_mt_log(
                    $plugin->translate('[_1] Line', $line_count)
                        . ' '
                        . MT->translate('Invalid date \'[_1]\'; \'Unpublished on\' dates should be real dates.'
                            , $unpublish_date )
                        . " entry_id=[" . $entry_id . "]"
                        , 0, $blog_id );

                 return 0; 
            }
            else {
                my $publish_date = $entry->authored_on;
                require MT::DateTime;
                if (
                    MT::DateTime->compare(
                        blog => $blog,
                        a    => { value => time(), type => 'epoch' },
                        b    => $unpublish_date
                    ) > 0 
                 ){
                     ## 未来時間じゃない
                     _print_mt_log(
                        $plugin->translate('[_1] Line', $line_count)
                            . ' '
                            . MT->translate('Invalid date \'[_1]\'; \'Unpublished on\' dates should be dates in the future.'
                                , $unpublish_date )
                            . " entry_id=[" . $entry_id . "]"
                            , 0, $blog_id );
                      return 0;

                 }
                 elsif (
                    $publish_date &&
                    MT::DateTime->compare(

                        blog => $blog,
                        a    => $publish_date,
                        b    => $unpublish_date
                    ) > 0
                 ) {
                     ## 公開日が過去
                     _print_mt_log(
                        $plugin->translate('[_1] Line', $line_count)
                            . ' '
                            . MT->translate( 'Invalid date \'[_1]\'; \'Unpublished on\' dates should be later than the corresponding \'Published on\' date.', $unpublish_date )
                            . " entry_id=[" . $entry_id . "]"
                            , 0, $blog_id );
                     return 0;

                 } 
            }
        }
    }
    $entry->class ($class);
    unless ($entry->save) {
        &_print_mt_log($plugin->translate('[_1] Line', $line_count) . ' ' . $plugin->translate( 'Entry save error' ).  " entry_id=[" . $entry_id . "]", 0, $blog_id );
        return 0;
    }
    unless ($entry->atom_id) {
        $entry->atom_id( $entry->make_atom_id());
        $entry->save() if $entry->atom_id;
    }

    # カスタムフィールド登録
    my $meta = get_meta( $entry );
    use CustomFields::App::CMS;
    my $customfield_types = CustomFields::App::CMS->load_customfield_types;

    my @CustomFields = CustomFields::Field->load({ blog_id => [ $blog_id , 0 ] });
    foreach my $CustomField (@CustomFields) {
        my $basename = $CustomField->basename;
        if ( $CustomField->type eq 'datetime' ) {
            if ( $data->{$basename} ) {
                 $meta->{$basename} = _format_and_check_ts( $data->{$basename} ) || undef;
            } else {
                 $meta->{$basename} = undef;
            }
        }
        elsif ( $CustomField->type eq 'checkbox' ) {
            $meta->{$basename} = ( $data->{$basename} || '0') ne '0' ?  $data->{$basename} || $CustomField->default || undef : $data->{$basename}; #15875
        }
        else {
            $meta->{$basename} = $data->{$basename} || $CustomField->default || undef;
        }
        
        # Fix for MSSQL
        # treat emtpy string as NULL if column type is datetime or integer
        # ( sgsindt for MS SQL type cast error)
        my $customfield_type = $customfield_types->{$CustomField->type}
            or next;
        my $column_def = $customfield_type->{column_def};
        if ( $column_def && ($column_def =~ m/^vinteger|vdatetime/o) 
             && !$meta->{$basename} && defined($meta->{$basename}) && ($meta->{$basename} eq '') ){
            $meta->{$basename} = undef;
        }
    }
    &save_meta( $entry, $meta ) if $meta;

    # カテゴリ登録
    if ($primary_cate) {
        map { $_->remove } MT::Placement->load({ entry_id => $entry->id });
        foreach my $cate_id (@category_ids) {
            # check blog author
            my $cat = MT::Category->load({id => $cate_id, blog_id => $blog_id }) 
                or next;

            my $place = MT::Placement->new;
            $place->blog_id( $blog_id );
            $place->entry_id( $entry->id );
            $place->category_id( $cate_id );
            $place->is_primary ($primary_cate == $cate_id ? 1 : 0);
            unless ($place->save) {
                &_print_mt_log( $plugin->translate('[_1] Line', $line_count) . ' ' . $plugin->translate( 'Category save error (entry_id=[_1])', $entry->id ), 0, $blog_id );
                return 0;
            }
        }
    }

    # タグの登録
    $data->{'tags'} ||= '';

    ## CSVフォーマットを処理
    my $csv_sub = Text::CSV_PP->new({ binary => 1 });
    $csv_sub->parse($data->{'tags'});
    my @tag_fields = $csv_sub->fields;

    # タグはコンマ区切り
    my %obj_tags_map;
    foreach my $tag_name ( @tag_fields ) {
        next if $tag_name !~ /\w+/; #15875
         # その名前のタグが既に存在するか？
         my $tag_obj = MT::Tag->load({ name => $tag_name }, { binary => { name => 1 } });
         if (!$tag_obj) {
             # 無い場合には新規にタグを登録する
             $tag_obj = MT::Tag->new;
             $tag_obj->name( $tag_name );
             $tag_obj->is_private( $tag_name =~ /^\@/ );
             $tag_obj->n8d_id( 0 );# TODO: n8d
             $tag_obj->save;
         }
         # タグとエントリの関連付けを得る
         my $objtag_obj = MT::ObjectTag->load({
             blog_id => $blog_id,
             object_datasource => MT::Entry->datasource,
             object_id => $entry->id,
             tag_id => $tag_obj->id,
         });
         if (!$objtag_obj) {
             # 無い場合には新規に関連付けを登録する
             $objtag_obj = MT::ObjectTag->new;
             $objtag_obj->blog_id( $blog_id );
             $objtag_obj->object_datasource( MT::Entry->datasource );
             $objtag_obj->object_id( $entry->id );
             $objtag_obj->tag_id( $tag_obj->id );
             $objtag_obj->save;
         }
         $obj_tags_map{$tag_obj->id} = 1;
    }
    # 外された関連付けは削除してしまう
    my @objtags = MT::ObjectTag->load({
        blog_id => $blog_id,
        object_datasource => MT::Entry->datasource,
        object_id => $entry->id,
    });
    foreach my $objtag (@objtags) {
        $objtag->remove if !$obj_tags_map{$objtag->tag_id};
    }

    return $save_mode;
}

# フォーマット整形。有効な日時かどうかチェック
sub _format_and_check_ts {
    my ( $value ) = @_;

    if ( my @at = parse_date( $value ) ) {
        my $authored_ts = sprintf( '%04d%02d%02d%02d%02d%02d', @at[0 .. 5] );
        return is_valid_date( $authored_ts ) ? $authored_ts : undef;
    }

    return;
}

### カテゴリ名からMT::Categoryを得る
sub _get_category_by {
    my ($column, $label, $blog_id, $class, $parent_id) = @_;

    my $iter = MT::Category->load_iter ({
        blog_id => $blog_id,
        class => $class ? $class : 'category',
        $parent_id ? (parent => $parent_id) : (),
    });
    while (my $cat = $iter->()) {
        return $cat if $cat->$column eq $label;
    }
    undef;
}

### MT::Log にログを保存する
sub _print_mt_log {
    my ($msg, $level, $blog_id) = @_;

    my $log = MT::Log->new;
    $log->message( $msg );
    $log->level( $level || MT::Log::ERROR ());
    $log->blog_id( $blog_id || 0 );
    my $app = MT->instance;
    $log->author_id( $app->user->id ) if $app->can('user') && $app->user;
    $log->save;
}

### アップロードされたファイルパスから拡張子部分を得る
sub _get_suffix {
    my $org_path = shift;
    my @suffixlist = @_;
    my ($name, $path, $suffix) = fileparse( $org_path, @suffixlist );

    if (scalar @suffixlist) {
        return $suffix;
    }
    else {
        my $suffix = '';
        if (index ($name, '.',  0) != -1) {
            $suffix = (split (/\./, $name))[-1]; 
        }
        return $suffix;
    }
}

### フィールドのチェック
sub _check_field {
    my ($fields, $check_field) = @_;
    my @fields = @$fields;
    foreach my $field_name ( @fields ) {
        if ($field_name eq $check_field){
            return 1;
        }
    }
    return 0;
}

### フィールド値のチェック
sub _check_field_value {
    my ($value, $null_check, $num_check, $value_arr) = @_;

    if ($null_check) {
        if (!$value) {
            return 0;
        }
    }
    else {
        if (!$value) {
            return 1;
        }
    }
    if ($num_check) {
        if ($value =~ /[\D]/){
            return 0;
        }
    }
    if ($value_arr) {
        foreach my $val (@$value_arr) {
            if ($value eq $val) {
                return 1;
            }
        }
        return 0;
    }
    return 1;
}

### データチェック
sub _data_check {
    my ($plugin, $data, $entry_id, $blog_id, $class, $allow_blogs) = @_;
    my @values;

    ### entry_id
    unless (_check_field_value( $entry_id, 0, 1 )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_id' );
    }

    ### entry_blog_id
    unless (_check_field_value( $blog_id, 1, 1 )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_blog_id' );
    }

    my $blog = MT::Blog->load( $blog_id );
    if (!$blog) {
        return $plugin->translate( 'Specified blog not found id=[_1]', $blog_id );
    }

    my $entry;
    if ( $entry_id ) {
        $entry = MT::Entry->load({id => $entry_id, class => '*'});
    }

    ### check blog permission,
    unless ( $allow_blogs->{$blog_id} ) {
        return $plugin->translate( 'Current user does not have permissions to blog : [_1]', $blog_id );
    }

    ### entry_class
    unless ( ($class eq 'page') || ($class eq 'entry') ) {
        return $plugin->translate( 'The value of [_1] is invalid', 'class' ) ;
    }

    if ( $data->{entry_class} ne $class ) {
        if ($class eq 'page') {
            return $plugin->translate( 'The value of [_1] is invalid', 'entry_class' ) . ". " . $plugin->translate( 'This Data is Web Page Data');
        } else {
            return $plugin->translate( 'The value of [_1] is invalid', 'entry_class' ) . ". " . $plugin->translate( 'This Data is Blog Entry Data');
        }
    }

    ### entry_author_id
    unless (_check_field_value( $data->{entry_author_id}, 1, 1 )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_author_id' );
    }
    my $author = MT::Author->load({ id => $data->{entry_author_id}});
    if (!$author) {
        return $plugin->translate( 'Specified user not found' );
    }
    unless ($author->is_superuser) {
        my $perms = MT::Permission->load({ blog_id => $blog_id, author_id => $data->{entry_author_id}});
        if (!$perms) {
            return $plugin->translate( 'Specified user has no permission' );
        }
        if ( ( $class eq 'entry' )
             && !$perms->can_do('administer_blog') ) {
            if ( $entry && ($author->id != $entry->author_id))  {
                if (!$perms->can_do('edit_all_posts')) {
                    return $plugin->translate( 'Specified user has no edit permission' );
                }
            } else {
                if (!$perms->can_post) {
                    return $plugin->translate( 'Specified user has no post permission' );
                }
            }
        }
        if ( ( $class eq 'page' )
             && !$perms->can_do('administer_website') ) {
            if (!$perms->can_do('manage_pages')) {
                return $plugin->translate( 'Specified user has no edit page permission' );
            }
        }
    }

    ### entry_title
    unless (_check_field_value( $data->{entry_title}, 1, 0 )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_title' );
    }

    # entry identity.
    if ($entry) {
        # ensure blog ID was not modified.
        if ( $blog_id && ($entry->blog_id ne $blog_id) ) {
            return $plugin->translate( 'The value of [_1] is invalid', 'entry_class' ) . ". " . $plugin->translate( 'Blog ID was not matched.');
        }
        # ensure object class was not modified.
        if ( $data->{entry_class} && ( $entry->class ne $data->{entry_class}) ) {
            return $plugin->translate( 'The value of [_1] is invalid', 'entry_class' ) . ". " . $plugin->translate( 'Object class was not matched.');
        }

    }

    ### entry_basename
    unless (_check_field_value( $data->{entry_basename}, 1, 0 )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_basename' );
    }

    ### entry_status
    if ($MT::VERSION >= 6 ) {

        ## r34689 for mt6
        @values = ( 1..6 );
        unless (_check_field_value( $data->{entry_status}, 0, 1, \@values )) {
            return $plugin->translate( 'The value of [_1] is invalid', 'entry_status' );
        }
        ## 公開日より過去は指定できない
        if ( $data->{entry_unpublished_on} ) {

            my @u = parse_date( $data->{entry_unpublished_on} || '' );
            my @a = parse_date( $data->{entry_authored_on} || '' );
            my $u = @u ? sprintf( '%04d%02d%02d%02d%02d%02d', @u[0 .. 5] ) : '';
            my $a = @a ? sprintf( '%04d%02d%02d%02d%02d%02d', @a[0 .. 5] ) : '';
            unless ( $u && $a && ( $u > $a ) ) {
                return MT->translate('Invalid date \'[_1]\'; \'Unpublished on\' dates should be later than the corresponding \'Published on\' date.', MT::Util::encode_html( $data->{entry_unpublished_on} ) );
            }
        }

    }
    else {
        @values = ( 1..4 );
        unless (_check_field_value( $data->{entry_status}, 0, 1, \@values )) {
            return $plugin->translate( 'The value of [_1] is invalid', 'entry_status' );
        }
    }

    ### entry_allow_comments
    @values = ( 0, 1 );
    unless (_check_field_value( $data->{entry_allow_comments}, 0, 1, \@values )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_allow_comments' );
    }

    ### entry_allow_pings
    @values = ( 0, 1 );
    unless (_check_field_value( $data->{entry_allow_pings}, 0, 1, \@values )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_allow_pings' );
    }

    ### entry_created_by
    unless (_check_field_value( $data->{entry_created_by}, 0, 1 )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_created_by' );
    }

    ### entry_modified_by
    unless (_check_field_value( $data->{entry_modified_by}, 0, 1 )) {
        return $plugin->translate( 'The value of [_1] is invalid', 'entry_modified_by' );
    }

    ### category_id
    my $category_id    = $data->{'entry_category_id'};
    my @category_ids   = split ',', $category_id;
    foreach my $cate_id (@category_ids) {
        if ($cate_id) {
            my $category = MT::Category->load({ id => $cate_id });
            if (!$category) {
                return $plugin->translate( 'Not found category_id [_1]', $cate_id );
            }
            if ($category->blog_id != $blog_id) {
                return $plugin->translate( 'Not found category_id [_1] in specified blog', $cate_id );
            }
        }
    }
    return '';
}

sub get_system_charset {
    my $app = shift;
    {   'shift_jis' => 'sjis',
        'iso-2022-jp' => 'jis',
        'euc-jp' => 'euc',
        'utf-8' => 'utf8'
    }->{lc $app->config->PublishCharset} || 'utf8';
}

1;
