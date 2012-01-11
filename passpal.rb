#!/usr/bin/env ruby

# Table of Contents
#
# 1. Load libraries
# 2. Monkey patching
# 3. AbstractInterface module
# 4. Agent class
# 5. Agents
# 5.1 WordFrequencyAgent class
# 5.2 LengthFrequencyAgent class
# 5.3 CharsetFrequencyAgent class
# 5.4 HashcatMaskFrequencyAgent class
# 5.5 SymbolFrequencyAgent class
# 5.6 CharsetPositionAgent class
# 6. Application class


#
# 1. Load libraries
#
require 'getoptlong'
#require 'ruby-prof'

begin
  require 'progressbar'
rescue LoadError
  puts "Could not load 'progressbar'. Install by running: gem install progressbar" 
  exit
end

begin
  require 'ruport'
rescue LoadError
  puts "Could not load 'ruport'. Install by running: gem install ruport" 
  exit
end


#
# 2. Monkey patching
#
class Array
  def longest_word
    group_by(&:size).max.last.first
  end
  def sum
    inject(:+)
  end
end

class Class
  def subclasses
    result = []
    ObjectSpace.each_object(Class) { |klass| result << klass if klass < self }
    result
  end
end


#
# 3. AbstractInterface module
#
module AbstractInterface
  class InterfaceNotImplementedError < NoMethodError
  end
  def self.included(klass)
    klass.send(:include, AbstractInterface::Methods)
    klass.send(:extend, AbstractInterface::Methods)
  end
  module Methods
    def api_not_implemented(klass)
      caller.first.match(/in \`(.+)\'/)
      method_name = $1
      raise AbstractInterface::InterfaceNotImplementedError.new("#{klass.class.name} needs to implement '#{method_name}' for interface #{self.name}!")
    end
  end
end


#
# 4. Extendable Agent class
#
class Agent
  include AbstractInterface
  attr_accessor :analyzeTime, :reportTime
  def analyze(word)
    Agent.api_not_implemented(self)
  end
  def report
    Agent.api_not_implemented(self)
  end
  def profile_analyze(word)
    start = Time.now
    r = analyze(word)
    stop = Time.now
    @analyzeTime ||= 0
    @analyzeTime += (stop.to_f - start.to_f)
    r
  end
  def profile_report
    start = Time.now
    r = report
    stop = Time.now
    @reportTime ||= 0
    @reportTime += (stop.to_f - start.to_f)
    r
  end
  def display_time
    puts self.class.to_s + " - Analyzing: " + @analyzeTime.round(4).to_s + "s Reporting: " + @reportTime.round(4).to_s + 's'
  end
end


#
# 5. Agents
# 5.1 WordFrequencyAgent
#
class WordFrequencyAgent < Agent
  attr_accessor :words
  def initialize
    @words = Hash.new(0)
  end
  def analyze(word)
    @words[word] += 1
  end
  def report
    @words = Hash[@words.sort_by { |k, v| -v }]
    table = Ruport::Data::Table.new({
        :data => @words.first(10),
        :column_names => %w[Word Count]
      })
    total  = @words.values.sum
    unique = @words.keys.length
    "Total words: \t" + total.to_s +
      "\nUnique words: \t" + unique.to_s + ' (' + ((unique.to_f/total.to_f)*100).round(2).to_s + ' %)' +
      "\n\nWord frequency, sorted by count, top 10\n" + table.to_s
  end
end


#
# 5.2 LengthFrequencyAgent
#
class LengthFrequencyAgent < Agent
  attr_accessor :lengths
  def initialize
    @lengths = Hash.new(0)
  end
  def analyze(word)
    @lengths[word.length] += 1
  end
  def report
    @lengths = Hash[@lengths.sort]
    table = Ruport::Data::Table.new({
        :data => @lengths,
        :column_names => %w[Length Count]
      })  
    "Length frequency, sorted by length, full table\n" + table.to_s
  end
end


#
# 5.3 CharsetFrequencyAgent
#
class CharsetFrequencyAgent < Agent
  attr_accessor :charsets, :results
  def initialize
    @charsets = Hash[
      :'lower' => Hash[:pattern => /^[a-z]+$/, :characters => 26],
      :'upper' => Hash[:pattern => /^[A-Z]+$/, :characters => 26],
      :'numeric' => Hash[:pattern => /^[0-9]+$/, :characters => 10],
      :'symbolic' => Hash[:pattern => Regexp.new('^[\p{Punct} ]+$'.force_encoding("utf-8"), Regexp::FIXEDENCODING), :characters => 33],
      :'lower-upper' => Hash[:pattern => /^[A-Za-z]+$/, :characters => 52],
      :'lower-numeric' => Hash[:pattern => /^[a-z0-9]+$/, :characters => 36],
      :'lower-symbolic' => Hash[:pattern => Regexp.new('^[a-z\p{Punct} ]+$'.force_encoding("utf-8"), Regexp::FIXEDENCODING), :characters => 59],
      :'upper-numeric' => Hash[:pattern => /^[A-Z0-9]+$/, :characters => 36],
      :'upper-symbolic' => Hash[:pattern => Regexp.new('^[A-Z\p{Punct} ]+$'.force_encoding("utf-8"), Regexp::FIXEDENCODING), :characters => 59],
      :'numeric-symbolic' => Hash[:pattern => Regexp.new('^[0-9\p{Punct} ]+$'.force_encoding("utf-8"), Regexp::FIXEDENCODING), :characters => 43],
      :'lower-upper-numeric' => Hash[:pattern => /^[A-Za-z0-9]+$/, :characters => 62],
      :'lower-upper-symbolic' => Hash[:pattern => Regexp.new('^[a-zA-Z\p{Punct} ]+$'.force_encoding("utf-8"), Regexp::FIXEDENCODING), :characters => 85],
      :'lower-numeric-symbolic' => Hash[:pattern => Regexp.new('^[a-z0-9\p{Punct} ]+$'.force_encoding("utf-8"), Regexp::FIXEDENCODING), :characters => 69],
      :'upper-numeric-symbolic' => Hash[:pattern => Regexp.new('^[A-Z0-9\p{Punct} ]+$'.force_encoding("utf-8"), Regexp::FIXEDENCODING), :characters => 69],
      :'lower-upper-numeric-symbolic' => Hash[:pattern => Regexp.new('^[A-Za-z0-9\p{Punct} ]+$'.force_encoding("utf-8"), Regexp::FIXEDENCODING), :characters => 95],
    ]
    @results = Hash.new(0)
  end
  def analyze(word)
    @charsets.each do |key, hash|
      if hash[:pattern].match(word)
        @results[key] += 1
      end
    end
  end
  def report
    output = []
    @results.each do |charset, count|
      output << [charset, count, count.to_f/@charsets[charset][:characters].to_f]
    end
    table = Ruport::Data::Table.new({
        :data => output,
        :column_names => %w[Charset Count Count/keyspace]
      })
    "Charset frequency, sorted by count, full table\n" + table.sort_rows_by("Count", :order => :descending).to_s + 
      "\nCharset frequency, sorted by count/keyspace, full table\n" + table.sort_rows_by("Count/keyspace", :order => :descending).to_s
  end
end


#
# 5.4 HashcatMaskFrequencyAgent
#
class HashcatMaskFrequencyAgent < Agent
  def initialize
    @results = Hash.new(0)
    @otherCount = 0
  end
  def analyze(word)
    if Regexp.new('^[a-zA-Z0-9\p{Punct} ]+$'.force_encoding('utf-8'), Regexp::FIXEDENCODING).match(word)
      string = word.gsub(/[A-Z]/, 'U').gsub(/[a-z]/, 'L').gsub(/[0-9]/, 'D').gsub(Regexp.new('[\p{Punct} ]'.force_encoding('utf-8'), Regexp::FIXEDENCODING), 'S')
      @results[string] += 1
    else
      @otherCount += 1
    end
  end
  def report
    output = []
    @results.each do |mask, count|
      keyspace = 1
      realmask = ''
      mask.each_char do |char|
        case char
        when 'L'
          keyspace *= 26
          realmask += '?l'
        when 'U'
          keyspace *= 26
          realmask += '?u'
        when 'D'
          keyspace *= 10
          realmask += '?d'
        when 'S'
          keyspace *= 33
          realmask += '?s'
        end
      end
      output << [realmask, count, count.to_f/keyspace.to_f]
    end
    table = Ruport::Data::Table.new({
        :data => output,
        :column_names => %w[Mask Count Count/keyspace]
      })
    "Hashcat mask frequency, sorted by count, top 10\n" + table.sort_rows_by("Count", :order => :descending).sub_table(0...10).to_s +
      "Words that didn't match any ?l?u?d?s mask: " + @otherCount.to_s +
      "\n\nHashcat mask frequency, sorted by count/keyspace, top 10\n" + table.sort_rows_by("Count/keyspace", :order => :descending).sub_table(0...10).to_s +
      "Words that didn't match any ?l?u?d?s mask: " + @otherCount.to_s + "\n"
  end
end


#
# 5.5 SymbolFrequencyAgent
#
class SymbolFrequencyAgent < Agent
  attr_accessor :symbols
  def initialize
    @symbols = Hash.new(0)
  end
  def analyze(word)
    m = word.scan(Regexp.new('([\p{Punct} ])'.force_encoding('utf-8'), Regexp::FIXEDENCODING))
    if m.length > 0
      m.each do |symbol|
        @symbols[symbol[0]] += 1
      end
    end
  end
  def report
    table = Ruport::Data::Table.new({
        :data => @symbols,
        :column_names => %w[Symbol Count]
      })
    "Symbol frequency, sorted by count, top 10\n" + table.sort_rows_by("Count", :order => :descending).sub_table(0...10).to_s
  end
end


#
# 5.6 CharsetPositionAgent
#
class CharsetPositionAgent < Agent
  attr_accessor :result
  def initialize
    @results = {
      :l => Hash.new(0),
      :u => Hash.new(0),
      :d => Hash.new(0),
      :s => Hash.new(0)
    }
  end
  def analyze(word)
    index = 0
    word.each_char do |char|
      case char
      when /[a-z]/
        @results[:l][index] += 1
      when /[A-Z]/
        @results[:u][index] += 1				
      when /[0-9]/
        @results[:d][index] += 1
      when Regexp.new('([\p{Punct} ])'.force_encoding('utf-8'), Regexp::FIXEDENCODING)
        @results[:s][index] += 1
      end
      index += 1
    end
  end
  def report
    @results[:l] = Hash[@results[:l].sort]
    @results[:u] = Hash[@results[:u].sort]
    @results[:d] = Hash[@results[:d].sort]
    @results[:s] = Hash[@results[:s].sort]
    table_l = Ruport::Data::Table.new({
        :data => [@results[:l].values.insert(0, 'Count')],
        :column_names => @results[:l].keys.insert(0, 'Position')
      })
    table_u = Ruport::Data::Table.new({
        :data => [@results[:u].values.insert(0, 'Count')],
        :column_names => @results[:u].keys.insert(0, 'Position')
      })
    table_d = Ruport::Data::Table.new({
        :data => [@results[:d].values.insert(0, 'Count')],
        :column_names => @results[:d].keys.insert(0, 'Position')
      })
    table_s = Ruport::Data::Table.new({
        :data => [@results[:s].values.insert(0, 'Count')],
        :column_names => @results[:s].keys.insert(0, 'Position')
      })
    "Position of lowercase characters, sorted by count, full table\n" + table_l.to_s +
      "\nPosition of uppercase characters, sorted by count, full table\n" + table_u.to_s +
      "\nPosition of digit characters, sorted by count, full table\n" + table_d.to_s +
      "\nPosition of symbol characters, sorted by count, full table\n" + table_s.to_s
  end
end


#
# 5.7 YourAgent
#
=begin
class YourAgent < Agent
def initialize

end
def analyze(word)

end
def report

end
end
=end


#
# 6. Application
#
class Application

  attr_accessor :agents
  attr_accessor :profile_flag

  def initialize
    @profile_flag = false
    if RUBY_VERSION != '1.9.3'
      puts 'Warning: This software has only been tested on Ruby 1.9.3'
      puts
    end
    @possibleAgents = [
      WordFrequencyAgent.new,
      LengthFrequencyAgent.new,
      CharsetFrequencyAgent.new,
      HashcatMaskFrequencyAgent.new,
      SymbolFrequencyAgent.new,
      CharsetPositionAgent.new,
      #YourAgent.new
    ]
    @agents = @possibleAgents
    opts = GetoptLong.new(
      ['--help', '-h', '-?', GetoptLong::NO_ARGUMENT],
      ['--include', '-i', GetoptLong::REQUIRED_ARGUMENT],
      ['--exclude', '-e', GetoptLong::REQUIRED_ARGUMENT],
      ['--profile', '-p', GetoptLong::NO_ARGUMENT]
    )
    begin
      opts.each do |opt, arg|
        case opt
        when '--help'
          display_help
          exit 1
        when '--include'
          @agents = []
          arg.split(/,/).each do |i|
            @agents << @possibleAgents[i.to_i-1]
          end
        when '--exclude'
          @agents = @possibleAgents
          arg.split(/,/).each do |i|
            @agents[i.to_i-1] = nil
          end
        when '--profile'
          @profile_flag = true
        end
      end
    rescue GetoptLong::InvalidOption => e
      puts e
    rescue => e
      puts e
    end
    if ARGV.length != 1
      abort "Missing file argument (try --help)"
    end
  end

  def display_help
    puts "passpal 0.1, T. Alexander Lystad <tal@lystadonline.no> (www.lystadonline.no)

Usage: passpal [switches] ... filename [> outfile.txt]
--help \t\t\t Show help
--include STRING \t Run these modules, separate with comma. Example: --include 1,3,5
--exclude STRING \t Run all modules except these, separate with comma. Example: --exclude 6
--profile \t\t Pretty inaccurate profiling, but should give you an idea what the relative time cost of the modules are
filename \t\t The file to analyze. Must be UTF-8 encoded.

    "
    puts "Available modules: "
    @possibleAgents.each_with_index do |value, key|
      puts (1+key).to_s + ' = ' + value.class.to_s
    end
  end

  def run
    #Analyzing
    filename = ARGV.shift
    f = File.open(filename, 'r:UTF-8')
    progress = ProgressBar.new('Analyzing', f.size)
    f.each_line do |line|
      progress.inc(line.bytesize)
      @agents.each do |agent|
        if @profile_flag && !agent.nil?
          agent.profile_analyze(line.chomp)
        else 
          agent.analyze(line.chomp)
        end
      end
    end
    progress.finish
    #Reporting
    buffer = "\n\n"
    progress = ProgressBar.new('Reporting', @agents.size)
    @agents.each do |agent|
      unless agent.nil?
        if @profile_flag
          string = agent.profile_report
        else
          string = agent.report
        end
        buffer += string + "\n\n" unless string.nil?
        progress.inc
      end
    end
    progress.finish
    puts buffer
    #Profiling
    if @profile_flag
      puts "Inaccurate profiling"
      @agents.each do |agent|
        unless agent.nil?
          agent.display_time
        end
      end
    end
  end

end

a = Application.new()
a.run()
