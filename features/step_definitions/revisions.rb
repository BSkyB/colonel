Given(/^an existing document with content:$/) do |table|
  content = table.hashes.first
  @document = Document.new(content)
  @first_revision = @document.save!({ name: 'Test', email: 'test@example.com' })
end

When(/^I change the content to:$/) do |table|
  content = table.hashes.first
  @document.content = content
end

When(/^I save the document$/) do
  @second_revision = @document.save!({ name: 'Test', email: 'test@example.com' })
end

Then(/^I should get a new revision with content:$/) do |table|
  expect(@second_revision).to be_a(Revision)
  expect(@first_revision.id).not_to eq(@second_revision.id)

  table.hashes.first.each do |key, value|
    expect(@second_revision.content.get(key)).to eq(value)
  end
end

Then(/^the previous revision should have content:$/) do |table|
  previous = @second_revision.previous

  expect(previous).to be_a(Revision)
  expect(previous.id).to eq(@first_revision.id)

  table.hashes.first.each do |key, value|
    expect(previous.content.get(key)).to eq(value)
  end
end

Given(/^an existing document with revisions with content:$/) do |table|
  # table is a Cucumber::Ast::Table
  @document = Document.new(nil)
  table.hashes.each do |content|
    @document.content = content
    @document.save!({ name: 'Test', email: 'test@example.com' })
  end
end

When(/^I get the document history$/) do
  @history = @document.history
end

Then(/^I should be able to iterate through revisions with content:$/) do |table|
  expect(@history).to be_a(Enumerator)

  expected_revision = table.hashes.each

  @history.each do |revision|
    expect(revision).to be_a(Revision)

    expected_revision.next.each do |key, value|
      expect(revision.content.get(key)).to eq(value)
    end
  end
end
