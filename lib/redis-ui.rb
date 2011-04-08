require 'rubygems'
require 'sinatra/base'
require 'redis'
require 'json'

module RedisUI
  
  def self.redis
    Redis.new
  end
  
  class Server < Sinatra::Base
        
    before do
      #content_type :json if request.xhr?
    end
    
    configure do
      set :views, File.dirname(__FILE__) + '/views'
      set :redis, RedisUI.redis
      set :public, File.dirname(__FILE__) + '/public'
      mime_type :json, "application/json"
    end  
      
    helpers do 
      include Rack::Utils
      alias_method :h, :escape_html
      
      def redis
        RedisUI.redis
      end
      
      def redis_value(key, cursor = 0, per = 100)
        case RedisUI.redis.type(key)
        when 'string'
          [RedisUI.redis.get(key)]
        when 'list'
          RedisUI.redis.lrange(key, cursor, cursor + per)
        when 'set'
          RedisUI.redis.smembers(key)[cursor..(cursor + per)]
        when 'zset'
          RedisUI.redis.zrange(key, cursor, cursor + per)
        end
      end
      
      def redis_size(key)
        case RedisUI.redis.type(key)
        when 'string'
          RedisUI.redis.get(key).length
        when 'list'
          RedisUI.redis.llen(key)
        when 'set'
          RedisUI.redis.scard(key)
        when 'zset'
          RedisUI.redis.zcard(key)
        end
      end
      
    end
    
    # render view based on page name
    # on redis error show error template w/ no layout
    def show(page, layout = true)
      begin
        erb page.to_sym, {:layout => layout}
      rescue Errno::ECONNREFUSED
        erb :error, {:layout => false}, :error => "Redis?"
      end
    end
    
    def respond_with(data = [], template = :index)
      #if request.xhr?
      #  data.to_json
      #else
        erb template, {:layout => true}
      #end
    end
    
    # index
    get "/" do
      match = params[:match] || '*'
      @keys = RedisUI.redis.keys(match)
      respond_with @keys, :index
    end
    
    # show
    get "/:key" do
      @key = params[:key]
      respond_with @key, :show
    end
    
    # set
    post "/:key" do
      body = params[:body] || ""
      RedisUI.redis.set params[:key], body
    end

  end
end