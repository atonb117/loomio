class DiscussionReaderSerializer < ActiveModel::Serializer
  embed :ids, include: true
  attributes :id,
             :discussion_id,
             :created_at,
             :updated_at,
             :last_read_at,
             :read_comments_count,
             :read_items_count,
             :following
end
