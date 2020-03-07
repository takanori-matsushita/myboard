require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/cookies'
require 'pg'
require 'pry'

enable :sessions

def db
  PG::connect(
    :host => "localhost",
    :user => 'matsushitatakanori', 
    :password => '',
    :dbname => "myboard")  
  end
  
  before do
    unless request.path == '/login' || request.path == '/signup' || session[:id]
      session[:notice] = {key: "danger", message: "ログインして下さい"}
      redirect '/login'
    end
    @user = db.exec_params("select * from users where id = $1",[session[:id]]).first
    @message = session.delete :notice
  end
  
  before '/edit/*' do
    
  end
  
  get '/signup' do
    erb :signup
  end
  
  post '/signup' do
    name = params[:name]
    email = params[:email]
    password = params[:password]
    db.exec_params("insert into users(name, email, password) values($1, $2, $3)",[name, email, password])
    user = db.exec_params("select * from users where email = $1 and password = $2",[email, password]).first
    session[:id] = user['id']
    redirect '/posts'
  end
  
  get '/login' do
    erb :login
  end
  
  post '/login' do
    email = params[:email]
    password = params[:password]
    user = db.exec_params("select * from users where email = $1 and password = $2",[email, password]).first
    session[:id] = user['id']
    session[:notice] = {key: "success", message: "ログインしました"}
    redirect '/posts'
  end
  
  get '/logout' do
    session.clear
    redirect '/login'
  end
  
  get '/posts' do
    @posts = db.exec_params("select posts.*, users.name, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts join users on users.id = posts.user_id")
    erb :posts
  end
  
  get '/posts/new' do
    erb :post_new
  end
  
  post '/create' do
    title = params[:title]
    content = params[:content]
    if params[:image]
      image_name = params[:image][:filename]
      image_data = params[:image][:tempfile]
      FileUtils.mv(image_data, "./public/images/#{image_name}")
      db.exec_params("insert into posts(title, content, image, user_id) values($1, $2, $3, $4)",[title, content, image_name, session[:id]])
    else
      db.exec_params("insert into posts(title, content, user_id) values($1, $2, $3, $4)",[title, content, session[:id]])
    end
    session[:notice] = {key: "primary", message: "新規投稿しました"}
    redirect '/posts'
  end
  
  get '/posts/:id' do
    id = params[:id]
    @post = db.exec_params("select posts.*, users.name, to_char(posts.updated_at, 'yyyy/mm/dd hh24:mm:ss') as updated_at from posts join users on users.id = posts.user_id where posts.id = $1", [id]).first
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
    if params[:image]
      image_name = params[:image][:filename]
      image_data = params[:image][:tempfile]
      FileUtils.mv(image_data, "./public/images/#{image_name}")
      db.exec_params("update posts set title = $1, content = $2, image = $3 where id = $4", [title, content, image_name, id])
    else
      db.exec_params("update posts set title = $1, content = $2 where id = $3", [title, content, id])
    end
    session[:notice] = {key: "success", message: "投稿を更新しました"}
    redirect "posts/#{id}"
  end
  
  get '/posts/:id/destroy' do
    id = params[:id]
    db.exec_params("delete from posts where id = $1", [id])
    session[:notice] = {key: "danger", message: "投稿を削除しました"}
    redirect '/posts'
  end
  
  get '/users' do
    @users = db.exec_params("select * from users")
    erb :users
  end
  
  get '/users/:id' do
    id = params['id']
    @user = db.exec_params("select * from users where id = $1", [id]).first
    erb :user
  end