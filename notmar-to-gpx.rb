#!/usr/bin/env ruby
require 'net/http'
require 'nokogiri'
require 'geo/coord'
require 'gpx'
require 'i18n'
require 'json'
I18n.config.available_locales = :en
require 'optimist'

p = Optimist::Parser.new do
  version "notmar-to-gpx.rb 1.0.0 (c) 2010 Pierre-Luc Dion"
  banner <<-EOS
Generate GPX file from Canadian Notices to Mariner for a chart.

Usage:
      notmar-to-gpx.rb [options] <chart_id>
      notmar-to-gpx.rb --start-date=2011-01-01 1236
where [options] are:
EOS

opt :start_date, "Start date (YYYY-MM-DD), default=2016-06-01", type: String, default: '2016-06-01'  
end

opts = Optimist::with_standard_exception_handling p do
  raise Optimist::HelpNeeded if ARGV.empty? # show help screen
  p.parse ARGV
end

# get charts notices
if ARGV[0].match(/^(\d)+$/)
  chart = ARGV[0].to_s
else
  puts "ERROR: chart id invalid"
  exit 2
end
# make sure raw_data folder exists
Dir.mkdir('raw_data') unless File.exists?('raw_data')

date1 = Date.strptime(opts[:start_date], '%Y-%m-%d')
filename = 'notmar_canada_' + chart.to_s + '_' + Date.today.to_s

url = "https://www.notmar.gc.ca/corrections-fr.php?chart-carte=" + chart + "&date1="+ date1.to_s + "&date2=" + Date.today.to_s
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
data = Net::HTTP.get_response(URI.parse(url))
if data.code == "200"
  page = Nokogiri::HTML(data.body)
else
  return
end
notices_raw = page.css('table')
File.open('raw_data/' + filename + '_extract.txt', 'w') { |file| file.write(notices_raw.to_s.delete("\t")) }

def verb_symbol(verb)
  # Symbole to use for OpenCPN
  # 'Hazard-Warning'
  # 'Symbol-Exclamation-Yellow'
  # 'Symbos-Spot-Blue'
  # 'wreck1'
  case verb
  when 'Coller'
    'Symbol-Spot-Blue'
  when 'Rayer'
    'Symbol-X-Large-Red'
  else
    'Symbol-Exclamation-Yellow'
  end
end

notes_to_file = File.open("#{filename}.log", 'w')
gpx = GPX::GPXFile.new
warnings = []

notices_raw.each do |notice_raw |
  verb = notice_raw.css('td')[2].text
  desc_raw = if notice_raw.css('td')[4].nil?
      notice_raw.css('td')[3].text
    else
      notice_raw.css('td')[4].text
    end
  this_notice = {
    date: Date.parse(notice_raw.css('td')[0].text),
    comment: verb + ' ' + notice_raw.css('td')[3].text.split("\n")[0].chomp,
    mpo: desc_raw.split('MPO(')[1].delete(")"),
    verb: verb
  }
  if desc_raw.split('M')[0].split(' ')[0].include?('°')
    coordinate = desc_raw.split('MPO')[0].sub(' ',', ')
    coordinate = coordinate.slice(0..(coordinate.index('W')))
    this_notice[:coord] = Geo::Coord.parse_dms(coordinate) rescue nil
  else
    this_notice[:location] = notice_raw.css('td')[4].text.split('M')[0]
  end
  if verb == 'Coller'
    this_notice[:url] = notice_raw.css('td').css('a').attr('href').value
    this_notice[:comment] << "\n" + this_notice[:url]
    notes_to_file.write (this_notice[:mpo] + ': ' + this_notice[:comment] + "\n")
  end
  if this_notice[:coord].nil?
    warnings << this_notice
  else
    icon = if this_notice[:comment].include? ("WK")
             'wreck1'
           else
             verb_symbol(verb)
           end
    gpx.waypoints << GPX::Waypoint.new({
      name: 'mpo:' + this_notice[:mpo],
      lat: this_notice[:coord].lat.to_f,
      lon: this_notice[:coord].lng.to_f,
      sym: icon,
      time: this_notice[:date],
      desc: I18n.transliterate(this_notice[:comment])})
    notes_to_file.write ( this_notice[:mpo] + ": import successful.\n")
  end
end
notes_to_file.write ("\n")
notes_to_file.write ("Waypoint(s) not created (errors):\n")
notes_to_file.write (JSON.pretty_generate(warnings))
notes_to_file.close
gpx.write("#{filename}.gpx")
