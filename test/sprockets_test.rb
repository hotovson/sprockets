require "minitest/autorun"
require "sprockets"
require "fileutils"

require "coffee_script"
require "eco"
require "ejs"
require "erb"

old_verbose, $VERBOSE = $VERBOSE, false
Encoding.default_external = 'UTF-8'
Encoding.default_internal = 'UTF-8'
$VERBOSE = old_verbose

def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, false
  yield
ensure
  $VERBOSE = old_verbose
end

# Popular extensions for testing but not part of Sprockets core

NoopProcessor = proc { |input| input[:data] }
Sprockets.register_mime_type 'text/haml', extensions: ['.haml']
Sprockets.register_engine '.haml', NoopProcessor, mime_type: 'text/html'

Sprockets.register_mime_type 'text/ng-template', extensions: ['.ngt']
AngularProcessor = proc { |input|
  <<-EOS
$app.run(function($templateCache) {
  $templateCache.put('#{input[:name]}.html', #{input[:data].chomp.inspect});
});
  EOS
}
Sprockets.register_engine '.ngt', AngularProcessor, mime_type: 'application/javascript'

Sprockets.register_mime_type 'text/mustache', extensions: ['.mustache']
Sprockets.register_engine '.mustache', NoopProcessor, mime_type: 'application/javascript'

Sprockets.register_mime_type 'text/x-handlebars-template', extensions: ['.handlebars']
Sprockets.register_engine '.handlebars', NoopProcessor, mime_type: 'application/javascript'

Sprockets.register_mime_type 'application/javascript-module', extensions: ['.es6']
Sprockets.register_engine '.es6', NoopProcessor, mime_type: 'application/javascript'

Sprockets.register_mime_type 'application/dart', extensions: ['.dart']
Sprockets.register_engine '.dart', NoopProcessor, mime_type: 'application/javascript'

require 'nokogiri'
Sprockets.register_mime_type 'application/ruby+builder', extensions: ['.builder']

HtmlBuilderProcessor = proc { |input|
  instance_eval <<-EOS
    builder = Nokogiri::HTML::Builder.new do |doc|
      #{input[:data]}
    end
    builder.to_html
  EOS
}
Sprockets.register_engine '.builder', HtmlBuilderProcessor, mime_type: 'text/html'

XmlBuilderProcessor = proc { |input|
  instance_eval <<-EOS
    builder = Nokogiri::XML::Builder.new do |xml|
      #{input[:data]}
    end
    builder.to_xml
  EOS
}
# Sprockets.register_engine '.builder', XmlBuilderProcessor, mime_type: 'application/xml'

Sprockets.register_engine '.jst2', Sprockets::JstProcessor.new(namespace: 'this.JST2'), mime_type: 'application/javascript'


class Sprockets::TestCase < MiniTest::Test
  FIXTURE_ROOT = File.expand_path(File.join(File.dirname(__FILE__), "fixtures"))

  def self.test(name, &block)
    define_method("test_#{name.inspect}", &block)
  end

  def fixture(path)
    IO.read(fixture_path(path))
  end

  def fixture_path(path)
    if path.match(FIXTURE_ROOT)
      path
    else
      File.join(FIXTURE_ROOT, path)
    end
  end

  def sandbox(*paths)
    backup_paths = paths.select { |path| File.exist?(path) }
    remove_paths = paths.select { |path| !File.exist?(path) }

    begin
      backup_paths.each do |path|
        FileUtils.cp(path, "#{path}.orig")
      end

      yield
    ensure
      backup_paths.each do |path|
        if File.exist?("#{path}.orig")
          FileUtils.mv("#{path}.orig", path)
        end

        assert !File.exist?("#{path}.orig")
      end

      remove_paths.each do |path|
        if File.exist?(path)
          FileUtils.rm_rf(path)
        end

        assert !File.exist?(path)
      end
    end
  end
end
