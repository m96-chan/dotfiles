<div align="center">

<img src="splash.png" width="300" />

# m96-chan/dotfiles

**~ my cozy terminal setup ~**

[![OS](https://img.shields.io/badge/Arch-1793D1?style=flat-square&logo=archlinux&logoColor=white)](https://archlinux.org/)
[![OS](https://img.shields.io/badge/Fedora-51A2DA?style=flat-square&logo=fedora&logoColor=white)](https://fedoraproject.org/)
[![OS](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Terminal](https://img.shields.io/badge/Kitty-000000?style=flat-square&logo=gnometerminal&logoColor=white)](https://sw.kovidgoyal.net/kitty/)
[![Shell](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Prompt](https://img.shields.io/badge/Starship-DD0B78?style=flat-square&logo=starship&logoColor=white)](https://starship.rs/)

</div>

---

Bash + Kitty + Starship をベースにした個人用 dotfiles。
ターミナル起動時にシステム情報を表示する MOTD、Tokyo Night カラースキーム、AI/Tech ニュースダッシュボードなどを含む。
Arch Linux の pacman 環境と macOS（Apple Silicon / Intel）で共通利用する。Homebrew は任意。

## 構成

```
.
├── .bashrc              # メイン設定 (MOTD, ghq+fzf, starship 等)
├── .bashrc.aliases      # エイリアス定義
├── .gitconfig.aliases   # Git エイリアス
├── .motd_art            # MOTD 用アスキーアート
├── .config/
│   ├── kitty/kitty.conf # Kitty 設定 (Tokyo Night テーマ)
│   ├── starship.toml    # Starship プロンプト設定
│   ├── wtf/config.yml   # WTF ダッシュボード設定
│   ├── goose/          # Goose 設定・レシピ
│   └── pistol/pistol.conf # 画像・動画プレビュー
├── setup.sh             # シンボリックリンク作成スクリプト
└── splash.png           # スプラッシュ画像
```

## 必要なツール

| ツール | 用途 |
|--------|------|
| [Kitty](https://sw.kovidgoyal.net/kitty/) | GPU ベースのターミナルエミュレータ |
| [Starship](https://starship.rs/) | カスタマイズ可能なシェルプロンプト |
| [fzf](https://github.com/junegunn/fzf) | ファジーファインダー |
| [ghq](https://github.com/x-motemen/ghq) | リポジトリ管理 (`Ctrl+]` で fzf 連携ジャンプ) |
| [Homebrew](https://brew.sh/) | パッケージマネージャ (Linux でも使用) |
| [nvm](https://github.com/nvm-sh/nvm) | Node.js バージョン管理 |
| [Rust / Cargo](https://rustup.rs/) | Rust ツールチェイン |
| [btop](https://github.com/aristocratos/btop) | リソースモニタ |
| [WTF](https://wtfutil.com/) | ターミナルダッシュボード (ニュース, リソース監視) |
| [circumflex](https://github.com/bensadeh/circumflex) | ターミナル用 Hacker News クライアント |
| [tickrs](https://github.com/tarkah/tickrs) | ターミナル用株価チャート |
| [fortune](https://wiki.archlinux.org/title/Fortune) | MOTD のランダム名言表示 |
| [Pistol](https://github.com/doronbehar/pistol) | `p` で呼ぶファイルプレビューア |
| [Chafa](https://hpjansson.org/chafa/) / [FFmpeg](https://ffmpeg.org/) | Pistol の画像・動画プレビュー |
| [HackGen Console NF](https://github.com/yuru7/HackGen) | Kitty で使用するフォント (Nerd Fonts 対応) |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | AI コーディングアシスタント CLI |

## インストール

### 共通 (全 OS)

```bash
# 1. リポジトリをクローン
ghq get m96-chan/dotfiles
# または
git clone https://github.com/m96-chan/dotfiles.git ~/dotfiles

# 2. シンボリックリンクを作成
cd ~/dotfiles  # or $(ghq root)/github.com/m96-chan/dotfiles
chmod +x setup.sh
./setup.sh

# 3. Rust ツールチェインをインストール
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 4. Cargo 経由のツールをインストール
cargo install tickrs
```

### macOS

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# ツール一括インストール
brew install starship fzf ghq nvm btop wtfutil circumflex fortune
brew install --cask kitty

# フォント
brew install --cask font-hackgen-nerd

# Pistol のビルドと画像・動画プレビュー
brew install go libmagic chafa ffmpeg
```

### Arch Linux

```bash
# 基本機能。Homebrew なしで使用できる。
sudo pacman -S --needed bash bash-completion git kitty starship fzf ghq nvm btop fortune-mod

# MOTD の詳細情報
sudo pacman -S --needed procps-ng pciutils iproute2

# Pistol のビルドと画像・動画プレビュー
sudo pacman -S --needed base-devel go file chafa ffmpeg
```

[nvm](https://archlinux.org/packages/extra/any/nvm/)、[ghq](https://archlinux.org/packages/extra/x86_64/ghq/)、
[Starship](https://archlinux.org/packages/extra/x86_64/starship/) は公式リポジトリからインストールできる。
`.bashrc` は Arch の `/usr/share/nvm/init-nvm.sh` と bash-completion を自動で読み込む。
WTF・circumflex・HackGen は各ツールのインストール手順や AUR を使って追加する。

### Fedora / Bazzite

Bazzite は immutable な OS のため、`rpm-ostree` またはコンテナ (`brew`, `distrobox`) 経由でインストールする。

```bash
# rpm-ostree で入るもの
rpm-ostree install kitty fzf fortune-mod

# Homebrew (Linuxbrew) を使う方法を推奨 (下記参照)
```

### Homebrew (Linux 共通)

CLI ツールを Homebrew で管理したい場合の選択肢。`.bashrc` はインストール済みの Homebrew を検出する。
Kitty はディストリビューションのパッケージマネージャでインストールする（Linux で `brew --cask` は使わない）。

```bash
# Homebrew をインストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# シェルに Homebrew を追加 (setup.sh で .bashrc がリンクされていれば自動)
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"

# ツール一括インストール
brew install starship fzf ghq nvm btop wtfutil circumflex fortune
```

### フォント (HackGen Console NF)

Kitty の設定で `HackGen Console NF` を使用している。手動でインストールする場合:

```bash
# 最新リリースを確認: https://github.com/yuru7/HackGen/releases
# 例:
wget https://github.com/yuru7/HackGen/releases/download/v2.9.0/HackGen_NF_v2.9.0.zip
unzip HackGen_NF_v2.9.0.zip
mkdir -p ~/.local/share/fonts
cp HackGen_NF_v2.9.0/*.ttf ~/.local/share/fonts/
fc-cache -fv
```

### nvm + Node.js

```bash
# pacman / Homebrew / ユーザー領域に nvm をインストールした後
source ~/.bashrc
nvm install --lts
nvm use --lts
```

### Pistol

上の OS 別の依存ツールをインストールし、Bash で実行する。
Arch の `file` パッケージには libmagic のヘッダも含まれるため、別の `libmagic-dev` パッケージは不要。
macOS の Homebrew 版 libmagic のビルド用フラグは `.bashrc` が設定する。

```bash
source ~/.bashrc
go install github.com/doronbehar/pistol/cmd/pistol@latest
p image.png
```

Go の出力先は `GOBIN`、または `GOPATH` の先頭の `bin`（未設定なら `~/go/bin`）を PATH に加える。

## setup.sh の動作

`setup.sh` は以下のシンボリックリンクを作成する:

| リンク先 | リンク元 |
|----------|----------|
| `~/.bashrc` | `.bashrc` |
| `~/.bashrc.aliases` | `.bashrc.aliases` |
| `~/.gitconfig.aliases` | `.gitconfig.aliases` |
| `~/.motd_art` | `.motd_art` |
| `~/.config/starship.toml` | `.config/starship.toml` |
| `~/.config/kitty/kitty.conf` | `.config/kitty/kitty.conf` |
| `~/.config/wtf/config.yml` | `.config/wtf/config.yml` |
| `~/.config/goose/config.yaml` | `.config/goose/config.yaml` |
| `~/.config/goose/recipes` | `.config/goose/recipes` |
| `~/.config/pistol/pistol.conf` | `.config/pistol/pistol.conf` |

`XDG_CONFIG_HOME` が設定されていれば、上表の `~/.config` の代わりにそのディレクトリを使う。
既存の通常ファイル・ディレクトリは `.dotfiles-backup` を付けて退避し、シンボリックリンクへ置き換える。
同名のバックアップが既にある場合は上書きせず停止する。再実行時もディレクトリへのリンクを辿らない。

`setup.sh` は Git のグローバル設定にも `include.path = ~/.gitconfig.aliases` を自動登録する。
繰り返し実行しても同じ include は重複しない。
Git エイリアスはこのリポジトリの `.gitconfig.aliases` で編集する。変更は次の Git コマンドから有効になる。
`.gitconfig` 本体のユーザー名・メールアドレス・認証設定などは各マシンで管理する。

## カスタマイズ

### OS 別の環境設定

`JAVA_HOME`・`ANDROID_HOME`・`ANDROID_SDK_ROOT`・`ANDROID_NDK_HOME` を既に設定していれば尊重する。
未設定の場合はインストール済みの JDK、Android SDK、NDK を検出する。
Arch の Java は Java 17、次に `/usr/lib/jvm/default`、macOS は `java_home` で Java 17、次に既定の JDK を探す。
SDK は `~/Android/Sdk`・`~/Library/Android/sdk`・`/opt/android-sdk` を候補とし、NDK はインストール済みの最新バージョンを使う。

Starship のOSアイコンは実行中のOSに合わせて変わる。Starship 未導入時は通常の Bash プロンプトを使う。
ログイン Bash から `.bashrc` が読み込まれない環境では、既存の `~/.bash_profile` に次を追加する:

```bash
[[ -r ~/.bashrc ]] && source ~/.bashrc
```

### MOTD

`.motd_art` を差し替えればターミナル起動時の画像を変更できる。
[chafa](https://hpjansson.org/chafa/) 等で画像をテキスト化して使用:

```bash
chafa --size=40x34 your_image.png > ~/.motd_art
```

起動時から CPU使用率・メモリ使用量・ルートディスク使用量/使用率・ローカルIPv4アドレスを表示する。
バッテリーがある場合は残量も表示する。
CPU使用率の計測には Linux で約0.1秒、macOS で約1秒かかる。
macOS では標準の `iostat` を使い、`top` による全プロセスの走査を避ける。
GPU名は起動時にはキャッシュから表示し、未作成の場合は `-` と表示する。
`motd` を実行するとGPU名も再取得して `${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/` に保存する。
`motd --brief` は起動時と同じ表示で、GPU名の再取得だけを省く。

横80列未満、アートを収められない高さ、アートファイルがない場合は、端末幅で折り返すテキスト表示に切り替える。
標準出力が端末でない場合は起動時の表示を省き、手動の `motd` はテキストを出力する。

### fzf

fzf の Bash 連携でパス選択・ディレクトリ移動・履歴検索を有効にする。
`fzf --bash` を使い、未対応の旧版ではディストリビューションや Homebrew に同梱された連携スクリプトを読み込む。
検索画面は高さ40%、候補を上から表示する枠付きの設定。既存の `FZF_DEFAULT_OPTS` があればそちらを優先する。
macOS の Kitty では左OptionキーをAltとして扱う設定なので、`左Option+C` でディレクトリ移動を使える。
Bash の設定は `reload` で反映できる。左Optionキーの変更には Kitty の再起動が必要。

### WTF ダッシュボード

`.config/wtf/config.yml` で RSS フィードやモジュールを編集可能。
デフォルトでは Yahoo! ニュース、Hacker News、AI 関連フィードを表示。

```bash
wtfutil
```

## ショートカット

### Bash

| キー | 動作 |
|------|------|
| `Ctrl+]` | ghq + fzf でリポジトリにジャンプ |
| `Ctrl+T` | fzf で選んだファイル・ディレクトリのパスを挿入 |
| `Alt+C` | fzf で選んだディレクトリに移動 |
| `Ctrl+R` | fzf でコマンド履歴を検索 |

### Kitty

| キー | 動作 |
|------|------|
| `Ctrl+Shift+T` | 新しいタブ |
| `Ctrl+Shift+W` | タブを閉じる |
| `Ctrl+Shift+→/←` | タブ移動 |
| `Ctrl+Shift+Enter` | 新しいウィンドウ |
| `Ctrl+Shift+]/[` | ウィンドウ移動 |
| `Ctrl+Shift+=/-/0` | フォントサイズ変更 |
| `Ctrl+Shift+F5` | 設定リロード |

### Git エイリアス

`.gitconfig.aliases` で管理する。`g` は Bash 側で `git` のエイリアスなので、`g st` のようにも使える。

| エイリアス | コマンド |
|-----------|---------|
| `git a` | `git add` |
| `git st` | `git status` |
| `git co` | `git checkout` |
| `git cm` | `git commit` |
| `git pp` | `git pull --prune` |
| `git poh` | `git push origin HEAD` |
| `git po` | `git push origin` |
| `git cl` | `git clone` |

### Bash の Git ショートカット

`.bashrc.aliases` で管理する。

| エイリアス | コマンド |
|-----------|---------|
| `gs` | `git status` |
| `ga` | `git add .` |
| `gc <msg>` | `git commit -m <msg>` |
| `gp` | `git push` |
| `gl` | `git log --oneline -20` |

## License

MIT
