require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/cookies'
require 'pg'
require 'pry'

enable :sessions

def db
  PG::connect(
    host: ENV['DB_HOST'],
    user: ENV['DB_USER'],
    password: ENV['DB_PASSWORD'],
    dbname: ENV['DB_NAME']
  ) 
end

# 共通の処理
###########################################################################
#beforeはすべてのエンドポイントで実行する処理を記述する
before do
  #アクセスしたパスが"/","/signup","/login"以外とログインしていなければ、"/login"ページに遷移させる
  unless request.path == '/' || request.path == '/login' || request.path == '/signup' || session[:id]
    session[:notice] = {key: "danger", message: "ログインして下さい"}
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
  #フラッシュメッセージに表示させたい文字を入力する。keyはbootstrapのクラスとして使用するため、
  #メッセージのみ表示させたい場合は、session[:notice] = "登録が完了しました" だけでメッセージが表示される
  session[:notice] = {key: "success", message: "登録が完了しました"}
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
    session[:notice] = {key: "success", message: "ログインしました"} #ログイン成功時のフラッシュメッセージ
    redirect '/posts' #投稿一覧ページにリダイレクトする
  else #ユーザー情報が一致しなかった場合
    session[:notice] = {key: "danger", message: "メールアドレスかパスワードが間違っています"} #ログイン失敗時のフラッシュメッセージ
    redirect '/login' #ログインページへリダイレクトする
  end
end

# ログアウト処理
###########################################################################
get '/logout' do
  session.clear #保持しているセッション情報を削除する
  session[:notice] = {key: "danger", message: "ログアウトしました"} #ログアウト時のフラッシュメッセージ
  redirect '/' #ルートパスへリダイレクトする
end

# 投稿機能
###########################################################################
get '/posts' do
  #投稿一覧を取得する
  #投稿に紐付いているユーザーネームも取得したいため、inner joinでテーブルを結合する
  #to_charはデータ型がTIMESTAMPだと秒数まで取得して保存されるため、何時何分まで表示させるためのSQLの関数
  @posts = db.exec_params("
    select posts.id, posts.user_id, users.name, posts.title, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts
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
    #insertするカラムを以下のように指定する
    db.exec_params("insert into posts(title, content, user_id) values($1, $2, $3)",[title, content, session[:id]])
  else #画像が投稿されている場合
    image_name = params[:image][:filename] #画像のファイル名を取得し変数へ代入する
    image_data = params[:image][:tempfile] #画像データを取得し変数へ代入する
    FileUtils.mv(image_data, "./public/images/#{image_name}") #画像を移動させる処理
    #insert処理を以下のカラムのように指定する
    db.exec_params("insert into posts(title, content, image, user_id) values($1, $2, $3, $4)",[title, content, image_name, session[:id]])
  end
  session[:notice] = {key: "primary", message: "新規投稿しました"} #投稿した際のフラッシュメッセージ
  redirect '/posts' #投稿一覧ページへリダイレクトする
end

get '/posts/:id' do
  #投稿詳細ページ
  id = params[:id]
  #個別の投稿情報を取得する
  #投稿したユーザーの情報も取得したいのでinner join でテーブルを結合する
  #取得したデータは配列になっているのでfirstで一番目のデータを取得して@post変数へ代入する
  @post = db.exec_params("
    select posts.id, posts.user_id, users.name, posts.title, posts.content, posts.image, posts.created_at, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts
    inner join users on users.id = posts.user_id
    where posts.id = $1", [id]
  ).first
  #記事に対していいねされた総数をカウントして出力する
  @like_count = db.exec_params("select count(*) from likes where post_id = $1", [id]).first
  #ログインしているユーザーがいいねしているか確認する
  @liked = db.exec_params("select * from likes where user_id = $1 and post_id = $2", [session[:id], id]).first
  #投稿に対するコメントをwhereで取得し変数へ代入
  @comments = db.exec_params("
    select comments.id, comments.post_id, users.name, users.image, comments.content, to_char(comments.created_at, 'yyyy/mm/dd hh24:mm:ss') as created_at from comments
    inner join users on comments.user_id = users.id
    inner join posts on comments.post_id = posts.id
    where post_id = $1
    order by created_at desc", [id])
  erb :post
end

get '/posts/:id/edit' do
  id = params[:id]
  #新規投稿時のデータを取得し、変数へ代入
  @post = db.exec_params("select posts.*, users.name, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts inner join users on users.id = posts.user_id where posts.id = $1", [id]).first
  if session[:id] != @post['user_id'] #もし、ログインしているユーザーが投稿したデータでない場合
    session[:notice] = {key: "warning", message: "アクセス権限がありません"} #アクセス権限がないときのフラッシュメッセージ
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
  session[:notice] = {key: "success", message: "投稿を更新しました"} #投稿更新時のフラッシュメッセージ
  redirect "posts/#{id}" #更新した投稿の詳細ページへリダイレクト
end

post '/posts/:id/destroy' do
  id = params[:id]
  post = db.exec_params("select * from posts where id = $1", [id]).first #削除ボタンを押した投稿のidと一致するデータを取得
  if session[:id] != post['user_id'] #ログインしているユーザーが投稿したユーザーでない場合
    session[:notice] = {key: "warning", message: "アクセス権限がありません"} #アクセス権限がないときのフラッシュメッセージ
    redirect '/posts' #投稿一覧へリダイレクト
  else
    db.exec_params("delete from posts where id = $1", [id]) #削除処理whereで削除ボタンを押した投稿のidを指定しないとすべてのデータが削除される
    session[:notice] = {key: "danger", message: "投稿を削除しました"} #削除できたときのフラッシュメッセージ
    redirect '/posts' #投稿一覧へリダイレクト
  end
end

# コメント機能
###########################################################################
post '/comment/:id' do
  post_id = params[:post_id]
  user_id = params[:user_id]
  content = params[:content]
  db.exec_params("insert into comments(post_id, user_id, content) values($1, $2, $3)", [post_id, user_id, content])
  redirect "/posts/#{post_id}"
end

# いいね機能
###########################################################################
post '/likes' do
  user_id = session[:id]
  post_id = params[:id]
  liked = db.exec_params("select * from likes where user_id = $1 and post_id = $2", [user_id, post_id]).first 
  if liked
    db.exec_params("delete from likes where id = $1", [liked['id']])
  else
    db.exec_params("insert into likes(user_id, post_id) values($1, $2)", [user_id, post_id])
  end
  redirect "/posts/#{post_id}"
end

# ユーザー情報
###########################################################################
get '/users' do
  @users = db.exec_params("select * from users where not id = $1 order by created_at desc", [session[:id]])
  @anyfollowed = db.exec_params("select followed, count(followed) as count_followed from followers group by followed")
  @anyfollowing = db.exec_params("select following, count(following) as count_following from followers group by following")
  # binding.pry
  erb :users
end

get '/users/:id' do
  redirect 'mypage' if params['id'] == session[:id]
  id = params['id']
  @user = db.exec_params("select *, to_char(created_at, 'yyyy/mm/dd') as created_at from users where id = $1", [id]).first
  @followed = db.exec_params("select count(*) from followers where followed = $1", [id]).first
  @following = db.exec_params("select count(*) from followers where following = $1", [id]).first
  @follow = db.exec_params("select * from followers where following = $1 and followed = $2", [session[:id], id]).first
  erb :user
end

# フォロー処理
###########################################################################
post '/follow' do
  following = session[:id]
  followed = params[:id]
  to_follow = db.exec_params("select * from followers where following = $1 and followed = $2", [following, followed]).first
  if to_follow
    db.exec_params("delete from followers where id = $1", [to_follow['id']])
  else
    db.exec_params("insert into followers(following, followed) values($1, $2)", [following, followed])
  end
  redirect "/users/#{followed}"
end

# マイページ
###########################################################################
get '/mypage' do
  erb :mypage
end

get '/mypage/edit' do
  erb :mypage_edit
end

post '/mypage/update' do
  name = params[:name]
  email = params[:email]
  password = params[:password]
  birthday = params[:birthday]
  introduce = params[:introduce]
  begin
    if params[:image].nil?
      if password.empty?
        db.exec_params("update users set name = $1, email = $2, birthday = $3, introduce = $4 where id = $5", [name, email, birthday, introduce, session[:id]])
      else
        db.exec_params("update users set name = $1, email = $2, password = $3, birthday = $4, introduce = $5 where id = $6", [name, email, password, birthday, introduce, session[:id]])
      end
    else
      image_name = params[:image][:filename]
      image_data = params[:image][:tempfile]
      FileUtils.mv(image_data, "./public/images/#{image_name}")
      if password.empty?
        db.exec_params("update users set name = $1, email = $2, birthday = $3, introduce = $4, image = $5 where id = $6", [name, email, birthday, introduce, image_name, session[:id]])
      else
        db.exec_params("update users set name = $1, email = $2, password = $3 birthday = $4, introduce = $5, image = $6 where id = $7", [name, email, password, birthday, introduce, image_name, session[:id]])
      end
    end
  rescue PG::UniqueViolation
    session[:notice] = {key: "danger", message: "そのメールアドレスはすでに利用されています。"}
    redirect '/mypage/edit'
  end
  session[:notice] = {key: "success", message: "プロフィールを更新しました"}
  redirect '/mypage'
end

# 検索機能
###########################################################################
get '/search' do
  success '/posts' if params[:q].empty?
  @keywords = params[:q].split(/[[:blank:]]+/)
  # @array = []
  @results = []
  @keywords.each_with_index do |keyword|
    next if keyword == ""
    array = db.exec_params("select *, to_char(created_at, 'yyyy/mm/dd') as created_at from posts where title like $1 or content like $1", ["%#{keyword}%"])
    array.each do |a|
      @results << a
    end
  end
  @url = request.fullpath
  erb :search
end