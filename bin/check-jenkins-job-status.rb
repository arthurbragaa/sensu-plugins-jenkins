#! /usr/bin/env ruby
#
#   check-jenkins-job-status
#
# DESCRIPTION:
#   Query jenkins API for a given number of failed builds and alert if the number
#   of failure is above the desired number
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   jenkins_api_client
#
# USAGE:
#   ruby bin/check-jenkins-job-status.rb --job build_ticket_box --builds 5
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 SUSE, GmbH <happy-customer@suse.de>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'jenkins_api_client'
require 'pry'

#
# Jenkins Job Check
#
class JenkinsJobChecker < Sensu::Plugin::Check::CLI
  option :server_api_url,
         description: 'hostname running Jenkins API',
         short: '-u JENKINS-API-HOST',
         long: '--url JENKINS-API-HOST',
         required: false,
         default: ENV['JENKINS_URL']

  option :job_name,
         description: 'Name of the a job',
         short: '-j JOB-NAME',
         long: '--job JOB-NAME',
         required: true

  option :builds,
         description: 'Number of failed builds to check',
         short: '-b COUNT',
         long: '--builds COUNT',
         required: true,
         proc: proc(&:to_i)

  option :username,
         description: 'Username for Jenkins instance',
         short: '-U USERNAME',
         long: '--username USERNAME',
         required: false,
         default: ENV['JENKINS_USER']

  option :password,
         description: "Password for Jenkins instance. Either set ENV['JENKINS_PASS'] or provide it as an option",
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         required: false,
         default: ENV['JENKINS_PASS']

  def run
    if failed_builds_count >= config[:builds]
      critical "The last #{config[:builds]} #{config[:job_name]} jobs are failing on Jenkins"
    else
      ok "Less than #{config[:builds]} #{config[:job_name]} jobs are failing on Jenkins"
    end
  end

  private

  def jenkins_api_client
    @jenkins_api_client ||= JenkinsApi::Client.new(
      server_url: config[:server_api_url],
      log_level: config[:client_log_level].to_i,
      username: config[:username], password: config[:password]
    )
  end

  def failed_builds_count
    current_build_number = jenkins_api_client.job.get_current_build_number(config[:job_name])
    count_builds = config[:builds]
    failed_builds = 0
    while count_builds > 0
      build = jenkins_api_client.job.get_build_details(config[:job_name], current_build_number)
      puts "#{build["displayName"]} ----> #{build["result"]}"
      current_build_number -= 1
      next if build["result"].nil? #Don't care about the running jobs
      failed_builds += 1 if build["result"] == "FAILURE"

      count_builds -= 1
    end
    failed_builds
  # rescue
  #   critical "Error looking up Jenkins job: #{config[:job_name]}"
  end
end
