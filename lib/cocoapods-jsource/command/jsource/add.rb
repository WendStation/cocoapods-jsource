
require "cocoapods-core/lockfile"
require 'fileutils'

module Pod
  class Command
    class Jsource < Command
      class Add < Jsource
        self.summary = 'Add source debugging function'

        self.description = <<-DESC
          Add source code debugging capabilities to binary.
        DESC

        def self.options
          [
              ['--names', 'component names to be added'],
              ['--gits', 'component git url to be added'],
          ].concat(super)
        end

        def initialize(argv)
          @namesString = argv.option('names')
          @names = @namesString.split(',') unless @namesString.nil?
          @gitsString = argv.option('gits')
          @gits = @gitsString.split(',') unless  @gitsString.nil?
          super
        end

        def validate!
          super
          help! 'component name is required.' unless @names.length > 0
          help! 'component git url is required.' unless @gits.length > 0
          help! 'names number must be equal to gits number' unless @names.length == @gits.length
          help! 'podfile.lock file is required. you need pod install/update' unless File.exist? config.lockfile_path
        end

        def run
          # 获取当前目录
          index = 0
          cache_dict = cache_object
          @names.each do |component_name|
            pod_cache_dict = {}
            if cache_dict.has_key? component_name
              pod_cache_dict = cache_dict[component_name]
            end
            version = component_version component_name
            if version.length == 0
              UI.puts "#{component_name} 找不到对应的版本信息，不做任何处理"
              next
            end
            if pod_cache_dict.has_key? version
              UI.puts "#{component_name} #{version} 已经存在，缓存为 #{pod_cache_dict[version][:sourcelist].to_s}"
              next
            end
            git = @gits[index]
            # 获取subspec
            source_file_list = get_source_file_list_from_binary(component_name)
            if source_file_list.length == 0
              UI.puts "#{component_name} 找不到对应的二进制，不做任何处理"
              next
            end
            UI.puts "开始下载源码..."
            for source_path in source_file_list
              create_working_directory source_path
              cmd ="git clone -b #{component_name}-#{version} --depth 1 #{git} #{source_path} >/dev/null 2>&1"
              `#{cmd}`
            end
            pod_cache_dict[version] = {"git":git, "sourcelist":source_file_list, "version":version}
            cache_dict[component_name] = pod_cache_dict
            UI.puts "#{component_name} 源码创建成功，目录为 #{source_file_list.to_s}"
            index = index + 1
          end
          dump_to_yaml cache_dict
        end

        def component_version(component_name)
          return unless File.exist? config.lockfile_path
          version=""
          lockfile = Lockfile.from_file config.lockfile_path
          dependencies = lockfile.internal_data["DEPENDENCIES"]
          dependencies.each do |dependency|
            list = dependency.split(" (")
            name = list[0]
            next unless name == component_name
            version = list[-1].sub(")", "").sub("=", "").sub(" ", "")
          end
          version
        end

        # 根据组件名获取组件的源码调试地址
        def get_source_file_list_from_binary(component_name)
          source_file_list = []
          component_pod_path = config.sandbox_root + component_name
          binary_path_list = `find #{component_pod_path} -name "#{component_name}*" -type l`.strip.split("\n").sort
          binary_hash = {}
          for path in binary_path_list
            name = path.to_s.strip.split("/")[-1]
            if name.to_s.include? ".a" or not name.to_s.include? "."
              binary_hash[name]=path unless binary_hash.has_key? name
            end
          end
          if binary_hash.length == 0
            UI.puts "#{component_name} 找不到二进制组件或者找不到对应的版本信息，不做任何处理"
            return source_file_list
          end

          binary_hash.each do |binary_name, binary_path|
            libbinary_file_name = "lib#{component_name}.a"
            source_path_list = []
            UI.puts "正在解析二进制#{binary_path}源码位置"
            if binary_name.to_s.end_with? libbinary_file_name
              # .a 文件
              source_path_list = `dwarfdump -arch x86_64 #{binary_path} | grep 'AT_name.*#{binary_name}'`.strip.split("\n").sort
            else
              # framework 文件
              source_path_list = `dwarfdump -arch x86_64 #{binary_path} | grep 'DW_AT_name.*#{binary_name}'`.strip.split("\n").sort
            end
            source_path_list.each do |tmp_source_path|
              if tmp_source_path.include?("Pods/#{binary_name}")
                source_path = tmp_source_path.strip.split("(\"")[-1].split(binary_name)[0] + "#{binary_name}"
                source_file_list << source_path if source_path.to_s.length > 0
                break
              end
            end
          end
          source_file_list
        end


        # 创建源码的存放的目录，可能需要root权限
        def create_working_directory(source_path)
          parent = source_path.split("T")[0]
          parent = File.expand_path(parent)
          return unless parent.length >0
          return if Dir.exist? parent
          UI.puts "检测到没有源码目录，即将创建#{parent}目录"
          `sudo -S mkdir -p #{parent}`
          user = `whoami`.strip
          `sudo -S chown #{user}:staff #{parent}`
        end
      end
    end
  end
end

