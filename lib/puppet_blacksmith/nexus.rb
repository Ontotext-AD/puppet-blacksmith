require 'rest-client'
require 'base64'
require 'json'
require 'yaml'

module Blacksmith
  class Nexus
    NEXUS_INSTANCE = 'http://nexus.instance.com'.freeze
    NEXUS_REPOSITORY = 'internal'.freeze
    CREDENTIALS_FILE_HOME = '~/.nexus.yml'.freeze
    CREDENTIALS_FILE_PROJECT = '.nexus.yml'.freeze
    DEFAULT_CREDENTIALS = { 'url' => NEXUS_INSTANCE, 'repository' => NEXUS_REPOSITORY }.freeze

    attr_accessor :username, :password, :url, :repository, :group, :artifact

    def initialize(username = nil, password = nil, url = nil)
      self.username = username
      self.password = password
      RestClient.proxy = ENV['http_proxy']
      load_credentials
      self.url = url unless url.nil?
    end

    def push!(_name, package = nil)
      unless package
        regex = /^.*\.tar\.gz$/
        pkg = File.expand_path('pkg')
        f = Dir.new(pkg).select { |f| f.match(regex) }.last
        raise Errno::ENOENT, "File not found in #{pkg} with regex #{regex}" if f.nil?
        package = File.join(pkg, f)
      end
      raise Errno::ENOENT, "File does not exist: #{package}" unless File.exist?(package)

      $auth_header = { 'Authorization' => 'Basic ' + Base64.encode64("#{username}:#{password}").chomp }

      begin
        RestClient.post("#{url}/service/local/artifact/maven/content", {
                          'r' => repository,
                          'g' => group,
                          'a' => artifact,
                          'v' =>  Blacksmith::Modulefile.new.version,
                          'p' => 'tar.gz',
                          :file => File.new(package, 'rb')
                        },
                        $auth_header)
      rescue RestClient::Exception => e
        raise Blacksmith::Error, "Error uploading #{package} to the nexus instance #{url} [#{e.message}]: #{e.response}"
      end
    end

    private

    def load_credentials
      file_credentials = load_credentials_from_file
      env_credentials = load_credentials_from_env

      credentials = DEFAULT_CREDENTIALS.merge file_credentials
      credentials = credentials.merge env_credentials

      self.username = credentials['username'] if credentials['username']
      self.password = credentials['password'] if credentials['password']
      self.url = credentials['url'] if credentials['url']
      self.repository = credentials['repository'] if credentials['repository']
      self.group = credentials['group'] if credentials['group']
      self.artifact = credentials['artifact'] if credentials['artifact']

      unless username && password
        raise Blacksmith::Error, <<-EOF
Could not find Nexus credentials!

Please set the environment variables
BLACKSMITH_NEXUS_URL
BLACKSMITH_NEXUS_USERNAME
BLACKSMITH_NEXUS_PASSWORD
BLACKSMITH_NEXUS_REPOSITORY
BLACKSMITH_NEXUS_GROUP_ID
BLACKSMITH_NEXUS_ARTIFACT_ID

or create the file '#{CREDENTIALS_FILE_PROJECT}' or '#{CREDENTIALS_FILE_HOME}'
with content similiar to:

---
url: http://nexus.instance.com
repository: internal
group: com.ontotext.puppet
artifact: base
username: myuser
password: mypassword
EOF
      end
    end

    def load_credentials_from_file
      credentials_file = [
        File.join(Dir.pwd, CREDENTIALS_FILE_PROJECT),
        File.expand_path(CREDENTIALS_FILE_HOME)
      ]
                         .select { |file| File.exist?(file) }
                         .first

      credentials = if credentials_file
                      YAML.load_file(credentials_file)
                    else
                      {}
                    end

      credentials
    end

    def load_credentials_from_env
      credentials = {}

      if ENV['BLACKSMITH_NEXUS_USERNAME']
        credentials['username'] = ENV['BLACKSMITH_NEXUS_USERNAME']
      end

      if ENV['BLACKSMITH_NEXUS_PASSWORD']
        credentials['password'] = ENV['BLACKSMITH_NEXUS_PASSWORD']
      end

      if ENV['BLACKSMITH_NEXUS_URL']
        credentials['url'] = ENV['BLACKSMITH_NEXUS_URL']
      end

      if ENV['BLACKSMITH_NEXUS_REPOSITORY']
        credentials['repository'] = ENV['BLACKSMITH_NEXUS_REPOSITORY']
      end

      if ENV['BLACKSMITH_NEXUS_GROUP_ID']
        credentials['group'] = ENV['BLACKSMITH_NEXUS_GROUP_ID']
      end

      if ENV['BLACKSMITH_NEXUS_ARTIFACT_ID']
        credentials['artifact'] = ENV['BLACKSMITH_NEXUS_ARTIFACT_ID']
      end

      credentials
    end
  end
end
