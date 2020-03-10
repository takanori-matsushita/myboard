# require 'sinatra' #sinatraを使用するためにgemを読み込む
# require 'sinatra/reloader' #sinatraでファイルを変更・保存した際にサーバーを立ち上げ直さなくても自動でリロードしてくれる
# require 'sinatra/cookies' #クッキーを使用する
# require 'pg' #PostgreSQLに接続するためのgem
# require 'pry' #デバッグの際に使用するgem
require "bundler/setup"
Bundler.require

if development?
  require 'sinatra/reloader'
end

enable :sessions #ログイン機能を使用するにはセッションを有効にしなければいけない

  def db #データベースへの接続の設定
    PG::connect(
      host: ENV['DB_HOST'],
      port: ENV['DB_PORT'],
      user: ENV['DB_USER'],
      password: ENV['DB_PASSWORD'],
      dbname: ENV['DB_NAME']
    ) 
  end

# 共通の処理
###########################################################################
#beforeはすべてのエンドポイントで実行する処理を記述する
before do
  #アクセスしたパスが"/"もしくは、"/signup"もしくは、"/login"もしくは、ログインしていなければ、"/login"ページに遷移させる
  unless request.path == '/' || request.path == '/login' || request.path == '/signup' || session[:id]
    session[:notice] = {class: "danger", message: "ログインして下さい"}
    redirect '/login'
  end
  #ログインしているユーザーの情報を取得する
  @admin = db.exec_params("select *, to_char(created_at, 'yyyy/mm/dd') as created_at from users where id = $1",[session[:id]]).first
  #フラッシュメッセージを表示させる
  @message = session.delete :notice
end

get '/' do
  erb :index
end

# サインアップ処理
###########################################################################
get '/signup' do
  erb :signup
end

post '/signup' do
  #signup.erbのフォームのinputタグのnameと一致する値をそれぞれ取得する
  name = params[:name]
  email = params[:email]
  password = params[:password]
  #入力された値をデータベースに保存する。PostgreSQLではreturningを書くことで実行したSQLのデータを返してくれる
  user = db.exec_params("insert into users(name, email, password) values($1, $2, $3) returning id",[name, email, password]).first
  #サインアップと同時にログイン処理を行う
  session[:id] = user['id']
  #フラッシュメッセージに表示させたい文字を入力する。classはbootstrapのクラスとして使用するため、
  #メッセージのみ表示させたい場合は、session[:notice] = "登録が完了しました" だけでメッセージが表示される
  session[:notice] = {class: "success", message: "登録が完了しました"}
  #登録処理が終わったので"/posts"へリダイレクトする
  redirect '/posts'
end

# ログイン処理
###########################################################################
get '/login' do
  #ログインしている場合は、ログインフォームにアクセスさせない
  #session[:id]があるときのみ実行される
  redirect '/posts' if session[:id]
  erb :login
end

post '/login' do
  #login.erbファイルのフォームのinputタグのnameと一致する値をそれぞれ取得する
  email = params[:email]
  password = params[:password]
  #入力されたemailとpasswordがデータベースに登録されている情報と一致するか照合し、user変数へ代入する
  user = db.exec_params("select * from users where email = $1 and password = $2",[email, password]).first
  if user #もしユーザー情報が一致した場合
    session[:id] = user['id'] #セッションにユーザーIDを代入する
    session[:notice] = {class: "success", message: "ログインしました"} #ログイン成功時のフラッシュメッセージ
    redirect '/posts' #投稿一覧ページにリダイレクトする
  else #ユーザー情報が一致しなかった場合
    session[:notice] = {class: "danger", message: "メールアドレスかパスワードが間違っています"} #ログイン失敗時のフラッシュメッセージ
    redirect '/login' #ログインページへリダイレクトする
  end
end

# ログアウト処理
###########################################################################
get '/logout' do
  session.clear #保持しているセッション情報を削除する
  session[:notice] = {class: "danger", message: "ログアウトしました"} #ログアウト時のフラッシュメッセージ
  redirect '/' #ルートパスへリダイレクトする
end

# 投稿機能
###########################################################################
get '/posts' do
  #投稿一覧を取得する
  #投稿に紐付いているユーザー名も取得したいため、inner joinでテーブルを結合する
  #to_charはデータ型がTIMESTAMPだと秒数まで取得して保存されるため、何時何分まで表示させるためのSQLの関数
  @posts = db.exec_params("
    select posts.id, posts.user_id, users.name, posts.title, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at
    from posts
    inner join users on users.id = posts.user_id
    order by updated_at desc
  ")
  erb :posts
end

get '/posts/new' do
  erb :post_new
end

post '/posts/create' do
  #posts_new.erbのフォームのinputタグのnameと一致する値をそれぞれ取得する
  title = params[:title]
  content = params[:content]
  if params[:image].nil? #もし画像が投稿されていない場合
    #insert処理を以下のカラムのように指定する
    db.exec_params("insert into posts(title, content, user_id) values($1, $2, $3)",[title, content, session[:id]])
  else #画像が投稿されている場合
    image_name = params[:image][:filename] #画像のファイル名を取得し変数へ代入する
    image_data = params[:image][:tempfile] #画像データを取得し変数へ代入する
    FileUtils.mv(image_data, "./public/images/#{image_name}") #画像を移動させる処理
    #insert処理を以下のカラムのように指定する
    db.exec_params("insert into posts(title, content, image, user_id) values($1, $2, $3, $4)",[title, content, image_name, session[:id]])
  end
  session[:notice] = {class: "primary", message: "新規投稿しました"} #投稿した際のフラッシュメッセージ
  redirect '/posts' #投稿一覧ページへリダイレクトする
end

get '/posts/:id' do
  #投稿詳細ページ
  id = params[:id]
  #個別の投稿情報を取得する。投稿したユーザーの情報も取得したいのでinner join でテーブルを結合する
  #取得したデータは配列になっているのでfirstで一番目のデータを取得して変数へ代入する to_charは100行目付近の説明を参照
  @post = db.exec_params("
    select posts.id, posts.user_id, users.name, posts.title, posts.content, posts.image, posts.created_at, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts
    inner join users on users.id = posts.user_id
    where posts.id = $1", [id]
  ).first
  #記事に対していいねされた総数をカウントして出力する
  @like_count = db.exec_params("select count(*) from likes where post_id = $1", [id]).first
  #ログインしているユーザーがいいねしているか確認する
  @liked = db.exec_params("select * from likes where user_id = $1 and post_id = $2", [session[:id], id]).first
  #投稿に対するコメントをwhereで取得し変数へ代入、to_charは100行目付近の説明を参照
  @comments = db.exec_params("
    select comments.id, comments.post_id, users.name, users.image, comments.content, to_char(comments.created_at, 'yyyy/mm/dd hh24:mm:ss') as created_at from comments
    inner join users on comments.user_id = users.id
    inner join posts on comments.post_id = posts.id
    where post_id = $1 --投稿に紐付いているコメントだけをしていする
    order by created_at desc", [id]) #orderを使って投稿日時を降順に並び替える
  erb :post
end
  
get '/posts/:id/edit' do
  id = params[:id]
  #新規投稿時のデータを取得し、変数へ代入 to_charは100行目付近の説明を参照
  @post = db.exec_params("
    select posts.*, users.name, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts
    inner join users on users.id = posts.user_id
    where posts.id = $1", [id]).first
  if session[:id] != @post['user_id'] #もし、ログインしているユーザーが投稿したデータでない場合
    session[:notice] = {class: "warning", message: "アクセス権限がありません"} #アクセス権限がないときのフラッシュメッセージ
    redirect '/posts' #投稿一覧にリダイレクトする
  end
  erb :post_edit
end
    
post '/posts/:id/update' do
  #post_edit.erbのフォームのinputタグのnameと一致する値をそれぞれ取得する
  id = params[:id]
  title = params[:title]
  content = params[:content]
  if params[:image].nil? #画像が投稿されていない場合
    db.exec_params("update posts set title = $1, content = $2 where id = $3", [title, content, id]) #任意のカラムを更新する
  else #画像が投稿されている場合画像をアップロードする処理を記述
    image_name = params[:image][:filename]
    image_data = params[:image][:tempfile]
    FileUtils.mv(image_data, "./public/images/#{image_name}")
    db.exec_params("update posts set title = $1, content = $2, image = $3 where id = $4", [title, content, image_name, id]) #任意のカラムを更新する
  end
  session[:notice] = {class: "success", message: "投稿を更新しました"} #投稿更新時のフラッシュメッセージ
  redirect "posts/#{id}" #更新した投稿の詳細ページへリダイレクト
end
    
post '/posts/:id/destroy' do
  id = params[:id]
  post = db.exec_params("select * from posts where id = $1", [id]).first #削除ボタンを押した投稿のidと一致するデータを取得
  if session[:id] != post['user_id'] #ログインしているユーザーが投稿したユーザーでない場合
    session[:notice] = {class: "warning", message: "アクセス権限がありません"} #アクセス権限がないときのフラッシュメッセージ
    redirect '/posts' #投稿一覧へリダイレクト
  else
    db.exec_params("delete from posts where id = $1", [id]) #削除処理whereで削除ボタンを押した投稿のidを指定しないとすべてのデータが削除される
    session[:notice] = {class: "danger", message: "投稿を削除しました"} #削除できたときのフラッシュメッセージ
    redirect '/posts' #投稿一覧へリダイレクト
  end
end

# コメント機能
###########################################################################
post '/comment/:id' do
  #post.erbのフォームのinputタグのnameと一致する値をそれぞれ取得する
  post_id = params[:post_id]
  user_id = params[:user_id]
  content = params[:content]
  db.exec_params("insert into comments(post_id, user_id, content) values($1, $2, $3)", [post_id, user_id, content])
  redirect "/posts/#{post_id}" #コメントした投稿の記事へリダイレクトする
end

# いいね機能
###########################################################################
post '/likes/:id' do
  user_id = session[:id] #いいねボタンを押したユーザー（ログイン中のユーザー）のid
  post_id = params[:id] #記事のid
  #投稿に対してログイン中のユーザーがいいねしているか探す
  liked = db.exec_params("select * from likes where user_id = $1 and post_id = $2", [user_id, post_id]).first 
  if liked #いいねしていた場合
    db.exec_params("delete from likes where id = $1", [liked['id']]) #いいねを削除する
  else #いいねしていなかった場合
    db.exec_params("insert into likes(user_id, post_id) values($1, $2)", [user_id, post_id]) #いいねを登録する
  end
  redirect "/posts/#{post_id}" #いいねした投稿の詳細へリダイレクト
end

# ユーザー情報
###########################################################################
get '/users' do #ユーザー一覧ページ
  #usersテーブルにフォロー・フォロワーをカウントした数を結合し、ログイン中のユーザー以外を表示
  @users = db.exec_params("
    select users.*, c_followers.followed_count, c_followers.following_count from users
    inner join (
      select users.id as user_id, count(f1.followed) as followed_count, f2.following_count from users
      left outer join followers f1 on users.id = f1.followed
      left outer join (
        select users.id as user_id, count(followers.following) as following_count from users
        left outer join followers on users.id = followers.following
        group by users.id
        order by users.id
      ) as f2 on users.id = f2.user_id
      group by users.id, f2.following_count
    ) as c_followers on users.id = c_followers.user_id
    where not id = $1
    order by created_at desc", [session[:id]])
  erb :users
end

get '/users/:id' do
  redirect 'mypage' if params['id'] == session[:id] # ログインしているユーザーがユーザー詳細ページへアクセスしようとしたらマイページへリダイレクトする
  id = params['id']
  #アクセスしたユーザーの詳細情報取得 to_charは100行目付近の説明を参照
  @user = db.exec_params("
    select users.id, users.name, users.image, users.introduce, users.birthday, to_char(users.created_at, 'yyyy/mm/dd') as created_at
    from users where id = $1", [id]).first
  #ユーザーに紐付いている投稿データを取得
  @posts = db.exec_params("
    select title, content, image, to_char(created_at, 'yyyy/mm/dd') as created_at,to_char(updated_at, 'yyyy/mm/dd') as updated_at
    from posts where user_id = $1
    order by updated_at desc", [id]) #更新日時を降順で並び替える
  @followed = db.exec_params("select count(*) from followers where followed = $1", [id]).first #フォロワーの総数
  @following = db.exec_params("select count(*) from followers where following = $1", [id]).first #フォロー中の総数
  #ログイン中のユーザーが詳細ページのユーザーをフォローしているか取得
  #フォローしていた場合はデータが取得でき、フォローしていない場合はnilが返される
  @follow = db.exec_params("select * from followers where following = $1 and followed = $2", [session[:id], id]).first
  erb :user
end

# フォロー処理
###########################################################################
post '/follow/:id' do
  following = session[:id] #フォローボタンを押したユーザー（ログイン中のユーザー）のid
  followed = params[:id] #フォローボタンを押されたユーザーのid
  #フォロー・フォロワー関係のデータを取得
  #フォロー・フォロワー関係にあればデータが取得でき、ない場合はnilが返される
  to_follow = db.exec_params("select * from followers where following = $1 and followed = $2", [following, followed]).first
  if to_follow #もしフォロー・フォロワー関係ならフォローを解除する
    db.exec_params("delete from followers where id = $1", [to_follow['id']])
  else #フォロー・フォロワー関係でなければフォローする
    db.exec_params("insert into followers(following, followed) values($1, $2)", [following, followed])
  end
  redirect "/users/#{followed}" #フォローしたユーザーのページへリダイレクトする
end

# マイページ
###########################################################################
get '/mypage' do
  #ユーザーに紐付いている投稿データを取得
  @posts = db.exec_params("
    select title, content, image, to_char(created_at, 'yyyy/mm/dd') as created_at,to_char(updated_at, 'yyyy/mm/dd') as updated_at
    from posts where user_id = $1
    order by updated_at desc", [session[:id]]) #更新日時を降順で並び替える
  erb :mypage
end
#この2つのエンドポイントはbeforeメソッドでユーザー情報を取得する処理を記述しているため、
#処理がなくてもユーザーデータを取得できる
get '/mypage/edit' do
  erb :mypage_edit
end
###########################################################################
post '/mypage/update' do
  #mypage_edit.erbのフォームのinputタグのnameと一致する値をそれぞれ取得する
  name = params[:name]
  email = params[:email]
  password = params[:password]
  birthday = params[:birthday]
  introduce = params[:introduce]
  begin #以下の処理を実行してエラーが帰ってくるようであればrescueで例外処理をする
    if params[:image].nil? #もしプロフィール画像がアップロードされていない場合
      if password.empty? #かつパスワードも入力されていない場合、imageカラムとpasswordカラム以外の値を更新する
        db.exec_params("update users set name = $1, email = $2, birthday = $3, introduce = $4 where id = $5", [name, email, birthday, introduce, session[:id]])
      else #パスワードが入力されていた場合、imageカラム以外の値を更新する
        db.exec_params("update users set name = $1, email = $2, password = $3, birthday = $4, introduce = $5 where id = $6", [name, email, password, birthday, introduce, session[:id]])
      end
    else #プロフィール画像がアップロードされた場合
      image_name = params[:image][:filename]
      image_data = params[:image][:tempfile]
      FileUtils.mv(image_data, "./public/images/#{image_name}") #画像アップロードの処理
      if password.empty? #かつパスワードが入力されていない場合、passwordカラム以外の値を更新する
        db.exec_params("update users set name = $1, email = $2, birthday = $3, introduce = $4, image = $5 where id = $6", [name, email, birthday, introduce, image_name, session[:id]])
      else #かつパスワードが入力されている場合、すべてのカラムの値を更新する
        db.exec_params("update users set name = $1, email = $2, password = $3 birthday = $4, introduce = $5, image = $6 where id = $7", [name, email, password, birthday, introduce, image_name, session[:id]])
      end
    end
  rescue PG::UniqueViolation #例外処理 emailにuniqueを設定しているため、PG::UniqueViolationというエラーが表示されるが、例外処理を記述することで、エラーに対する処理を実行できる
    session[:notice] = {class: "danger", message: "そのメールアドレスはすでに利用されています。"} #メールアドレスが重複している際のフラッシュメッセージ
    redirect '/mypage/edit' #マイページの編集ページへリダイレクト
  end
  session[:notice] = {class: "success", message: "プロフィールを更新しました"} #データを更新できた際のフラッシュメッセージ
  redirect '/mypage'
end

# 検索機能
###########################################################################
get '/search' do
  success '/posts' if params[:q].empty? #検索キーワードが入力されていない場合、投稿一覧へリダイレクト
  @keywords = params[:q].split(/[[:blank:]]+/) #キーワードが空白で複数入力されている場合、空白で区切って配列に変換し、変数へ代入する 空白の判定は正規表現で実装
  @results = [] #以下の処理で使用するための配列を用意
  @keywords.each_with_index do |keyword| #複数のキーワードで検索するため、キーワードをeachで回して処理を行う
    next if keyword == "" #配列の一番最初が空白だった場合、次の配列の処理に移る。空白だった場合も空のデータとして取れてしまうため
    #以下の行で入力されたキーワードを検索
    array = db.exec_params("
      select *, to_char(created_at, 'yyyy/mm/dd') as created_at
      from posts
      where title like $1 or content like $1", ["%#{keyword}%"])
    array.each do |a| #上記で検索結果が配列で帰ってくるため更にeachでヒットしたデータを順番に取り出す
      #eachの中の変数はスコープとなり外からは見れないが、@をつけることでグローバル変数となり、外からでも参照することができる
      #そのため、一度eachの外で@resultsを用意する必要がある
      @results << a #@results変数に検索結果を追加する
    end
  end
  @url = request.fullpath #"/search"のフルパスを取得し、変数へ代入 search.erbで条件分岐として使用する
  erb :search
end