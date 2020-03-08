require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/cookies'
require 'pg'
require 'pry'

enable :sessions

def db
  PG::connect(
    :host => ENV['DB_HOST'],
    :user => ENV['DB_USER'],
    :password => ENV['DB_PASSWORD'],
    :dbname => ENV['DB_NAME']
  ) 
end

# 共通の処理
###########################################################################
before do
  unless request.path == '/login' || request.path == '/signup' || session[:id]
    session[:notice] = {key: "danger", message: "ログインして下さい"}
    redirect '/login'
  end
  @admin = db.exec_params("select *, to_char(created_at, 'yyyy/mm/dd') as created_at from users where id = $1",[session[:id]]).first
  @message = session.delete :notice
end

# サインアップ処理
###########################################################################
get '/signup' do
  erb :signup
end

post '/signup' do
  name = params[:name]
  email = params[:email]
  password = params[:password]
  user = db.exec_params("insert into users(name, email, password) values($1, $2, $3) returning id",[name, email, password]).first
  session[:id] = user['id']
  session[:notice] = {key: "success", message: "登録が完了しました"}
  redirect '/posts'
end

# ログイン処理
###########################################################################
get '/login' do
  erb :login
end

post '/login' do
  email = params[:email]
  password = params[:password]
  user = db.exec_params("select * from users where email = $1 and password = $2",[email, password]).first
  if user
    session[:id] = user['id']
    session[:notice] = {key: "success", message: "ログインしました"}
    redirect '/posts'
  else
    session[:notice] = {key: "danger", message: "メールアドレスかパスワードが間違っています"}
    redirect '/login'
  end
end

# ログアウト処理
###########################################################################
get '/logout' do
  session.clear
  session[:notice] = {key: "danger", message: "ログアウトしました"}
  redirect '/login'
end

# 投稿機能
###########################################################################
get '/posts' do
  @posts = db.exec_params("select posts.*, users.name, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts join users on users.id = posts.user_id")
  erb :posts
end

get '/posts/new' do
  erb :post_new
end

post '/posts/create' do
  title = params[:title]
  content = params[:content]
  if params[:image].nil?
    db.exec_params("insert into posts(title, content, user_id) values($1, $2, $3)",[title, content, session[:id]])
  else
    image_name = params[:image][:filename]
    image_data = params[:image][:tempfile]
    FileUtils.mv(image_data, "./public/images/#{image_name}")
    db.exec_params("insert into posts(title, content, image, user_id) values($1, $2, $3, $4)",[title, content, image_name, session[:id]])
  end
  session[:notice] = {key: "primary", message: "新規投稿しました"}
  redirect '/posts'
end

get '/posts/:id' do
  id = params[:id]
  @post = db.exec_params("select posts.*, users.name, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts join users on users.id = posts.user_id where posts.id = $1", [id]).first
  @like = db.exec_params("select count(*) from likes where post_id = $1", [id]).first
  @liked = db.exec_params("select * from likes where user_id = $1", [session[:id]]).first
  erb :post
end

get '/posts/:id/edit' do
  id = params[:id]
  @post = db.exec_params("select posts.*, users.name, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts join users on users.id = posts.user_id where posts.id = $1", [id]).first
  if session[:id] != @post['user_id']
    session[:notice] = {key: "warning", message: "アクセス権限がありません"}
    redirect '/posts' 
  end
  erb :post_edit
end

post '/posts/:id/update' do
  id = params[:id]
  title = params[:title]
  content = params[:content]
  if params[:image].nil?
    db.exec_params("update posts set title = $1, content = $2 where id = $3", [title, content, id])
  else
    image_name = params[:image][:filename]
    image_data = params[:image][:tempfile]
    FileUtils.mv(image_data, "./public/images/#{image_name}")
    db.exec_params("update posts set title = $1, content = $2, image = $3 where id = $4", [title, content, image_name, id])
  end
  session[:notice] = {key: "success", message: "投稿を更新しました"}
  redirect "posts/#{id}"
end

get '/posts/:id/destroy' do
  id = params[:id]
  @post = db.exec_params("select * from posts where id = $1", [id]).first
  if session[:id] != @post['user_id']
    session[:notice] = {key: "warning", message: "アクセス権限がありません"}
    redirect '/posts' 
  end
  db.exec_params("delete from posts where id = $1", [id])
  session[:notice] = {key: "danger", message: "投稿を削除しました"}
  redirect '/posts'
end

# いいね機能
###########################################################################
post '/likes' do
  user_id = session[:id]
  post_id = params[:id]
  like = db.exec_params("select * from likes where user_id = $1 and post_id = $2", [user_id, post_id]).first 
  if like
    db.exec_params("delete from likes where id = $1", [like['id']])
  else
    db.exec_params("insert into likes(user_id, post_id) values($1, $2)", [user_id, post_id])
  end
  redirect "/posts/#{post_id}"
end

# ユーザー情報
###########################################################################
get '/users' do
  @users = db.exec_params("select * from users where not id = $1", [session[:id]])
  erb :users
end

get '/users/:id' do
  redirect 'mypage' if params['id'] == session[:id]
  id = params['id']
  @user = db.exec_params("select *, to_char(created_at, 'yyyy/mm/dd') as created_at from users where id = $1", [id]).first
  erb :user
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
  @searches = []
  @keywords.each_with_index do |keyword, i|
    next if keyword == ""
    @searches[i] = db.exec_params("select *, to_char(created_at, 'yyyy/mm/dd') as created_at from posts where title like $1 or content like $1", ["%#{keyword}%"])
  end
  @url = request.fullpath
  erb :search
end