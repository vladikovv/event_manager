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
  result = Hash.new(0)
  registration_hours.reduce(result) do |timestamps, timestamp|
    timestamp_hr = timestamp.split(':')[0]
    timestamps[timestamp_hr] += 1
    timestamps
  end
  max_hours_quantity = result.values.max
  peak_hours = Hash.new(0)
  result.each do |key, value|
    peak_hours[key] = value if value == max_hours_quantity
  end
  peak_hours
end

def peak_registration_days(registration_days)

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

