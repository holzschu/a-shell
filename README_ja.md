# a-shell: iOS用の複数ウィンドウを備えたターミナル

<p align="center">
<img src="https://img.shields.io/badge/Platform-iOS%2014.0+-lightgrey.svg" alt="Platform: iOS">
<a href="https://twitter.com/a_Shell_iOS"><img src="https://img.shields.io/badge/Twitter-@a__Shell__iOS-blue.svg?style=flat" alt="Twitter"/></a>
<a href="https://discord.gg/cvYnZm69Gy"><img src="https://img.shields.io/discord/935519150305050644?color=5865f2&label=Discord&style=flat" alt="Discord"/></a>
</p>

このプロジェクトの目標は、iOS上でシンプルなUnixのようなターミナルを提供することです。[ios_system](https://github.com/holzschu/ios_system/)を使用してコマンドを解釈し、[ios_system](https://github.com/holzschu/ios_system/)エコシステムのすべてのコマンド（nslookup、whois、python3、lua、pdflatex、lualatexなど）を含んでいます。

プロジェクトは、iPadOS 13の複数ウィンドウの作成と管理の機能を使用しています。各ウィンドウには独自のコンテキスト、外観、コマンド履歴、および現在のディレクトリがあります。`newWindow`は新しいウィンドウを開き、`exit`は現在のウィンドウを閉じます。

ヘルプには、コマンドラインで`help`と入力します。`help -l`は利用可能なすべてのコマンドを一覧表示します。`help -l | grep command`を入力すると、お気に入りのコマンドがすでにインストールされているかどうかがわかります。

`config`を使用してa-Shellの外観を変更できます。これにより、フォント、フォントサイズ、背景色、テキストの色、およびカーソルの色と形状を変更できます。各ウィンドウは独自の外観を持つことができます。`config -p`は現在のウィンドウの設定を永続化し、将来のすべてのウィンドウで使用されます。`config -t`を使用してツールバーも構成できます。

新しいウィンドウを開くと、a-Shellは`.profile`ファイルが存在する場合にそれを実行します。これを使用して環境変数をカスタマイズしたり、一時ファイルをクリーンアップしたりできます。

a-Shellの使用方法の詳細については、<a href="https://bianshen00009.gitbook.io/a-guide-to-a-shell/">ドキュメント</a>を参照してください。

## AppStore

a-Shellは現在、<a href="https://holzschu.github.io/a-Shell_iOS/">AppStoreで利用可能</a>です。

## コンパイル方法

プロジェクトを自分でコンパイルしたい場合は、以下の手順が必要です：
* プロジェクト全体とそのサブモジュールをダウンロードします：`git submodule update --init --recursive`
* すべてのxcFrameworksをダウンロードします：`downloadFrameworks.sh`
    * これにより、標準のAppleフレームワークがダウンロードされます（`xcfs/.build/artefacts/xcfs`にあり、チェックサム制御があります）。
    * Pythonフレームワークが多すぎて（2000以上）自動でダウンロードできません。プロジェクトの「Embed」ステップからそれらを削除するか、コンパイルできます：
        * まずXcodeのコマンドラインツールが必要です（まだインストールされていない場合は`sudo xcode-select --install`）。
        * OpenSSLライブラリ（libsslおよびlibcrypto）、XQuartz（freetype）、およびmacOS向けのNode.js（npm）が必要です（iOSおよびシミュレータ用のバージョンを提供しています）。
        * ディレクトリを`cpython`に変更します：`cd cpython`
        * Python 3.11および関連するライブラリ/フレームワークをビルドします：`sh ./downloadAndCompile.sh`（このステップには2GHzのi5 MBPでは数時間かかります）。

a-Shellは現在デバイス上で実行されます。a-Shell miniはデバイスおよびシミュレータで実行できます。

Python 3.xはiOS 14 SDKでのみ使用できる関数を使用しているため、最小iOSバージョンを14.0に設定しています。これによりバイナリのサイズも削減され、`ios_system`および他のフレームワークが同じ設定になります。iOS 13デバイスで実行する必要がある場合は、ほとんどのフレームワークを再コンパイルする必要があります。

## ホームディレクトリ

iOSでは、`~`ディレクトリには書き込みできず、`~/Documents/`、`~/Library/`、および`~/tmp`のみに書き込むことができます。ほとんどのUnixプログラムは設定ファイルが`$HOME`にあると想定しています。

したがって、a-Shellはこれらが`~/Documents`を指すようにいくつかの環境変数を変更します。`env`を入力してそれらを確認できます。

ほとんどの設定ファイル（Pythonパッケージ、TeXファイル、Clang SDKなど）は`~/Library`にあります。

## サンドボックスとブックマーク

a-ShellはiOS 13が他のアプリのサンドボックス内のディレクトリにアクセスできる機能を使用しています。`pickFolder`を入力して他のアプリ内のディレクトリにアクセスできます。一度ディレクトリを選択すると、ここでほぼすべての操作が可能になるため、注意してください。

`pickFolder`でアクセスしたすべてのディレクトリはブックマークされるため、`pickFolder`なしで後でそれらに戻ることができます。また、現在のディレクトリを`bookmark`でブックマークすることもできます。`showmarks`はすべての既存のブックマークをリスト表示し、`jump mark`および`cd ~mark`で現在のディレクトリを特定のブックマークに変更し、`renamemark`でブックマークの名前を変更し、`deletemark`でブックマークを削除できます。

設定でユーザーがオプションを変更でき、`s`、`g`、`l`、`r`、および`d`コマンドも使用できます。

迷子になった場合は、`cd`で常に`~/Documents/`に戻ることができます。`cd -`は前のディレクトリに変更します。

## ショートカット

a-ShellはApple Shortcutsと互換性があり、ユーザーにシェルの完全な制御を提供します。a-Shellコマンドを使用してファイルのダウンロード、処理、リリースを行う複雑なショートカットを作成できます。3つのショートカットがあります：
- `Execute Command`はコマンドのリストを受け取り、それらを順番に実行します。入力はファイルまたはテキストノードであり、ノード内のコマンドが実行されます。
- `Put File`および`Get File`はa-Shellとファイルを転送するために使用されます。

ショートカットは「In Extension」または「In App」で実行できます。 「In Extension」はAppの軽量バージョンでショートカットが実行され、グラフィカルユーザーインターフェースがないことを意味します。構成ファイルやシステムライブラリが不要な軽量なコマンドに適しています（mkdir、nslookup、whois、touch、cat、echoなど）。 「In App」はメインアプリケーションを開いてショートカットを実行します。すべてのコマンドにアクセスできますが、時間がかかります。ショートカットがアプリを開いたら、`open shortcuts://`コマンドを呼び出してShortcutsアプリに戻ることができます。デフォルトの動作は、コマンドの内容に基づいてできるだけショートカットを「In Extension」で実行しようとすることです。特定のショートカットを「In App」または「In Extension」で実行することもできますが、常に機能しないことに注意してください。

両方の種類のショートカットはデフォルトで同じ特定のディレクトリ、`$SHORTCUTS`または`~shortcuts`で実行されます。もちろん、`cd`および`jump`コマンドを実行できるため、ほぼどこにでも移動できます。

## プログラミング / コマンドの追加:

a-Shellには、いくつかのプログラミング言語がインストールされています: Python、Lua、JS、C、C++、およびTeXです。

CおよびC++では、プログラムを `clang program.c` でコンパイルし、WebAssemblyファイルが生成されます。その後、`wasm a.out` で実行できます。また、複数のオブジェクトファイルをリンクしたり、`ar` で静的ライブラリを作成したりすることもできます。プログラムに満足したら、それを `$PATH` 内のディレクトリに移動させ（例：`~/Documents/bin`）、`program.wasm` に名前を変更すると、コマンドラインで `program` と入力すると実行されます。

また、メインコンピューターで特定の [WASI-sdk](https://github.com/holzschu/wasi-sdk) を使用してプログラムをクロスコンパイルし、WebAssemblyファイルをiPadやiPhoneに転送することもできます。

特定のa-Shell用に事前にコンパイルされたWebAssemblyコマンドはこちらで利用可能です: https://github.com/holzschu/a-Shell-commands これには `zip`、`unzip`、`xz`、`ffmpeg` などが含まれます。これらはダウンロードして `$PATH` に配置することでiPadにインストールできます。

WebAssemblyの制限があります: ソケットなし、フォークなし、対話的なユーザー入力なし（他のコマンドからの入力を `command | wasm program.wasm` でパイプすることは問題ありません）。

Pythonでは、 `pip install packagename` を使用して追加のパッケージをインストールできますが、それらは純粋なPythonである場合に限ります。CコンパイラはまだPythonで使用できる動的ライブラリを生成することができません。

TeXファイルはデフォルトではインストールされていません。任意のTeXコマンドを入力すると、システムはそれをダウンロードするように促します。LuaTeXファイルも同様です。

## VoiceOver

設定でVoiceOverを有効にすると、a-ShellはVoiceOverと連携します: コマンドを入力する際に読み上げ、結果を読み上げ、指で画面を読むことができます...
