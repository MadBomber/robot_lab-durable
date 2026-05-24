#!/usr/bin/env ruby
# frozen_string_literal: true

# Day Trader: subprocess launcher with interleaved prefixed output
#
# Spawns the generator and predictor as child processes, reads their
# stdout in background threads, and prints every line with a color-coded
# prefix so both streams are visible in a single terminal.
#
# [GEN ] lines — amber  — price ticks from the XYZZY generator
# [PRED] lines — cyan   — predictions, window results, and GOOD/MISS verdicts
#
# Ctrl-C forwards SIGINT to both children and shuts everything down.
#
# Prerequisites:
#   Redis server running on localhost:6379
#   PostgreSQL configured for HTM (see HTM gem setup)
#
# Usage (from the robot_lab-durable root):
#   ruby examples/01_day_trader.rb

require 'open3'

RUBY         = RbConfig.ruby
EXAMPLES_DIR = File.expand_path("day_trader_lib", __dir__)
GENERATOR    = File.join(EXAMPLES_DIR, "generator.rb")
PREDICTOR    = File.join(EXAMPLES_DIR, "predictor.rb")

GEN_COLOR  = "\e[33m"   # amber
PRED_COLOR = "\e[36m"   # cyan
RESET      = "\e[0m"
GEN_LABEL  = "[GEN ] "
PRED_LABEL = "[PRED] "

def die(msg)
  warn msg
  exit 1
end

[GENERATOR, PREDICTOR].each { |f| die("Missing: #{f}") unless File.exist?(f) }

puts <<~BANNER
  #{"=" * 62}
    Day Trader Demo
    Generator : XYZZY price stream via Redis (5s ticks, GBM model)
    Predictor : SMA+EMA ensemble tuned by a RobotLab durable agent
    Feedback  : ✓ GOOD / ✗ MISS verdict on each prediction window
    Stop      : Ctrl-C
  #{"=" * 62}
BANNER

# ── Spawn generator ───────────────────────────────────────────────────────────

_gen_in, gen_out, gen_thread = Open3.popen2e(RUBY, GENERATOR)
gen_pid = gen_thread.pid

# Give the generator one tick to connect to Redis before the predictor
# subscribes, avoiding a missed first message.
sleep 1

# ── Spawn predictor ───────────────────────────────────────────────────────────

_pred_in, pred_out, pred_thread = Open3.popen2e(RUBY, PREDICTOR)
pred_pid = pred_thread.pid

# ── Ctrl-C: forward SIGINT to both children ───────────────────────────────────

trap("INT") do
  [gen_pid, pred_pid].each { |pid| Process.kill("INT", pid) rescue nil }
end

# ── Relay each process's output with a color-coded label ─────────────────────

def relay(io, label, color)
  Thread.new do
    io.each_line do |line|
      $stdout.print "#{color}#{label}#{RESET}#{line}"
      $stdout.flush
    end
  end
end

t1 = relay(gen_out,  GEN_LABEL,  GEN_COLOR)
t2 = relay(pred_out, PRED_LABEL, PRED_COLOR)

t1.join
t2.join

gen_thread.value
pred_thread.value

puts "\nDay Trader stopped."
