# 簡易掲示板
CODEBASE受講生向けの簡易SNSサンプル
 
# クローンしてローカルで確認する方法
1. ターミナルを起動し、保存したいパス・ディレクトリへ移動。
2. `git clone https://github.com/takanori-matsushita/myboard.git`を実行。
3. 以下のデータベース構築を参考にSQL文を実行し、PGの設定。環境変数の説明を読んでみて、設定できそうであれば、チャレンジしてみる。
4. `ruby app.rb`で[http://localhost:4567](http://localhost:4567)へアクセス。
 
## データベースについて
 
### ER図
<img width="748" alt="mybord_table" src="https://user-images.githubusercontent.com/56256994/76166697-d89db880-61a3-11ea-8794-6fb4f0c9f49b.png">
 
テーブル設計の内容については、[#1テーブル設計-ER図](https://github.com/takanori-matsushita/myboard/issues/1)を参照。
 
### データベース構築
詳しいSQLの内容については、[#2データベース作成時のSQL文の解説](https://github.com/takanori-matsushita/myboard/issues/2)を参照

データベースにログイン
```
Macの方
psql -d postgres
 
Windowsの方
psql -d postgres -U lagoon
```
データベースの作成
```
CREATE DATABASE myboard;
```
作成したデータベースに切り替える
```
\c myboard
```
ユーザーテーブルの作成
```
CREATE TABLE users(
  id SERIAL NOT NULL PRIMARY KEY,
  name VARCHAR(20) NOT NULL,
  email VARCHAR(50) NOT NULL,
  password VARCHAR(20) NOT NULL,
  image VARCHAR(20) DEFAULT 'profile_img.jpg',
  introduce VARCHAR(20) DEFAULT 'よろしくお願いします。',
  birthday DATE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```
ポストテーブルの作成
```
CREATE TABLE posts(
  id SERIAL NOT NULL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  title VARCHAR(20) NOT NULL,
  content VARCHAR(255) NOT NULL,
  image VARCHAR(50),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```
フォロー・フォロワーテーブルの作成
```
CREATE TABLE followers(
  id SERIAL NOT NULL PRIMARY KEY,
  following INTEGER NOT NULL,
  followed INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```
コメントテーブルの作成
```
CREATE TABLE comments(
  id SERIAL NOT NULL PRIMARY KEY,
  post_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  content VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```
いいねテーブルの作成
```
CREATE TABLE likes(
  id SERIAL NOT NULL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  post_id INTEGER NOT NULL
);
```
#### 
更新日時を取得し、保存する関数(カラム名がupdated_atを対象に実行する)
```
create function set_update_time() returns opaque as '
  begin
    new.updated_at := ''now'';
    return new;
  end;
' language 'plpgsql';
```
更新機能は、usersテーブルとpostテーブルだけ実装しているため、その2つのテーブルにトリガーを設定
```
create trigger update_tri before update on users for each row
  execute procedure set_update_time();
```
```
create trigger update_tri before update on posts for each row
  execute procedure set_update_time();
```

## Sinatraとデータベースの接続
Sinatraとデータベースを連携するにはpgの設定が必要。  
app.rbの`enable :sessions`の下の設定を自身のPCの環境へ変更。
```
def db
  PG::connect(
    host: '', #今回はローカル環境なのでlocalhost
    user: '', #ターミナルでwhoamiを実行し表示されたユーザー名
    password: '', #接続時のパスワード今回は設定しないので、空白
    dbname: '' #作成したデータベース名
  ) 
end
```

## 環境変数について
 
### 環境変数とは？
環境変数とはそのシェル内の環境のみで扱うことができる変数。
例えばapp.rbファイルにそのまま情報を書き込んでgit等で管理すると、悪意のある第三者に利用される危険性があるので注意が必要。
 
### 環境変数の設定方法
Sinatraで環境変数を使うには、ENVという記述で対応できる。
```
def db
  PG::connect(
    host: ENV['DB_HOST'],
    user: ENV['DB_USER'],
    password: ENV['DB_PASSWORD'],
    dbname: ENV['DB_NAME']
  ) 
end
```
シェルがbashならホームディレクトリの`.bash_profile`ファイル、zshなら`.zshenv`ファイルに以下のように記述し保存する。
```
export DB_HOST='localhost'
export DB_USER='' whoamiで表示されたuser名
export DB_PASSWORD=''
export DB_NAME='myboard' データベース名
```
