When(/^I create a content item$/) do
  @item = ContentItem.new({text: "Hi!"})
end

When(/^I save it as "(.*?)" with email "(.*?)"$/) do |name, email|
  @item.save!({name: name, email: email})
end

Then(/^the item should have an id I can use later$/) do
  expect(@item.id).to be_a(String)
  expect(@item.id).to match(/^[a-f0-9]{32}$/)
end

Given(/^an existing content item stored as "(.*?)" with content:$/) do |label, table|
  content = table.hashes.first
  item = ContentItem.new(content)
  item.save!({name: 'Test', email: 'test@example.com'})

  # remember the id for the future
  @ids ||= {}
  @ids[label] = item.id
end

When(/^I open content item using stored id "(.*?)"$/) do |label|
  # use store id
  @item = ContentItem.open(@ids[label])
end

Then(/^I should get content:$/) do |table|
  table.hashes.first.each do |key, value|
    expect(@item.send(key)).to eq(value)
  end
end
