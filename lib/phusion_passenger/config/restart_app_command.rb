#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2013 Phusion
#
#  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
#
#  See LICENSE file for license information.

require 'optparse'
PhusionPassenger.require_passenger_lib 'constants'
PhusionPassenger.require_passenger_lib 'admin_tools/server_instance'
PhusionPassenger.require_passenger_lib 'config/command'
PhusionPassenger.require_passenger_lib 'config/utils'

module PhusionPassenger
module Config

class RestartAppCommand < Command
	include PhusionPassenger::Config::Utils

	def self.description
		return "Restart an application"
	end

	def run
		parse_options
		select_passenger_instance
		@admin_client = connect_to_passenger_admin_socket(:role => :passenger_status)
		select_app_group_name
		perform_restart
	end

private
	def self.create_option_parser(options)
		OptionParser.new do |opts|
			nl = "\n" + ' ' * 37
			opts.banner =
				"Usage 1: passenger-config restart-app <APP PATH PREFIX> [OPTIONS]\n" +
				"Usage 2: passenger-config restart-app --name <APP GROUP NAME> [OPTIONS]"
			opts.separator ""
			opts.separator "  Restart an application. The syntax determines how the application that is to"
			opts.separator "  be restarted, will be selected."
			opts.separator ""
			opts.separator "  1. Selects all applications whose paths begin with the given prefix."
			opts.separator ""
			opts.separator "     Example: passenger-config restart-app /webapps"
			opts.separator "     Restarts all apps whose path begin with /webapps, such as /webapps/foo,"
			opts.separator "     /webapps/bar and /webapps123."
			opts.separator ""
			opts.separator "  2. Selects a specific application based on an exact match of its app group"
			opts.separator "     name."
			opts.separator ""
			opts.separator "     Example: passenger-config restart-app --name /webapps/foo"
			opts.separator "     Restarts only /webapps/foo, but not for example /webapps/foo/bar or"
			opts.separator "     /webapps/foo123."
			opts.separator ""

			opts.separator "Options:"
			opts.on("--name APP_GROUP_NAME", String, "The app group name to select") do |value|
				options[:app_group_name] = value
			end
			opts.on("--rolling-restart", "Perform a rolling restart instead of a#{nl}" +
				"regular restart (Enterprise only). The#{nl}" +
				"default is a blocking restart") do |value|
				if Config::Utils.is_enterprise?
					options[:rolling_restart] = true
				else
					abort "--rolling-restart is only available in #{PROGRAM_NAME} Enterprise: #{ENTERPRISE_URL}"
				end
			end
			opts.on("--instance PID", Integer, "The #{PROGRAM_NAME} instance to select") do |value|
				options[:instance] = value
			end
			opts.on("-h", "--help", "Show this help") do
				options[:help] = true
			end
		end
	end

	def help
		puts @parser
	end

	def parse_options
		super
		case @argv.size
		when 0
			if !@options[:app_group_name]
				abort "Please pass either an app path prefix or an app group name. " +
					"See --help for more information."
			end
		when 1
			if @options[:app_group_name]
				abort "You've passed an app path prefix, but you cannot also pass an " +
					"app group name. Please use only either one of them. See --help " +
					"for more information."
			end
		else
			help
			abort
		end
	end

	def select_app_group_name
		groups = @server_instance.groups(@admin_client)
		if app_group_name = @options[:app_group_name]
			@groups = [groups.find { |g| g.name == app_group_name }]
			if !@groups[0]
				abort "There is no #{PROGRAM_NAME}-served application running with the app group name '#{app_group_name}'."
			end
		else
			regex = /^#{Regexp.escape(@argv.first)}/
			@groups = groups.find_all { |g| g.app_root =~ regex }
			if @groups.empty?
				abort "There are no #{PROGRAM_NAME}-served applications running whose paths begin with '#{@argv.first}'."
			end
		end
	end

	def perform_restart
		restart_method = @options[:rolling_restart] ? "rolling" : "blocking"
		@groups.each do |group|
			puts "Restarting #{group.name}"
			@admin_client.restart_app_group(group.name,
				:method => restart_method)
		end
	end
end

end # module Config
end # module PhusionPassenger
