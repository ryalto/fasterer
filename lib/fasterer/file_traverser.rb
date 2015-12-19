require 'pathname'
require 'colorize'

require_relative 'analyzer'
require_relative 'config'

module Fasterer
  class FileTraverser
    CONFIG_FILE_NAME  = Config::FILE_NAME
    SPEEDUPS_KEY      = Config::SPEEDUPS_KEY
    EXCLUDE_PATHS_KEY = Config::EXCLUDE_PATHS_KEY

    attr_reader :config

    def initialize(path)
      @path = Pathname(path)
      @parse_error_paths = []
      @config = Config.new
    end

    def traverse
      if @path.directory?
        scannable_files.each { |ruby_file| scan_file(ruby_file) }
      else
        scan_file(@path)
      end
      output_parse_errors if parse_error_paths.any?
    end

    def config_file
      config.file
    end

    def offenses_found?
      !!offenses_found
    end

    private

    attr_reader :parse_error_paths
    attr_accessor :offenses_found

    def scan_file(path)
      analyzer = Analyzer.new(path)
      analyzer.scan
    rescue RubyParser::SyntaxError, Racc::ParseError, Timeout::Error
      parse_error_paths.push(path)
    else
      if offenses_grouped_by_type(analyzer).any?
        output(analyzer)
        self.offenses_found = true
      end
    end

    def scannable_files
      all_files - ignored_files
    end

    def all_files
      Dir["#{@path}/**/*.rb"].map do |ruby_file_path|
        Pathname(ruby_file_path).relative_path_from(@path).to_s
      end
    end

    def output(analyzer)
      puts analyzer.file_path.colorize(:red)

      offenses_grouped_by_type(analyzer).each do |error_group_name, error_occurences|
        puts "#{Fasterer::Offense::EXPLANATIONS[error_group_name]}."\
             " Occurred at lines: #{error_occurences.map(&:line_number).join(', ')}."
      end

      puts
    end

    def offenses_grouped_by_type(analyzer)
      analyzer.errors.group_by(&:name).delete_if do |offense_name, _|
        ignored_speedups.include?(offense_name)
      end
    end

    def output_parse_errors
      puts 'Fasterer was unable to process some files because the'
      puts 'internal parser is not able to read some characters or'
      puts 'has timed out. Unprocessable files were:'
      puts '-----------------------------------------------------'
      puts parse_error_paths
      puts
    end

    def ignored_speedups
      config.ignored_speedups
    end

    def ignored_files
      config.ignored_files
    end

    def nil_config_file
      config.nil_file
    end
  end
end
