Given(/^an existing document with content:$/) do |table|
  content = table.hashes.first
  @document = Document.new(content)
  @document.save!({ name: 'Test', email: 'test@example.com' })
end

When(/^I change the content to:$/) do |table|
  content = table.hashes.first
  @document.content = content
end

When(/^I save the document$/) do
  @revision = @document.save!({ name: 'Test', email: 'test@example.com' })
end

Then(/^I should get a new revision with content:$/) do |table|
  expect(@revision.sha).to_not be_nil
end

Then(/^the previous revision should have content:$/) do |table|
  pending
end
