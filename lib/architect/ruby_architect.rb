module BinaryBuilder
  class RubyArchitect < Architect
    RUBY_TEMPLATE_PATH = File.expand_path('../../../templates/ruby_blueprint', __FILE__)

    attr_reader :git_tag

    def initialize(options)
      @git_tag = options[:git_tag]
    end

    def blueprint
      blueprint_string = read_file(RUBY_TEMPLATE_PATH)
      blueprint_string.gsub!('GIT_TAG', git_tag)
      blueprint_string.gsub!('RUBY_DIRECTORY', "ruby-#{git_tag[1..-1].split('_')[0..2].join('.')}")
    end

    private
    def read_file(file)
      File.open(file).read
    end
  end
end