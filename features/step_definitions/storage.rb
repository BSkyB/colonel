When(/^I create a document$/) do
  @document = Document.new({text: "Hi!"})
end

When(/^I save it as "(.*?)" with email "(.*?)"$/) do |name, email|
  @document.save!({name: name, email: email})
end

Then(/^the document should have an id I can use later$/) do
  expect(@document.id).to be_a(String)
  expect(@document.id).to match(/^[a-f0-9]{32}$/)
end

Given(/^an existing document stored as "(.*?)" with content:$/) do |label, table|
  content = table.hashes.first
  document = Document.new(content)
  document.save!({name: 'Test', email: 'test@example.com'})

  # remember the id for the future
  @ids ||= {}
  @ids[label] = document.id
end

When(/^I open a document using stored id "(.*?)"$/) do |label|
  # use store id
  @document = Document.open(@ids[label])
end

Then(/^I should get content:$/) do |table|
  table.hashes.first.each do |key, value|
    expect(@document.content.send(key)).to eq(value)
  end
end
