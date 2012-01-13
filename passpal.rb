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
# 5.7 YourAgent class
# 6. Application class

PASSPAL_VERSION = '0.3'


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
# From http://www.metabates.com/2011/02/07/building-interfaces-and-abstract-classes-in-ruby/
#
class Agent
  include AbstractInterface
  attr_accessor :analyzeTime, :reportTime
  def initialize
    @analyzeTime = 0
    @reportTime = 0
  end
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
    @analyzeTime += (stop.to_f - start.to_f)
    r
  end
  def profile_report
    start = Time.now
    r = report
    stop = Time.now
    @reportTime += (stop.to_f - start.to_f)
    r
  end
  def display_time
    self.class.to_s + " - Analyzing: " + @analyzeTime.round(4).to_s + "s Reporting: " + @reportTime.round(4).to_s + 's'
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
    total = @words.values.each_value.inject(:+)
    unique = @words.keys.length
    @words = Hash[@words.sort_by { |k, v| -v }]
    output = @words.first($top.to_i)
    output.each do |array|
      array << ((array[1].to_f/total)*100).round(4).to_s + ' %'
    end
    table = Ruport::Data::Table.new({
        :data => output,
        :column_names => ['Word', 'Count', 'Of total']
      })
    "Total words: \t" + total.to_s +
      "\nUnique words: \t" + unique.to_s + ' (' + ((unique.to_f/total.to_f)*100).round(2).to_s + ' %)' +
      "\n\nWord frequency, sorted by count, top " + $top.to_s + "\n" + table.to_s
  end
end


#
# 5.2 BaseWordFrequencyAgent
#
class BaseWordFrequencyAgent < Agent
  attr_accessor :words
  def initialize
    @words = Hash.new(0)
    @total = 0
  end
  def analyze(word)
    @total += 1
    word = word.gsub(/^[^a-zA-Z]+/, '').gsub(/[^a-zA-Z]+$/, '')
    @words[word] += 1 if word.length >= 3
  end
  def report
    @words = Hash[@words.sort_by { |k, v| -v }]
    output = @words.first($top.to_i)
    output.each do |array|
      array << ((array[1].to_f/@total)*100).round(4).to_s + ' %'
    end
    table = Ruport::Data::Table.new({
        :data => output,
        :column_names => ['Word', 'Count', 'Of total']
      })
      "Base word (len>=3) frequency, sorted by count, top " + $top.to_s + "\n" + table.to_s
  end
end


#
# 5.3 LengthFrequencyAgent
#
class LengthFrequencyAgent < Agent
  attr_accessor :lengths
  def initialize
    @lengths = Hash.new(0)
    @total = 0
  end
  def analyze(word)
    @lengths[word.length] += 1
    @total += 1
  end
  def report
    output = Hash[@lengths.sort].to_a
    output.each do |array|
      array << ((array[1].to_f/@total)*100).round(4).to_s + ' %'
    end
    table = Ruport::Data::Table.new({
        :data => output,
        :column_names => ['Length', 'Count', 'Of total']
      })  
    "Length frequency, sorted by length, full table\n" + table.to_s
  end
end


#
# 5.4 CharsetFrequencyAgent
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
    @total = 0
  end
  def analyze(word)
    @charsets.each do |key, hash|
      if hash[:pattern].match(word)
        @results[key] += 1
      end
    end
    @total += 1
  end
  def report
    output = []
    @results.each do |charset, count|
      output << [charset, count, ((count.to_f/@total)*100).round(4).to_s + ' %', count.to_f/@charsets[charset][:characters]]
    end
    table = Ruport::Data::Table.new({
        :data => output,
        :column_names => ['Charset', 'Count', 'Of total', 'Count/keyspace']
      })
    "Charset frequency, sorted by count, full table\n" + table.sort_rows_by("Count", :order => :descending).to_s + 
      "\nCharset frequency, sorted by count/keyspace, full table\n" + table.sort_rows_by("Count/keyspace", :order => :descending).to_s
  end
end


#
# 5.5 HashcatMaskFrequencyAgent
#
class HashcatMaskFrequencyAgent < Agent
  def initialize
    @results = Hash.new(0)
    @otherCount = 0
    @total = 0
  end
  def analyze(word)
    if Regexp.new('^[a-zA-Z0-9\p{Punct} ]+$'.force_encoding('utf-8'), Regexp::FIXEDENCODING).match(word)
      string = word.gsub(/[A-Z]/, 'U').gsub(/[a-z]/, 'L').gsub(/[0-9]/, 'D').gsub(Regexp.new('[\p{Punct} ]'.force_encoding('utf-8'), Regexp::FIXEDENCODING), 'S')
      @results[string] += 1
    else
      @otherCount += 1
    end
    @total += 1
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
      output << [realmask, count, ((count.to_f/@total)*100).round(4).to_s + ' %', count.to_f/keyspace.to_f]
    end
    table = Ruport::Data::Table.new({
        :data => output,
        :column_names => ['Mask', 'Count', 'Of total', 'Count/keyspace']
      })
    "Hashcat mask frequency, sorted by count, top " + $top.to_s + "\n" + table.sort_rows_by("Count", :order => :descending).sub_table(0...$top.to_i).to_s +
      "Words that didn't match any ?l?u?d?s mask: " + @otherCount.to_s + ' (' + ((@otherCount.to_f/@total)*100).round(4).to_s + ' %)' +
      "\n\nHashcat mask frequency, sorted by count/keyspace, top " + $top.to_s + "\n" + table.sort_rows_by("Count/keyspace", :order => :descending).sub_table(0...$top.to_i).to_s +
      "Words that didn't match any ?l?u?d?s mask: " + @otherCount.to_s + ' (' + ((@otherCount.to_f/@total)*100).round(4).to_s + ' %)' + "\n"
  end
end


#
# 5.6 SymbolFrequencyAgent
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
    "Symbol frequency, sorted by count, top " + $top.to_s + "\n" + table.sort_rows_by("Count", :order => :descending).sub_table(0...$top.to_i).to_s
  end
end


#
# 5.7 CharsetPositionAgent
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
    min_length = 6
    length = word.length
    if length >= min_length
      index = 0
      word.each_char do |char|
        if index < 3 || index >= length-3
          if index < 3
            pos = index
          elsif index >= length-3
            pos = -(length-index)
          end
          case char
          when /[a-z]/
            @results[:l][pos] += 1
          when /[A-Z]/
            @results[:u][pos] += 1				
          when /[0-9]/
            @results[:d][pos] += 1
          when Regexp.new('([\p{Punct} ])'.force_encoding('utf-8'), Regexp::FIXEDENCODING)
            @results[:s][pos] += 1
          end
        end
        index += 1
      end
    end
  end
  def report
    sum_0 = @results[:l][0]+@results[:u][0]+@results[:d][0]+@results[:s][0]
    sum_1 = @results[:l][1]+@results[:u][1]+@results[:d][1]+@results[:s][1]
    sum_2 = @results[:l][2]+@results[:u][2]+@results[:d][2]+@results[:s][2]
    sum_m3 = @results[:l][-3]+@results[:u][-3]+@results[:d][-3]+@results[:s][-3]
    sum_m2 = @results[:l][-2]+@results[:u][-2]+@results[:d][-2]+@results[:s][-2]
    sum_m1 = @results[:l][-1]+@results[:u][-1]+@results[:d][-1]+@results[:s][-1]
    table_f = Ruport::Data::Table.new({
      :data => [
        ['lower', ((@results[:l][0].to_f/sum_0)*100).round(4).to_s+' %', ((@results[:l][1].to_f/sum_1)*100).round(4).to_s+' %', ((@results[:l][2].to_f/sum_2)*100).round(4).to_s+' %', ((@results[:l][-3].to_f/sum_m3)*100).round(4).to_s+' %', ((@results[:l][-2].to_f/sum_m2)*100).round(4).to_s+' %', ((@results[:l][-1].to_f/sum_m1)*100).round(4).to_s+' %'],
        ['upper', ((@results[:u][0].to_f/sum_0)*100).round(4).to_s+' %', ((@results[:u][1].to_f/sum_1)*100).round(4).to_s+' %', ((@results[:u][2].to_f/sum_2)*100).round(4).to_s+' %', ((@results[:u][-3].to_f/sum_m3)*100).round(4).to_s+' %', ((@results[:u][-2].to_f/sum_m2)*100).round(4).to_s+' %', ((@results[:u][-1].to_f/sum_m1)*100).round(4).to_s+' %'],
        ['digits', ((@results[:d][0].to_f/sum_0)*100).round(4).to_s+' %', ((@results[:d][1].to_f/sum_1)*100).round(4).to_s+' %', ((@results[:d][2].to_f/sum_2)*100).round(4).to_s+' %', ((@results[:d][-3].to_f/sum_m3)*100).round(4).to_s+' %', ((@results[:d][-2].to_f/sum_m2)*100).round(4).to_s+' %', ((@results[:d][-1].to_f/sum_m1)*100).round(4).to_s+' %'],
        ['symbols', ((@results[:s][0].to_f/sum_0)*100).round(4).to_s+' %', ((@results[:s][1].to_f/sum_1)*100).round(4).to_s+' %', ((@results[:s][2].to_f/sum_2)*100).round(4).to_s+' %', ((@results[:s][-3].to_f/sum_m3)*100).round(4).to_s+' %', ((@results[:s][-2].to_f/sum_m2)*100).round(4).to_s+' %', ((@results[:s][-1].to_f/sum_m1)*100).round(4).to_s+' %'],
      ],
      :column_names => ['Charset\Index', '0 (first char)', 1, 2, -3, -2, '-1 (last char)']
    })
    "Charset distribution of characters in beginning and end of words (len>=6)\n" + table_f.to_s
  end
end


#
# 5.8 YourAgent
#
=begin
class YourAgent < Agent
  def initialize

  end
  def analyze(word)

  end
  def report
    #puts $top
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
	@output_file = STDOUT
    @profile_flag = false
    if RUBY_VERSION != '1.9.3'
      puts 'Warning: This software has only been tested on Ruby 1.9.3'
      puts
    end
    @possibleAgents = [
      WordFrequencyAgent.new,
      BaseWordFrequencyAgent.new,
      LengthFrequencyAgent.new,
      CharsetFrequencyAgent.new,
      HashcatMaskFrequencyAgent.new,
      SymbolFrequencyAgent.new,
      CharsetPositionAgent.new,
      #YourAgent.new,
    ]
    @agents = @possibleAgents
    opts = GetoptLong.new(
      ['--help', '-h', '-?', GetoptLong::NO_ARGUMENT],
      ['--top', '-t', GetoptLong::REQUIRED_ARGUMENT],
      ['--include', '-i', GetoptLong::REQUIRED_ARGUMENT],
      ['--exclude', '-e', GetoptLong::REQUIRED_ARGUMENT],
      ['--profile', '-p', GetoptLong::NO_ARGUMENT],
	  ['--outfile', '-o', GetoptLong::REQUIRED_ARGUMENT]
    )
    begin
      opts.each do |opt, arg|
        case opt
        when '--help'
          display_help
          exit 1
        when '--top'
          $top = arg
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
		when '--outfile'
			@output_file = File.new(arg, "w")
        end
      end
      $top ||= 10
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
    puts "passpal "+PASSPAL_VERSION+", T. Alexander Lystad <tal@lystadonline.no> (www.thepasswordproject.com)

Usage on Windows: ruby passpal.rb [switches] filename [> outfile.txt]
Usage on Linux:   ./passpal.rb [switches] filename [> outfile.txt]
--help \t\t\t Show help
--top \t\t\t Show top X results. Defaults to 10. Some reports are always shown in full. Example: --top 20
--include STRING \t Run these modules, separate with comma. Example: --include 1,3,5
--exclude STRING \t Run all modules except these, separate with comma. Example: --exclude 6
--profile \t\t Pretty inaccurate profiling, but should give you an idea what the relative time cost of the modules are
--outfile filename \t Output to this file
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
        unless agent.nil?
          if @profile_flag
            agent.profile_analyze(line.chomp)
          else 
              agent.analyze(line.chomp)
          end
        end
      end
    end
    progress.finish
    #Reporting
    buffer = "\n\npasspal "+PASSPAL_VERSION+" report (www.thepasswordproject.com)\n\n"
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
    @output_file.puts buffer
    #Profiling
    if @profile_flag
      @output_file.puts "Inaccurate profiling"
      @agents.each do |agent|
        unless agent.nil?
          @output_file.puts agent.display_time
        end
      end
    end
  end
end

a = Application.new()
a.run()
