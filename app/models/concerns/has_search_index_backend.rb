# Copyright (C) 2012-2016 Zammad Foundation, http://zammad-foundation.org/
module HasSearchIndexBackend
  extend ActiveSupport::Concern

  included do
    after_create  :search_index_update
    after_update  :search_index_update
    after_touch   :search_index_update
    after_destroy :search_index_destroy
  end

=begin

update search index, if configured - will be executed automatically

  model = Model.find(123)
  model.search_index_update

=end

  def search_index_update
    return if ignore_search_indexing?(:update)

    # start background job to transfer data to search index
    return if !SearchIndexBackend.enabled?
    Delayed::Job.enqueue(BackgroundJobSearchIndex.new(self.class.to_s, id))
  end

=begin

delete search index object, will be executed automatically

  model = Model.find(123)
  model.search_index_destroy

=end

  def search_index_destroy
    return if ignore_search_indexing?(:destroy)
    SearchIndexBackend.remove(self.class.to_s, id)
  end

=begin

collect data to index and send to backend

  ticket = Ticket.find(123)
  result = ticket.search_index_update_backend

returns

  result = true # false

=end

  def search_index_update_backend
    # fill up with search data
    attributes = search_index_attribute_lookup
    return if !attributes

    # update backend
    SearchIndexBackend.add(self.class.to_s, attributes)
  end

=begin

get data to store in search index

  ticket = Ticket.find(123)
  result = ticket.search_index_data

returns

  result = {
    attribute1: 'some value',
    attribute2: ['value 1', 'value 2'],
    ...
  }

=end

  def search_index_data
    attributes = {}
    %w(name note).each { |key|
      next if !self[key]
      next if self[key].respond_to?('empty?') && self[key].empty?
      attributes[key] = self[key]
    }
    return if attributes.empty?
    attributes
  end

  def ignore_search_indexing?(_action)
    false
  end

  # methods defined here are going to extend the class, not the instance of it
  class_methods do

=begin

serve methode to ignore model attributes in search index

class Model < ApplicationModel
  include HasSearchIndexBackend
  search_index_attributes_ignored :password, :image
end

=end

    def search_index_attributes_ignored(*attributes)
      @search_index_attributes_ignored = attributes
    end

=begin

reload search index with full data

  Model.search_index_reload

=end

    def search_index_reload
      tolerance       = 5
      tolerance_count = 0
      all.order('created_at DESC').each { |item|
        next if item.ignore_search_indexing?(:destroy)
        begin
          item.search_index_update_backend
        rescue => e
          logger.error "Unable to send #{item.class}.find(#{item.id}) backend: #{e.inspect}"
          tolerance_count += 1
          raise "Unable to send #{item.class}.find(#{item.id}) backend: #{e.inspect}" if tolerance_count == tolerance
        end
      }
    end
  end
end
