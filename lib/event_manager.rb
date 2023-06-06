require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.delete('^0-9').to_s
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..10]
  else
    ''
  end
end

def peak_registration_hours(registration_hours)
  registration_hours_hash = Hash.new(0)
  registration_hours.reduce(registration_hours_hash) do |timestamps, timestamp|
    timestamp_hr = timestamp.split(':')[0]
    timestamps[timestamp_hr] += 1
    timestamps
  end
  max_hours_quantity = registration_hours_hash.values.max
  result = Hash.new(0)
  registration_hours_hash.each do |key, value|
    result[key] = value if value == max_hours_quantity
  end
  result
end

def peak_registration_days(registration_dates)
  registration_days_hash = Hash.new(0)
  registration_dates.reduce(registration_days_hash) do |dates, date|
    parsed_current_date = DateTime.strptime(date, '%m/%d/%Y')
    current_day_of_week = parsed_current_date.strftime('%A')
    dates[current_day_of_week] += 1
    dates
  end
  max_registrations_per_day = registration_days_hash.values.max
  result = Hash.new(0)
  registration_days_hash.each do |key, value|
    result[key] = value if value == max_registrations_per_day
  end
  result
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_hours = []
reg_days = []
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone_number = clean_phone_number(row[:homephone])

  reg_timestamp = row[:regdate]
  reg_days.push(reg_timestamp.split[0])
  reg_hours.push(reg_timestamp.split[1])

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

peak_reg_time = peak_registration_hours(reg_hours)
print "Peak registration hours are: \n"
peak_reg_time.each do |k, v|
  print "Hour: #{k}, frequency: #{v} times\n"
end

peak_reg_days = peak_registration_days(reg_days)
print "\nPeak registration days are: \n"
peak_reg_days.each do |k, v|
  print "Day: #{k}, frequency: #{v} times\n"
end

