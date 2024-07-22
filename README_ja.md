# a-shell: iOS用の複数ウィンドウを備えたターミナル

<p align="center">
<img src="https://img.shields.io/badge/Platform-iOS%2014.0+-lightgrey.svg" alt="Platform: iOS">
<a href="https://twitter.com/a_Shell_iOS"><img src="https://img.shields.io/badge/Twitter-@a__Shell__iOS-blue.svg?style=flat" alt="Twitter"/></a>
<a href="https://discord.gg/cvYnZm69Gy"><img src="https://img.shields.io/discord/935519150305050644?color=5865f2&label=Discord&style=flat" alt="Discord"/></a>
</p>

このプロジェクトの目標は、iOS上でシンプルなUnixのようなターミナルを提供することです。[ios_system](https://github.com/holzschu/ios_system/)を使用してコマンドを解釈し、[ios_system](https://github.com/holzschu/ios_system/)エコシステムのすべてのコマンド（nslookup、whois、python3、lua、pdflatex、lualatexなど）を含んでいます。

プロジェクトは、iPadOS 13の複数ウィンドウの作成と管理の機能を使用しています。各ウィンドウはそれぞれのコンテキスト、外観、コマンド履歴、およびカレントディレクトリを持っています。`newWindow`は新しいウィンドウを開き、`exit`は現在のウィンドウを閉じます。

ヘルプを見るには、コマンドラインで`help`と入力します。`help -l`は利用可能なすべてのコマンドを一覧表示します。`help -l | grep command`を入力すると、お気に入りのコマンドがすでにインストールされているかどうかがわかります。

`config`を使用してa-Shellの外観を変更できます。これにより、フォント、フォントサイズ、背景色、テキストの色、およびカーソルの色と形状を変更できます。各ウィンドウはそれぞれの外観を持つことができます。`config -p`は現在のウィンドウの設定を永続化し、将来のすべてのウィンドウで使用されます。`config -t`を使用してツールバーを設定することもできます。

新しいウィンドウを開くと、a-Shellは`.profile`ファイルが存在する場合にそれを実行します。これを使用して環境変数をカスタマイズしたり、一時ファイルをクリーンアップしたりできます。

a-Shellの使用方法の詳細については、<a href="https://bianshen00009.gitbook.io/a-guide-to-a-shell/">ドキュメント</a>を参照してください。

## AppStore

a-Shellは現在、<a href="https://holzschu.github.io/a-Shell_iOS/">AppStoreで入手可能</a>です。

## コンパイル方法

プロジェクトを自分でコンパイルしたい場合は、以下の手順が必要です：
* `git submodule update --init --recursive`でプロジェクト全体とそのサブモジュールをダウンロードします
* `downloadFrameworks.sh`ですべてのxcFrameworksをダウンロードします
    * これにより、標準のAppleフレームワークがダウンロードされます（`xcfs/.build/artefacts/xcfs`にあり、チェックサム制御があります）。
    * Pythonフレームワークは多すぎて（2000以上）自動でダウンロードできません。プロジェクトの「Embed」ステップからそれらを削除するか、以下の手順でコンパイルすることができます：
        * Xcode Command Line Toolsが必要です。まだインストールされていない場合は`sudo xcode-select --install`。
        * macOS向けのOpenSSLライブラリ（libsslおよびlibcrypto）、XQuartz（freetype）、Node.js（npm）が必要です（iOSおよびシミュレータ向けのバージョンは提供しています）。
        * `cd cpython`でディレクトリを`cpython`に変更します
        * `sh ./downloadAndCompile.sh`でPython 3.11および関連するライブラリやフレームワークをビルドします（このステップには2GHzのi5 MBPでは数時間かかります）。

a-Shellは現在デバイス上で動作します。a-Shell miniはデバイス上およびシミュレータ上で動作できます。

Python 3.xはiOS 14 SDKでのみ使用できる関数を使用しているため、最小iOSバージョンを14.0に設定しています。これによりバイナリのサイズも削減されるため、`ios_system`や他のフレームワークも同じ設定になっています。iOS 13デバイスで実行する必要がある場合は、ほとんどのフレームワークを再コンパイルする必要があります。

## ホームディレクトリ

iOSでは、`~`ディレクトリには書き込みできず、`~/Documents/`、`~/Library/`、および`~/tmp`のみに書き込むことができます。ほとんどのUnixプログラムは設定ファイルが`$HOME`にあると想定しています。

したがって、a-Shellはこれらが`~/Documents`を指すようにいくつかの環境変数を変更します。`env`を入力してそれらを確認できます。

ほとんどの設定ファイル（Pythonパッケージ、TeXファイル、Clang SDKなど）は`~/Library`にあります。

## サンドボックスとブックマーク

a-ShellはiOS 13の機能を使用して他のアプリのサンドボックス内のディレクトリにアクセスしています。`pickFolder`を入力して他のアプリ内のディレクトリにアクセスできます。一度ディレクトリを選択すると、ここでほぼすべての操作が可能になるため、注意してください。

`pickFolder`でアクセスしたすべてのディレクトリはブックマークされるため、`pickFolder`なしで後でそれらに戻ることができます。また、`bookmark`でカレントディレクトリをブックマークすることもできます。`showmarks`は現在のブックマークをすべて列挙し、`jump mark`および`cd ~mark`はカレントディレクトリをその特定のブックマークに変更し、`renamemark`は特定のブックマークの名前を変更し、`deletemark`はブックマークを削除します。

設定のユーザーが変更可能なオプションで、`s`、`g`、`l`、`r`、`d`コマンドを代わりに、または併用して使用することができます。

迷子になった場合は、`cd`で常に`~/Documents/`に戻ることができます。`cd -`は直前のディレクトリに変更します。

## ショートカット

a-ShellはApple Shortcutsと互換性があり、ユーザーにシェルの完全な制御を提供します。a-Shellコマンドを使用してファイルのダウンロード、処理、リリースを行う複雑なショートカットを作成できます。3つのショートカットがあります：
- `Execute Command`はコマンドのリストを受け取り、それらを順番に実行します。入力はファイルまたはテキストノードであり、ノード内のコマンドが実行されます。
- `Put File`および`Get File`はa-Shellとファイルを転送するために使用されます。

ショートカットは「In Extension」または「In App」で実行できます。「In Extension」はAppの軽量バージョンで、グラフィカルユーザーインターフェースがなしでショートカットが実行されることを意味します。設定ファイルやシステムライブラリ（mkdir、nslookup、whois、touch、cat、echoなど）が不要な軽量なコマンドに適しています。「In App」はメインアプリケーションを開いてショートカットを実行します。すべてのコマンドにアクセスできますが、時間がかかります。ショートカットがアプリを開いたら、`open shortcuts://`コマンドを呼び出してShortcutsアプリに戻ることができます。デフォルトの動作は、コマンドの内容に基づいてできるだけショートカットを「In Extension」で実行しようとすることです。特定のショートカットを「In App」または「In Extension」で実行することもできますが、常に機能するとは限らないことに注意してください。

両方の種類のショートカットはデフォルトで同じ特定のディレクトリ、`$SHORTCUTS`または`~shortcuts`で実行されます。もちろん、`cd`および`jump`コマンドを実行できるため、ほぼどこにでも移動できます。

## プログラミング / コマンドの追加:

a-Shellには、Python、Lua、JS、C、C++、TeXなどのいくつかのプログラミング言語がインストールされています。

CおよびC++では、プログラムを`clang program.c`でコンパイルし、WebAssemblyファイルが生成されます。その後、`wasm a.out`で実行できます。また、複数のオブジェクトファイルをリンクしたり、`ar`で静的ライブラリを作成したりすることもできます。プログラムに満足したら、それを`$PATH`内のディレクトリに移動させ（例：`~/Documents/bin`）、`program.wasm`に名前を変更すると、コマンドラインで`program`と入力すると実行されるようになります。

また、メインコンピューターで私たち独自の[WASI-sdk](https://github.com/holzschu/wasi-sdk)を使用してプログラムをクロスコンパイルし、WebAssemblyファイルをiPadやiPhoneに転送することもできます。

a-Shell専用のコンパイル済みWebAssemblyコマンドは https://github.com/holzschu/a-Shell-commands で入手可能です。これには`zip`、`unzip`、`xz`、`ffmpeg`などが含まれます。これらはダウンロードして`$PATH`に配置することでiPadにインストールできます。

ソケットなし、フォークなし、対話的なユーザー入力なし（他のコマンドからの入力を`command | wasm program.wasm`でパイプすることは問題ありません）といったWebAssemblyの制約があります。

Pythonでは、`pip install packagename`を使用して追加のパッケージをインストールできますが、それらが純粋なPythonである場合に限られます。CコンパイラはまだPythonで使用できる動的ライブラリを生成することができません。

TeXのファイルはデフォルトではインストールされていません。任意のTeXコマンドを入力すると、システムはそれをダウンロードするように促します。LuaTeXのファイルも同様です。

## VoiceOver

設定でVoiceOverを有効にすると、a-ShellはVoiceOverと連携し、コマンドを入力する際に読み上げたり、結果を読み上げたり、指で触れた画面を読み上げたりなどを行います。
