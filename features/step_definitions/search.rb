Given(/^the following documents:$/) do |table|
  table.hashes.each do |content|
    document = Document.new(content)
    document.save!({name: 'Test', email: 'test@example.com'})
  end

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end

When(/^I list all documents$/) do
  @documents = Document.list
end

Then(/^I should get the following documents:$/) do |table|
  docs = @documents.map do |doc|
    doc.content
  end

  table.hashes.each do |content|
    expect(docs.any? do |d|
      content.all? do |key, value|
        d.get(key) == value
      end
    end).to be(true), "Didin't find #{content.inspect} in #{docs.inspect}"
  end
end

Given(/^the following documents promoted to "(.*?)":$/) do |status, table|
  table.hashes.each do |content|
    document = Document.new(content)
    document.save!({name: 'Test', email: 'test@example.com'})
    document.promote!('master', status, {name: 'Test', email: 'test@example.com'})
  end

  ElasticsearchProvider.es_client.indices.refresh index: '_all'
end

When(/^I list all "(.*?)" documents$/) do |arg1|
  @documents = Document.list(state: 'published')
end
