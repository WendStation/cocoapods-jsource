
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
          [
              ['--short', 'Only print the path relative to the cache root'],
              ['--cache', 'Only print the cached pods']
          ].concat(super)
        end

        def initialize(argv)
          @pod_name = argv.shift_argument
          @short_output = argv.flag?('short')
          @pod_cache = argv.flag?('cache')
          @cache_dict = cache_object
          @manager = XcodeManager.new(argv)
          super
        end

        def run
          return if @cache_dict.nil?
          result = ""
          if @pod_name
            if @pod_cache
              result = @cache_dict[@pod_name] if @cache_dict.has_key? @pod_name
            else
              # 获取debug里 这个pod_name 的关键信息
              result = @manager.component_in_debug @pod_name
            end
          else
            if @pod_cache
              result = @cache_dict
            else
              # 获取debug里所有的group信息。
              result = @manager.all_components_in_debug
            end
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

