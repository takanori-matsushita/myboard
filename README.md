# 簡易掲示板
CODEBASE受講生向けの簡易掲示板サンプル
 
## データベース構築
動作の確認をしたい方は、以下のSQL文を実行して下さい。
```
CREATE DATABASE myboard;
```
```
CREATE TABLE users(
  id SERIAL NOT NULL PRIMARY KEY,
  name VARCHAR(20) NOT NULL,
  email VARCHAR(50) NOT NULL,
  password VARCHAR(20) NOT NULL,
  image VARCHAR(20) DEFAULT '/images/no-image.jpg',
  introduce VARCHAR(20) DEFAULT 'よろしくお願いします。',
  birthday DATE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
)
```
```
CREATE TABLE posts(
  id SERIAL NOT NULL PRIMARY KEY,
  title VARCHAR(20) NOT NULL,
  content VARCHAR(255) NOT NULL,
  image VARCHAR(50),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
)
```
```
CREATE TABLE follower(
  id SERIAL NOT NULL PRIMARY KEY,
  following INTEGER NOT NULL,
  followed INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
)
```

## 環境変数について
 
### 環境変数とは？
環境変数とはそのシェルの環境のみで扱うことができる変数です。
例えばapp.rbファイルにそのまま情報を書き込んでgit等で管理すると、悪意のある第三者に利用される危険性があります。
 
### 環境変数の設定方法
シェルがbashならホームディレクトリの.bash_profile、zshなら.zshenvファイルに以下のように記述し保存して下さい。
export DB_HOST='localhost'
export DB_USER='' whoamiで表示されたuser名
export DB_PASSWORD=''
export DB_NAME='myboard' データベース名
