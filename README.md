# KokugoTagger

cabocha形式のファイルに対して、学校文法に準拠した係り受けラベルを付与します。

## Installation

事前に以下のツールをインストールし、パスを通しておく必要があります。

- Ruby
- YamCha

コマンドラインから以下のように入力し、インストールしてください。

    $ gem install kokugo_tagger

## Usage

UTF-8/UniDicのCaboCha形式データにのみ対応しています。CaboCha形式のファイルにラベルを付与する場合は、次のように実行してください。

    $ cat neko.cabocha | kokugo_tagger > output.cabocha

プレーンテキストの場合は、次のようにCaboChaと組み合わせて下さい。CaboChaは別途インストールしてください。

    $ cat neko.txt | cabocha -f1 | kokugo_tagger > output.cabocha

コマンドライン上で対話的に実行することもできます。

    $ cabocha -f1 | kokugo_tagger
    吾輩は猫である
    * 0 1S 0/1 0.000000
    吾輩	代名詞,*,*,*,*,*,ワガハイ,我が輩,吾輩,ワガハイ,吾輩,ワガハイ,混,*,*,*,*,ワガハイ,ワガハイ,ワガハイ,ワガハイ,*,*,0,*,*	O
    は	助詞,係助詞,*,*,*,*,ハ,は,は,ワ,は,ワ,和,*,*,*,*,ハ,ハ,ハ,ハ,*,*,*,"動詞%F2@0,名詞%F1,形容詞%F2@-1",*	O
    * 1 -1X 2/2 0.000000
    猫	名詞,普通名詞,一般,*,*,*,ネコ,猫,猫,ネコ,猫,ネコ,和,*,*,*,*,ネコ,ネコ,ネコ,ネコ,*,*,1,C4,*	O
    で	助動詞,*,*,*,助動詞-ダ,連用形-一般,ダ,だ,で,デ,だ,ダ,和,*,*,*,*,デ,ダ,デ,ダ,*,*,*,名詞%F1,*	O
    ある	動詞,非自立可能,*,*,五段-ラ行,終止形-一般,アル,有る,ある,アル,ある,アル,和,*,*,*,*,アル,アル,アル,アル,*,*,1,C3,*	O
    EOS

係り受けラベルは以下の8種類です。

- S: 主語
- R: 連用修飾語
- T: 連体修飾語
- Z: 接続語
- D: 独立語
- H: 並立の関係
- J: 補助の関係
- X: その他(文末など)

## Contributing

1. Fork it ( https://github.com/[my-github-username]/kokugo_tagger/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
