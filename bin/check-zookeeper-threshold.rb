#!/usr/bin/env ruby
#
# check-zookeeper-threshold.rb
#
# ===
#
# DESCRIPTION:
#   Run a Zookeeper command (e.g. 'mntr'), parse the result for a particular value,
#   and test that value against minumum and/or maximum thresholds
#
# PLATFORMS:
#   Linux, BSD, Solaris
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#  check-zookeeper-threshold.rb --zk_command <command> --metric <name-of-the-metric-to-check> --leader_only \
#  [--minwarn <minimun-warning-threshold>] [--maxwarn <maximum-warning-threshold>] \
#  [--mincrit <minimun-critical-threshold>] [--maxcrit <maximum-critical-threshold>] 
#
# EXAMPLE:
# check-zookeeper-mntr.rb --zk_command mntr --metric zk_synced_followers --leader_only --mincrit 2
#

require 'sensu-plugin/check/cli'
require 'socket'

class ZookeeperThreshold < Sensu::Plugin::Check::CLI

  option :host,
         description: 'ZooKeeper host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'ZooKeeper port',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 2181

  option :leader_only,
         description: 'If true, cut the check short and return OK if the server is not the leader.  Some values are only present on leaders.',
         long: '--leader_only',
         boolean: true,
         default: false

  option :zk_command,
         description: 'Zookeeper command/four-letter-word',
         long: '--zk_command ZK_COMMAND',
         default: 'mntr'

  option :metric,
         description: 'Metric to threshold check',
         long: '--metric METRIC'

  option :minwarn,
         long: '--minwarn MINWARN',
         proc: proc(&:to_f)

  option :maxwarn,
         long: '--maxwarn MAXWARN',
         proc: proc(&:to_f)

  option :mincrit,
         long: '--mincrit MINCRIT',
         proc: proc(&:to_f)

  option :maxcrit,
         long: '--maxcrit MAXCRIT',
         proc: proc(&:to_f)

  def zkcmd(four_letter_word)
    Socket.tcp(config[:host], config[:port]) do |sock|
      sock.print "#{four_letter_word}\r\n"
      sock.close_write
      sock.read
    end
  end

  def run

    if config[:leader_only]
      response = zkcmd(:srvr)
      ok "Check run on a follower, but run as leader_only" if response !~ /^Mode: leader$/
    end

    response = zkcmd(config[:zk_command])

    if response =~ /^#{config[:metric]}\s+(\d+)$/
      value = Regexp.last_match(1)
    else
      unknown "#{config[:metric]} not found.  If the metric is only present on leaders, run with --leader_only"
    end

    if config[:mincrit] != nil
      critical "#{config[:metric]} #{value} less than #{config[:mincrit]}" if value.to_f < config[:mincrit]
    end

    if config[:maxcrit] != nil
      critical "#{config[:metric]} #{value} exceeds #{config[:maxcrit]}" if value.to_f > config[:maxcrit]
    end

    if config[:minwarn] != nil
      warning "#{config[:metric]} #{value} less than #{config[:minwarn]}" if value.to_f < config[:minwarn] 
    end

    if config[:maxwarn] != nil
      warning "#{config[:metric]} #{value} exceeds #{config[:maxwarn]}" if value.to_f > config[:maxwarn]
    end

    ok "#{config[:metric]}: #{value}"

  end
end
