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

	class NoHTTPCache
		def initialize(app)
			@app = app
		end

		def call(env)
			status, headers, @body = @app.call(env)
			headers.delete('Content-Length')
			[status, headers, self]
		end

		def each
			@body.each do |p|
				new_p = p
				loc = (p =~ /\.js/)
				unless loc.nil?
					new_p[loc+1..loc+6] = "?v=#{rand(999)}"
				end
				yield new_p
			end
		end

	end
end


use Rack::PathSub
use Rack::NoHTTPCache
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

