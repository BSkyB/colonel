require 'fileutils'

When(/^I dump documents into a file named "(.*?)"$/) do |filename|
  index = DocumentIndex.new(Colonel.config.storage_path)
  docs = index.documents.map { |doc| Document.open(doc[:name]) }

  File.open(filename, "w") do |f|
    Serializer.generate(docs, f)
  end
end

When(/^I remove all files in the storag$/) do
  FileUtils.rm_rf Colonel.config.storage_path
end

When(/^I restore documents from a file named "(.*?)"$/) do |filename|
  File.open(filename, "r") do |f|
    Serializer.load(f)
  end
end

When(/^I list all documents in the document index$/) do
  index = DocumentIndex.new(Colonel.config.storage_path)
  @documents = index.documents.map { |doc| Document.open(doc[:name]) }
end
