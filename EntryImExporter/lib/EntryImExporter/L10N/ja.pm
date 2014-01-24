package EntryImExporter::L10N::ja;

use strict;
use base 'EntryImExporter::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (

  ## common

    'SKYARC Co.,Ltd.' => '株式会社スカイアーク',

  ## EntryImExporter

    # Application
    'Entry management', => 'ブログ記事の一括管理',
    'Page management', => 'ウェブページの一括管理',
    'Export all entries of blog(s) to CSV file format. And import entries from exported CSV data.'
        =>'ブログ記事・ウェブページをCSVフォーマットで一括登録・出力するプラグインです。',
    # Importer
    'CSV file' => 'CSV ファイル',
    'Execute' => '実行する',
    'Select exported CSV (The columns that have invalid data will not be stored.)' => 'エントリーのデータが保存されたCSVファイルを選択します。CSVファイルに無効な値が挿入されている場合、エントリーの登録は行われません。',
    'If there is entry have a same entry_id, existing entry\'s data are over written.' 
        => '同じエントリーIDが存在する場合、そのエントリーを上書きする。',
    'Number of fields is too few.' => 'フィールド数が足りません',
    'Not found category_id [_1]' => 'カテゴリ ID [_1] が見つかりません',
    'Not found category_id [_1] in specified blog' => '指定されたブログにカテゴリ ID [_1] が見つかりません',
    'The value of [_1] is invalid' => '[_1] の値が不正です',
    'Specified blog not found id=[_1]' => '投稿先のブログが見つかりません',
    'Specified user not found' => '投稿ユーザーが見つかりません',
    'Specified user has no permission' => '指定ユーザーに投稿権限がありません',
    'Entry save error' => 'エントリーの保存に失敗しました',
    'Category save error (entry_id=[_1])' => 'カテゴリーの保存に失敗しました (entry_id=[_1])',
    'File upload error' => 'ファイルのアップロードに失敗しました',
    'CSV file type error' => 'ファイルの拡張子が CSV ではありません',
    'Title fields not found [_1]' => 'タイトルにフィールド [_1] が見つかりません',
    'Fields count and title count are different' => 'フィールド数がタイトルと異なります',
    '[_1] lines' => '[_1] 件目',
    'count' => '件',
    'CSV post error' => 'CSVデータ取込中にエラーが発生しました。',
    'CSV all posted' => 'CSVデータの一括登録を行いました。',
    'all [_1] count'   => '全 [_1] 件中',
    'add [_1] count'   => '追加 [_1] 件',
    'update [_1] count'=> '更新 [_1] 件',
    'skip [_1] count'  => '未処理 [_1] 件',
    'error [_1] count' => 'エラー [_1] 件',
    'detail' => '詳しくは',
    'ログを確認' => 'view log',
    'Against Website (id:[_1]), entry can\'t be registered.' => 'ウェブサイト(id:[_1])に対して、ブログ記事を登録することはできません。',
    '[_1] Line' => '[_1] 行目 ',
    'This Data is Blog Entry Data' => 'このデータはブログ記事データです。',
    'This Data is Web Page Data' => 'このデータはウェブページデータです。',
    'Select blog' => '出力対象ブログ', 

    'All blogs' => '全てのブログ', 
    'All websites' => '全てのウェブサイト',
    'All' => '全て',
    'Website and belonged blog to [_1]' => '[_1]とその所属するブログ',
    'Belonged blog to [_1]' => '[_1]に所属するブログ',

    'Import from CSV' => 'CSV一括登録する', 
    'Export to CSV' => 'CSV一括出力する', 
    'entry data csv export' => 'ブログ記事をCSVフォーマットで出力します。',
    'Overwrite Entries' => 'ブログ記事の上書き',
    'Overwrite Pages' => 'ウェブページの上書き',
    'entry data csv import' => 'ブログ記事をCSVフォーマットで登録します。',
    'page data csv import' => 'ウェブページをCSVフォーマットで登録します。',
    'entry data csv export' => 'ブログ記事をCSVフォーマットで出力します。',
    'page data csv export' => 'ウェブページをCSVフォーマットで出力します。',
    'Import Entries'   => 'ブログ記事のインポート', 
    'Export Entries'   => 'ブログ記事のエクスポート', 
    'Import Pages'   => 'ウェブページのインポート', 
    'Export Pages'   => 'ウェブページのエクスポート', 
    'Select exported blog entry CSV (The columns that have invalid data will not be stored.)' => 'ブログ記事のデータが保存されたCSVファイルを選択します。CSVファイルに無効な値が挿入されている場合、ブログ記事の登録は行われません。',
    'Select exported web page CSV (The columns that have invalid data will not be stored.)' => 'ウェブページのデータが保存されたCSVファイルを選択します。CSVファイルに無効な値が挿入されている場合、ウェブページの登録は行われません。',
    'If there is blog entry have a same id, existing entry\'s data are over written.' => '同じブログ記事IDが存在する場合、そのブログ記事を上書きする。',
    'If there is web page have a same id, existing page\'s data are over written.' => '同じウェブページIDが存在する場合、そのウェブページを上書きする。',
    'The CSV is not open in Exel. Exceeded the character limit of the cell.' => 'このCSVはExelでは開く事が出来ません。セルの文字数制限を超えました。',

    'Posted a blog(id:[_1]) without permission.' => 'ブログ(id:[_1])への投稿権限がありません。',
    'Website It is not possible to register a blog(id:[_1]) post.' => 'ウェブサイトへのブログ記事(id:[_1])の登録は出来ません。',

    'Encoding' => '文字コード',
    'Read CSV with specified encoding.' => 'CSVを指定した文字コードで読み込みます。',
    'Write CSV with specified encoding.' => 'CSVを指定した文字コードで書き出します。',
);


1;
