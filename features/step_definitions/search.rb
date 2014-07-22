Given(/^the following documents:$/) do |table|
  table.hashes.each do |content|
    document = Document.new(content)
    document.save!({name: 'Test', email: 'test@example.com'})
  end
end

When(/^I list all documents$/) do
  @documents = Document.list
end

Then(/^I should get the following documents:$/) do |table|
  docs = @documents.each

  table.hashes.each do |content|
    doc = docs.next
    content.each do |key, val|
      expect(doc.content.get(key)).to eq(value)
    end
  end
end

