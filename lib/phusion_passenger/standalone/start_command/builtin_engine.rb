# encoding: utf-8
#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2014-2015 Phusion
#
#  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
#
#  See LICENSE file for license information.

require 'etc'
PhusionPassenger.require_passenger_lib 'constants'
PhusionPassenger.require_passenger_lib 'standalone/control_utils'
PhusionPassenger.require_passenger_lib 'utils/shellwords'
PhusionPassenger.require_passenger_lib 'utils/json'

module PhusionPassenger
  module Standalone
    class StartCommand

      module BuiltinEngine
      private
        def start_engine_real
          Standalone::ControlUtils.require_daemon_controller
          @engine = DaemonController.new(build_daemon_controller_options)
          start_engine_no_create
        end

        def wait_until_engine_has_exited
          lock = DaemonController::LockFile.new(read_watchdog_lock_file_path!)
          lock.shared_lock do
            # Do nothing
          end
        end


        def start_engine_no_create
          begin
            @engine.start
          rescue DaemonController::AlreadyStarted
            begin
              pid = @engine.pid
            rescue SystemCallError, IOError
              pid = nil
            end
            if pid
              abort "#{PROGRAM_NAME} Standalone is already running on PID #{pid}."
            else
              abort "#{PROGRAM_NAME} Standalone is already running."
            end
          rescue DaemonController::StartError => e
            abort "Could not start the server engine:\n#{e}"
          end
        end

        def build_daemon_controller_options
          if @options[:socket_file]
            ping_spec = [:unix, @options[:socket_file]]
          else
            ping_spec = [:tcp, @options[:address], @options[:port]]
          end

          command = ""

          if !@options[:envvars].empty?
            command = "env "
            @options[:envvars].each_pair do |name, value|
              command << "#{Shellwords.escape name}=#{Shellwords.escape value} "
            end
          end

          command << "#{@agent_exe} watchdog";
          command << " --passenger-root #{Shellwords.escape PhusionPassenger.install_spec}"
          command << " --daemonize"
          command << " --no-user-switching"
          command << " --no-delete-pid-file"
          command << " --cleanup-pidfile #{Shellwords.escape @working_dir}/temp_dir_toucher.pid"
          if should_wait_until_engine_has_exited?
            command << " --report-file #{Shellwords.escape @working_dir}/report.json"
          end
          add_param(command, :user, "--user")
          add_param(command, :log_file, "--log-file")
          add_param(command, :pid_file, "--pid-file")
          add_param(command, :instance_registry_dir, "--instance-registry-dir")
          add_param(command, :data_buffer_dir, "--data-buffer-dir")
          add_param(command, :log_level, "--log-level")
          @options[:ctls].each do |ctl|
            command << " --ctl #{Shellwords.escape ctl}"
          end
          if @options[:user]
            command << " --default-user #{Shellwords.escape @options[:user]}"
          else
            user  = Etc.getpwuid(Process.uid).name
            begin
              group = Etc.getgrgid(Process.gid)
            rescue ArgumentError
              # Do nothing. On Heroku, it's normal that the group
              # database is broken.
            else
              command << " --default-group #{Shellwords.escape group.name}"
            end
            command << " --default-user #{Shellwords.escape user}"
          end

          command << " --BS"
          command << " --listen #{listen_address}"
          command << " --no-graceful-exit"
          add_param(command, :environment, "--environment")
          add_param(command, :app_type, "--app-type")
          add_param(command, :startup_file, "--startup-file")
          add_param(command, :spawn_method, "--spawn-method")
          add_param(command, :restart_dir, "--restart-dir")
          if @options.has_key?(:friendly_error_pages)
            if @options[:friendly_error_pages]
              command << " --force-friendly-error-pages"
            else
              command << " --disable-friendly-error-pages"
            end
          end
          if @options[:turbocaching] == false
            command << " --disable-turbocaching"
          end
          add_flag_param(command, :load_shell_envvars, "--load-shell-envvars")
          add_param(command, :max_pool_size, "--max-pool-size")
          add_param(command, :min_instances, "--min-instances")
          add_enterprise_param(command, :concurrency_model, "--concurrency-model")
          add_enterprise_param(command, :thread_count, "--app-thread-count")
          add_enterprise_flag_param(command, :rolling_restarts, "--rolling-restarts")
          add_enterprise_flag_param(command, :resist_deployment_errors, "--resist-deployment-errors")
          add_enterprise_flag_param(command, :debugger, "--debugger")
          add_flag_param(command, :sticky_sessions, "--sticky-sessions")
          add_param(command, :vary_turbocache_by_cookie, "--vary-turbocache-by-cookie")
          add_param(command, :sticky_sessions_cookie_name, "--sticky-sessions-cookie-name")
          add_param(command, :union_station_gateway_address, "--union-station-gateway-address")
          add_param(command, :union_station_gateway_port, "--union-station-gateway-port")
          add_param(command, :union_station_key, "--union-station-key")

          command << " #{Shellwords.escape(@apps[0][:root])}"

          return {
            :identifier    => "#{AGENT_EXE} watchdog",
            :start_command => command,
            :ping_command  => ping_spec,
            :pid_file      => @options[:pid_file],
            :log_file      => @options[:log_file],
            :timeout       => 25
          }
        end

        def listen_address(options = @options, for_ping_port = false)
          if options[:socket_file]
            return "unix:" + File.absolute_path_no_resolve(options[:socket_file])
          else
            return "tcp://" + compose_ip_and_port(options[:address], options[:port])
          end
        end

        def add_param(command, option_name, param_name)
          if value = @options[option_name]
            command << " #{param_name} #{Shellwords.escape value.to_s}"
          end
        end

        def add_flag_param(command, option_name, param_name)
          if value = @options[option_name]
            command << " #{param_name}"
          end
        end

        def add_enterprise_param(command, option_name, param_name)
          if value = @options[option_name]
            command << " #{param_name} #{Shellwords.escape value.to_s}"
          end
        end

        def add_enterprise_flag_param(command, option_name, param_name)
          if value = @options[option_name]
            command << " #{param_name}"
          end
        end

        def report_file_path
          @report_file_path ||= "#{@working_dir}/report.json"
        end

        def read_watchdog_lock_file_path!
          @watchdog_lock_file_path ||= begin
            report = File.open(report_file_path, "r:utf-8") do |f|
              Utils::JSON.parse(f.read)
            end
            # The report file may contain sensitive information, so delete it.
            File.unlink(report_file_path)
            report["instance_dir"] + "/lock"
          end
        end

        #####################

        def reload_engine(pid)
          @engine.stop
          start_engine_no_create
        end
      end # module BuiltinEngine

    end # module StartCommand
  end # module Standalone
end # module PhusionPassenger