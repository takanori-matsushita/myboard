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

get '/' do
  @posts = db.exec_params("select posts.id, users.name, posts.title, posts.content from posts join users on users.id = posts.user_id")
  erb :index
end

get '/signup' do
  erb :signup
end

post '/signup' do
  name = params[:name]
  email = params[:email]
  password = params[:password]
  db.exec_params("insert into users(name, email, password) values($1, $2, $3)",[name, email, password])
  user = db.exec_params("select * from users where email = $1 and password = $2",[email, password])
  session[:id] = user[0]['id']
  redirect '/form'
end

get '/login' do
  erb :login
end

post '/login' do
  email = params[:email]
  password = params[:password]
  user = db.exec_params("select * from users where email = $1 and password = $2",[email, password])
  session[:id] = user[0]['id']
  redirect '/form'
end

get '/logout' do
  session.clear
  redirect '/login'
end

get '/form' do
  redirect '/login' unless session[:id]
  @user = db.exec_params("select * from users where id = $1",[session[:id]])
  erb :form
end

post '/posts' do
  title = params[:title]
  content = params[:content]
  db.exec_params("insert into posts(title, content, user_id) values($1, $2, $3)",[title, content, session[:id]])
  redirect '/'
end