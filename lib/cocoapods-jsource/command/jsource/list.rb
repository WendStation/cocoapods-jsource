
require "cocoapods-core/lockfile"
require 'fileutils'

module Pod
  class Command
    class Jsource < Command
      class List < Jsource
        self.summary = 'list all source info'

        self.description = <<-DESC
          Prints the content of the jsource(s) whose name matches `QUERY` to standard output.
        DESC

        self.arguments = [
            CLAide::Argument.new('QUERY', false),
        ]

        def self.options
          [[
               '--short', 'Only print the path relative to the cache root'
           ]].concat(super)
        end

        def initialize(argv)
          @pod_name = argv.shift_argument
          @short_output = argv.flag?('short')
          @cache_dict = cache_object
          super
        end

        def run
          return if @cache_dict.nil?
          result = ""
          if @pod_name
            result = @cache_dict[@pod_name] if @cache_dict.has_key? @pod_name
          else
            result = @cache_dict
          end
          if @short_output
            result = result.keys
          end
          output_pipe.puts result.to_yaml unless result.nil? or result.length == 0
        end

      end
    end
  end
end

