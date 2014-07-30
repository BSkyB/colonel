When(/^I run the following command:$/) do |string|
  out = `#{string}`
end

Given(/^the following \.colonel file:$/) do |string|
  File.open(File.join(Dir.pwd, ".colonel"), "w") do |f|
    f.write(string)
  end
end
