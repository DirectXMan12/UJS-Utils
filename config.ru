require 'json'

module Rack
	class DefaultPage < Directory
		def default_pg_path
			return @default_pg_path
		end
		def default_pg_path=(p)
			unless (path =~ /^\//)
				@default_pg_path = '/'+p
			else
				@default_pg_path = p
			end
		end	
		
		def initialize(root, default_path)
			@default_pg_path = '[default]'
			self.default_pg_path = default_path
			super(root)
		end

		def call(env)
			path = Utils.unescape(env['PATH_INFO'])
			
			if (path == '/' || path == '')
				raise('argh!') if default_pg_path.nil?
				env['PATH_INFO'] = self.default_pg_path
			end
			super(env)
		end
	end

	class UJSServer < DefaultPage
		attr_accessor :body

		def call(env)
			@body = 'default'
			unless self.catch_url? env
				super(env)
			else
				self.switch_paths env
			end
		end

		def each
			raise 'art thou a spirit, for thou hast no body!?!' if (self.body.nil? || self.body == 'default')
			yield self.body
		end

		def catch_url?(env)
			path = Utils.unescape(env['PATH_INFO'])
			
			(path =~ /\/script_response/ || path =~ /\/json_response/)
		end

		def switch_paths(env)
			path = Utils.unescape(env['PATH_INFO'])

			case path
				when '/script_response'
					self.body = "alert('hi');"
					return [200, {"Content-Type" => 'text/javascript', "Content-Length" => self.body.length.to_s}, self]
				when '/json_response'
					self.body = ::JSON.generate({:test => 32}) 
					return [200, {'Content-Type' => 'application/json', 'Content-Length' => self.body.length.to_s}, self]
			end	
		end
	end

	class PathSub
		def initialize(app)
			@app = app
		end

		def call(env)
			status, headers, @response = @app.call(env)
			@env = env
			headers.delete 'Content-Length'
			[status, headers, self]
		end

		def each
			@response.each do |p|
				yield p.gsub('$path', 'http://'+@env['HTTP_HOST'])
			end
		end
	end

	class TextResponse
		attr_accessor :content_type
		attr_accessor :response

		def initialize(entered_opts={:content_type => 'text/plain', :response => 'hi'})
			opts = ({:content_type => 'text/plain', :response => 'hi'}).merge(entered_opts)
		 	
			self.content_type = opts[:content_type]
			self.response = opts[:response]
		end

		def call(env)
			@env = env
			return [200, {'Content-Type' => self.content_type}, self]
		end

		def each
			if self.response.is_a?(Proc)
				yield self.response.call(@env, Request.new(@env))
			elsif self.response.respond_to?(:to_s)
				yield self.response
			else
				raise 'what??'
			end
		end

	end
end


use Rack::PathSub
use Rack::ContentLength

root = Dir.pwd

js_resp = Rack::TextResponse.new :content_type => 'text/javascript', :response => Proc.new { |env, req|
																																										unless(req.params.length != 0)
																																											"alert('hi');"
																																										else
																																											"alert('You typed #{req.params.to_a[0][1]}!');"
																																										end	
																																									}

json_resp = Rack::TextResponse.new :content_type => 'application/json', :response => ::JSON.generate({:test => 32})

main_app = Rack::DefaultPage.new(root, 'test_page.html')


map = {'/script_response' => js_resp, '/json_response' => json_resp, '/' => main_app}

app = Rack::URLMap.new map
	
	

run app

