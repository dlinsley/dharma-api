require "mongoid"
require 'active_support/all'

#The MIT License (MIT)

#Copyright (c) 2015 Jason Lee

#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.


module Mongoid
  class Identity
    MAII_TABLE_NAME = 'mongoid.auto_increment_ids'.freeze

    class << self

      # Generate auto increment id
      # params:
      def generate_id(document)
        if AutoIncrementId.cache_enabled?
          cache_key = self.maii_cache_key(document)
          if ids = Mongoid::AutoIncrementId.cache_store.read(cache_key)
            cached_id = self.shift_id(ids, cache_key)
            return cached_id if !cached_id.blank?
          end
        end

        opts = {
          findAndModify: MAII_TABLE_NAME,
          query: { _id: document.collection_name },
          update: { '$inc' => { c: AutoIncrementId.seq_cache_size } },
          upsert: true,
          new: true
        }
        o = Mongoid.default_client.database.command(opts, {})

        last_seq = o.documents[0]['value']['c'].to_i

        if AutoIncrementId.cache_enabled?
          ids = ((last_seq - AutoIncrementId.seq_cache_size) + 1 .. last_seq).to_a
          self.shift_id(ids, cache_key)
        else
          last_seq
        end
      end

      def shift_id(ids, cache_key)
        return nil if ids.blank?
        first_id = ids.shift
        AutoIncrementId.cache_store.write(cache_key, ids)
        first_id
      end

      def maii_cache_key(document)
        "maii-seqs-#{document.collection_name}"
      end
    end
  end

  module Document
    ID_FIELD = '_id'.freeze

    def self.included(base)
      base.class_eval do
        # define Integer for id field
        Mongoid.register_model(self)
        field :_id, type: Integer, overwrite: true
      end
    end

    # hack id nil when Document.new
    def identify
      Identity.new(self).create
      nil
    end

    alias_method :super_as_document, :as_document
    def as_document
      result = super_as_document
      if result[ID_FIELD].blank?
        result[ID_FIELD] = Identity.generate_id(self)
      end
      result
    end
  end
end
