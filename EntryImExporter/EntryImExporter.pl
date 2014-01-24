## SKYARC (C) 2004-2011 SKYARC System Co., Ltd., All Rights Reserved.
package MT::Plugin::EntryImExpoerter;

use strict;
use warnings;
use MT;
use MT::Plugin;
use base qw( MT::Plugin );
use vars qw( $MYNAME $VERSION );

$MYNAME = 'EntryImExporter';
$VERSION = '1.500';

my $plugin = __PACKAGE__->new({
    'name' => $MYNAME,
    'id' => lc $MYNAME,
    'key' => lc $MYNAME,
    'version' => $VERSION,
    'author_name' => '<__trans phrase="SKYARC System Co.,Ltd.">',
    'author_link' => 'http://www.skyarc.co.jp/',
    'doc_link' => 'http://www.skyarc.co.jp/engineerblog/entry/entryimexporter.html',
    'description' =><<'HTMLHEREDOC',
<__trans phrase="Export all entries of blog(s) to CSV file format. And import entries from exported CSV data.">
HTMLHEREDOC
    'l10n_class' => 'MTCMSImExporter::L10N',
    'settings' =>  new MT::PluginSettings([
        [ 'entry_im_exporter_use_sjis_export', { 'Default' => '1' } ],
        [ 'entry_im_exporter_use_sjis_import', { 'Default' => '1' } ],
    ]),
    'registry' => {
        'applications' => {
            'cms' => {
                'methods' => {
                    'run_entry_importer' => '$EntryImExporter::EntryImExporter::CMS::csv_import',
                    'run_entry_exporter' => '$EntryImExporter::EntryImExporter::CMS::csv_export',
                    'disp_page_importer' => '$EntryImExporter::EntryImExporter::CMS::disp_page',
                    'disp_entry_importer' => '$EntryImExporter::EntryImExporter::CMS::disp_entry'
                },
                'menus' => {
                    'entry:entry_im_exporter_entry' => {
                        'view' => [ 'system', 'blog', 'website' ],
                        'mode' => 'disp_entry_importer',
                        'order' => '720',
                        'label' => 'Entry management',
                        'condition' => '$EntryImExporter::EntryImExporter::CMS::_permission_check',
                    },
                    'page:entry_im_exporter_page' => {
                        'view' => [ 'system', 'blog', 'website' ],
                        'mode' => 'disp_page_importer',
                        'order' => '720',
                        'label' => 'Page management',
                        'condition' => '$EntryImExporter::EntryImExporter::CMS::_permission_check',
                    },
                }
            }
        }
    }
});
MT->add_plugin( $plugin );
1;
