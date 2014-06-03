require 'spec_helper'
require 'pry'
require 'fileutils'

require 'support/sample_content'

describe "Stress test", live: true do
  let :index do
    DocumentIndex.new('tmp/integration_test')
  end

  before do
    Colonel.config.storage_path = 'tmp/integration_test'

    ContentItem.ensure_index!
    ContentItem.put_mapping!
  end

  after do
    FileUtils.rm_rf('tmp/integration_test')
  end

  it "should create a 100 documents without a hitch" do
    doc_ids = []
    published_ids = []
    archived_ids = []

    docs = (1..100).to_a.map do |i|
      info = {
        title: TITLES.sample(1).first,
        tags: TAGS.sample(5),
        slug: "#{SLUGS.sample(1).first}_#{i}",
        abstract: CONTENT.sample(1).first,
        body: CONTENT.sample(4).flatten.join("\n\n")
      }

      doc = ContentItem.new(info)
      doc.save!({name: "John Doe", email: "john@example.com"}, "Commit message")

      expect(doc.history('master').length).to eq(1)

      doc_ids << doc.id

      doc.body += CONTENT.sample(1).first
      doc.save!({name: "John Doe", email: "john@example.com"}, "Commit message")

      expect(doc.history('master').length).to eq(2)

      doc.tags += TAGS.sample(2)

      doc.save!({name: "John Doe", email: "john@example.com"}, "Commit message")

      expect(doc.history('master').length).to eq(3)

      doc
    end

    docs.sample(30).each do |doc|
      doc.promote!('master', 'published', {name: "John Doe", email: "john@example.com"}, "Published!")
      published_ids << doc.id

      expect(doc.history('published').length).to be >= 1
    end

    published_ids.each do |pid|
      doc = Document.open(pid, 'master')

      expect(doc).to have_been_promoted('published')
    end

    docs.sample(10).each do |doc|
      doc.promote!('master', 'archived', {name: "John Doe", email: "john@example.com"}, "Archived!")
      archived_ids << doc.id

      doc.save_in!('archived', {name: "John Doe", email: "john@example.com"}, "Commit message")
      expect(doc.history('archived').length).to be >= 1
    end

    archived_ids.each do |pid|
      doc = Document.open(pid, 'master')

      expect(doc).to have_been_promoted('archived')
    end

    docs.sample(50).each do |doc|
      doc.tags = doc.tags.sample(5)

      doc.save!({name: "John Doe", email: "john@example.com"}, "Another commit message")

      expect(doc.history('master').length).to eq(4)
    end

    docs.select {|d| !d.has_been_promoted?('published', d.revision) }.sample(20).each do |doc|
      doc.promote!('master', 'published', {name: "John Doe", email: "john@example.com"}, "Published (possibly again)!")
      expect(doc.history('published').length).to be >= 1
    end

    docs.sample(40).each do |doc|
      doc.title += " (updated)"

      doc.save!({name: "John Doe", email: "john@example.com"}, "Final save")
    end

    doc_ids.each do |id|
      doc = ContentItem.open(id)

      expect(doc.revision).to match(/[a-z0-9]{40}/)
    end

    published_ids.each do |id|
      doc = ContentItem.open(id)

      pub_rev = nil
      doc.history('master') do |c|
        if doc.has_been_promoted?('published', c[:rev])
          pub_rev = c[:rev]
          break
        end
      end

      expect(pub_rev).not_to be_nil
    end

    expect(index.documents.length).to eq(100)
    expect(index.documents.map{|d| d[:name] }.sort).to eq(doc_ids.sort)
  end
end
