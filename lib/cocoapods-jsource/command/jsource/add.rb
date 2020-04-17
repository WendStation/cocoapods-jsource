require "cocoapods-core/lockfile"
require 'fileutils'
require 'cocoapods-jsource/command/xcode_manager'
require 'cocoapods'

module Pod
  class Command
    class Jsource < Command
      class Add < Jsource
        self.summary = 'Add source debugging function'

        self.description = <<-DESC
          Add source code debugging capabilities to binary.
        DESC

        self.arguments = [
            CLAide::Argument.new('NAMES', true),
        ]

        def initialize(argv)
          @namesString = argv.shift_argument
          @names = @namesString.split(',') unless @namesString.nil?
          @cache_dict = cache_object
          @manager = XcodeManager.new(argv)
          @remote = argv.flag?('remote')
          @index = -1
          super
        end

        def self.options
          [
              ['--remote', 'add components from internet'],
          ].concat(super)
        end

        def validate!
          super
          help! 'component name is required.' if @namesString.nil?
          #help! 'component git url is required.' unless @gits.length > 0
          #help! 'names number must be equal to gits number' unless @names.length == @gits.length
          help! 'podfile.lock file is required. you need pod install/update' unless File.exist? config.lockfile_path
        end

        def have_cached(component_name, version, subspecs)
          return false unless @cache_dict.has_key? component_name
          pod_cache_dict = @cache_dict[component_name]
          return false unless pod_cache_dict.has_key? version
          return false unless pod_cache_dict[version].has_key? :source_paths
          source_path_hash = pod_cache_dict[version][:source_paths]
          return false unless source_path_hash.length > 0
          if subspecs.length > 0
            tem_list = subspecs & (source_path_hash.keys - [component_name])
            return false unless tem_list == subspecs
            subspecs.each do |binary_name|
              return false unless source_path_hash.keys.include? binary_name
              dir_path = source_path_hash[binary_name]
              return false unless File.exist? dir_path
            end
          else
            source_path_hash.each do |binary_name, dir_path|
              return false unless File.exist? dir_path
            end
          end
          return true
        end

        def spec_with_name(name, version)
          set = config.sources_manager.search(Dependency.new(name, version))
          if set
            path = set.specification_paths_for_version(Version.new(version)).first
            spec = Specification.from_file(path)
            spec.root
          else
            raise Informative, "Unable to find a specification for `#{name}`"
          end
        end

        def download_component_to_path(component_name, version, source_path_hash={})
          source_path_hash.each do |binary_name, source_path|
            sandbox_path = source_path.split("Pods")[0] + "Pods"
            sandbox_component_path = "#{sandbox_path}/#{component_name}"
            binary_path = "#{sandbox_path}/#{binary_name}"
            if File.exist? sandbox_component_path
              UI.puts "using #{binary_name} #{version}"
              UI.puts "\t#{source_path.to_s}"
              FileUtils.copy_entry(sandbox_component_path, binary_path) unless File.exist? binary_path
            else
              UI.puts "downloading #{binary_name} #{version}"
              UI.puts "\t #{source_path.to_s}"
              FileUtils.mkdir_p [binary_path] unless File.exist? binary_path
              sandbox = Sandbox.new(sandbox_path)
              spec = spec_with_name(component_name, version)
              specs = { :ios => [spec] }
              installer = Installer::PodSourceInstaller.new(sandbox, config.podfile, specs, :can_cache => true)
              installer.install!
              #installer.clean!
              # TODO validtarget
              # 改名
              if binary_name != component_name and File.exist? sandbox_component_path
                FileUtils.copy_entry(sandbox_component_path, binary_path) unless File.exist? binary_name
              end
            end
          end
        end

        def local_have_source_files(component_name)
          files = Dir::glob "Pods/#{component_name}/**/*.m"
          if files and files.length > 0
            return true
          end
          return false
        end

        def source_files(component_name)
          return nil unless local_have_source_files component_name
          souces = []
          Dir::foreach "Pods/#{component_name}" do |path|
            next if path.include? "Frameworks"
            souces << path
          end
          souces
        end

        def get_file_list(path)
          list = []
          Dir.entries(path).each do |sub|
            if sub != '.' && sub != '..'
              if File.directory?("#{path}/#{sub}")
                list << "#{path}/#{sub}"
                list = list + get_file_list("#{path}/#{sub}")
              else
                list << "#{path}/#{sub}"
              end
            end
          end
          list
        end

        def local_component_to_path(component_name, version, source_paths_hash)
          path = "Pods/#{component_name}"
          # TODO 没有源码状态
          if !File.exist? path
            # copy files to source_paths
            UI.puts "本地目录不存在，请执行pod install/update 或者输入远程仓库地址"
            exit 1
          end
          #file_list = get_file_list path
          source_paths_hash.each do |binary_name, source_path_list|
            if source_path_list.length > 0
              if source_path_list[0].include?("Pods")
                dest_file_path = source_path_list[0].split("Pods")[0] + "Pods/#{binary_name}"
              else
                tmp_list = source_path_list[0].split(component_name)
                dest_file_path = tmp_list[0]
                if tmp_list.length > 2
                  dest_file_path += component_name
                end
              end
              UI.puts "copying #{binary_name} to #{dest_file_path}"
            end
            source_path_list.each do |dest_file_path|
              if dest_file_path.include?("Pods")
                origin_file = dest_file_path.split("Pods/#{binary_name}")[-1]
                origin_file_path = path + origin_file
              else
                tmp_list = dest_file_path.split(component_name)
                origin_file = tmp_list[-1]
                if tmp_list.length > 2
                  origin_file =  component_name + origin_file
                end
                origin_file_path = path + "/#{origin_file}"
              end
              if !File.exist? origin_file_path
                UI.warn "本地不存在#{origin_file_path}, 可能使用了虚拟subspec或者本地源码缓存有问题。推荐加上 --remote 参数"
                exit 1
              end
              if File.directory? origin_file_path
                # FileUtils.mkdir_p [dest_file_path], :mode => 0700 unless File.exist? dest_file_path
                create_working_directory dest_file_path
              else
                create_working_directory dest_file_path
                parent_dir = File.dirname dest_file_path
                FileUtils.mkdir_p [parent_dir], :mode => 0700 unless File.exist? parent_dir
                FileUtils.copy origin_file_path, dest_file_path unless File.exist? dest_file_path
                h_origin_file_path = origin_file_path.gsub(/(mm|m|c)$/, "h")
                h_dest_file_path = dest_file_path.gsub(/(mm|m|c)$/, "h")
                parent_dir = File.dirname h_dest_file_path
                create_working_directory parent_dir
                FileUtils.mkdir_p [parent_dir], :mode => 0700 unless File.exist? parent_dir
                FileUtils.copy h_origin_file_path, h_dest_file_path unless File.exist? h_dest_file_path
              end
            end
          end

        end


        def component_cache(component_name)
          if @cache_dict.has_key? component_name
            component_cache_dict = @cache_dict[component_name]
          end
          component_cache_dict
        end


        def local_source_paths(component_name, subspecs, source_paths_hash)
          local_hash = {}
          source_paths_hash.each do |binary_name, source_paths|
            need_add = false
            if binary_name != component_name
              if subspecs.include? binary_name
                need_add = true
              end
              if subspecs.length == 0
                need_add = true
              end
            else
              need_add = true
            end
            local_hash[binary_name] = source_paths if need_add
          end
          local_hash
        end


        def unite_source_paths_hash(source_paths_hash)
          source_path_hash = {}
          source_paths_hash.each do |binary_name, source_paths|
            source_path_hash[binary_name] = source_paths[0].split("Pods")[0] + "Pods/#{binary_name}" if source_paths.length > 0
          end
          source_path_hash
        end

        def run
          # 在Pods 目录下创建Debug.xcodeproj 文件。
          debug_xcodeproj = @manager.generate_debug_xcodeproj

          # 获取源码，并添加到工程里。
          @names.each do |component_name|
            @index = @index + 1
            version, subspecs = component_info component_name
            if version.length == 0
              UI.puts "#{component_name} 找不到对应的版本信息，不做任何处理"
              next
            end
            source_path_hash = {}
            if have_cached component_name, version, subspecs
              UI.puts "Using #{component_name} #{version} in #{@cache_dict[component_name][version][:source_paths]}"
              source_path_hash = @cache_dict[component_name][version][:source_paths]
            else
              source_paths_hash = source_paths_from_binary(component_name)
              if source_paths_hash.length == 0
                UI.puts "#{component_name} 找不到对应的二进制，不做任何处理"
                next
              end
              source_paths_hash = local_source_paths component_name, subspecs, source_paths_hash
              source_path_hash = unite_source_paths_hash source_paths_hash
              if @remote
                # 需要把值合并。
                download_component_to_path component_name, version, source_path_hash
              else
                local_component_to_path component_name, version, source_paths_hash
              end

            end

            # add_component_to_debug
            ENV["IS_SOURCE"] = "1"
            spec = spec_with_name component_name, version
            @manager.add_component_to_debug component_name, source_path_hash, debug_xcodeproj, spec
            # add_component_to_cache
            pod_cache_dict = {}
            pod_cache_dict[version] = {"source_paths":source_path_hash, "version":version}
            #if @use_remote
            #  pod_cache_dict[version]["git"] = @gits[@index]
            #end
            @cache_dict[component_name] = pod_cache_dict
            UI.puts "#{component_name} 源码创建成功，目录为 #{source_path_hash.to_s}"
          end
          @manager.add_debug_to_workspace
          dump_to_yaml @cache_dict
        end

        def component_info(component_name)
          return unless File.exist? config.lockfile_path
          version=""
          lockfile = Lockfile.from_file config.lockfile_path
          dependencies = lockfile.internal_data["DEPENDENCIES"]
          subspecs = []
          dependencies.each do |dependency|
            next unless dependency.start_with? component_name
            if !dependency.include? "(="
              UI.puts "podfile中 #{component_name} 可能没有指定版本，需要指定确定的版本才能使用。"
              exit 1
            end
            list = dependency.split(" (")
            name = list[0]
            if name.include? "/"
              name_list = name.split("/")
              subspec = name.gsub(/\//,"")
              name = name_list[0]
            end
            next unless name == component_name
            version = list[-1].split("/")[0].sub(")", "").sub("=", "").sub(" ", "") if version == ""
            subspecs << subspec if subspec
            spec = spec_with_name component_name, version
            spec.default_subspecs.each do |subspec_spec|
              subspecs = subspecs | ["#{component_name}#{subspec_spec}"]
            end
          end
          return version, subspecs
        end

        # 根据组件名获取组件的源码调试地址
        def source_paths_from_binary(component_name)
          source_path_hash = {}
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
            exit 1
          end

          binary_hash.each do |binary_name, binary_path|
            libbinary_file_name = "lib#{component_name}.a"
            at_name_list = []
            if binary_name.to_s.end_with? libbinary_file_name
              # .a 文件
              at_name_list = `dwarfdump -arch x86_64 #{binary_path} | grep 'AT_name.*#{binary_name}'`.strip.split("\n").sort
            else
              # framework 文件
              at_name_list = `dwarfdump -arch x86_64 #{binary_path} | grep 'DW_AT_name.*#{binary_name}'`.strip.split("\n").sort
            end
            #if source_file.length == 0
            #  UI.puts "在#{binary_path} 里没有找到合适的调试信息~"
            #  next
            #end
            source_list = []
            at_name_list.each do |tmp_source_path|
              if tmp_source_path.include?("Pods/#{binary_name}")
                source_path = tmp_source_path.strip.split("(\"")[-1].split("\")")[0]
                source_list << source_path if source_path.to_s.length > 0
              end
              if tmp_source_path.include?("../../")
                source_path = tmp_source_path.strip.split("(\"")[-1].split("\")")[0]
                source_list << source_path
              end
            end
            if source_list.length == 0
              UI.puts "#{component_name} 没有找到调试信息, 可能是早期打的组件。建议这个组件重新生成。"
              exit 1
            else
              source_path_hash[binary_name] = source_list
            end
          end
          source_path_hash
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

