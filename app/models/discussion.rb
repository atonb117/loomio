class Discussion < ActiveRecord::Base

  PER_PAGE = 50
  paginates_per PER_PAGE

  include ReadableUnguessableUrls
  include Translatable
  include Searchable

  scope :archived, -> { where('archived_at is not null') }
  scope :published, -> { where(archived_at: nil, is_deleted: false) }

  scope :active_since, -> (time) { where('last_item_at > ?', time) }
  scope :last_comment_after, -> (time) { where('(last_comment_at IS NULL and discussions.created_at > :time) OR last_comment_at > :time', time: time) }
  scope :order_by_latest_comment_or_created_at, -> { order('CASE
                                                            WHEN last_comment_at IS NULL THEN discussions.created_at
                                                            ELSE last_comment_at END DESC') }

  scope :visible_to_public, -> { published.where(private: false) }
  scope :not_visible_to_public, -> { where(private: true) }
  scope :with_motions, -> { where("discussions.id NOT IN (SELECT discussion_id FROM motions WHERE id IS NOT NULL)") }
  scope :without_open_motions, -> { where("discussions.id NOT IN (SELECT discussion_id FROM motions WHERE id IS NOT NULL AND motions.closed_at IS NULL)") }
  scope :with_open_motions, -> { joins(:motions).merge(Motion.voting) }
  scope :joined_to_current_motion, -> { joins('LEFT OUTER JOIN motions ON motions.discussion_id = discussions.id AND motions.closed_at IS NULL') }

  scope :not_by_helper_bot, -> { where('author_id NOT IN (?)', User.helper_bots.pluck(:id)) }

  validates_presence_of :title, :group, :author, :group_id
  validate :private_is_not_nil
  validates :title, length: { maximum: 150 }
  validates_inclusion_of :uses_markdown, in: [true,false]
  validate :privacy_is_permitted_by_group

  is_translatable on: [:title, :description], load_via: :find_by_key!, id_field: :key
  has_paper_trail :only => [:title, :description]

  belongs_to :group, counter_cache: true
  belongs_to :author, class_name: 'User'
  belongs_to :user, foreign_key: 'author_id'
  has_many :motions, dependent: :destroy
  has_one :current_motion, -> { where('motions.closed_at IS NULL').order('motions.closed_at ASC') }, class_name: 'Motion'
  has_one :most_recent_motion, class_name: 'Motion', order: 'motions.created_at desc'
  has_many :votes, through: :motions
  has_many :comments, dependent: :destroy
  has_many :comment_likes, through: :comments, source: :comment_votes
  has_many :commenters, -> { uniq }, through: :comments, source: :user

  has_many :events, -> { includes :user }, as: :eventable, dependent: :destroy
  has_many :items, -> { includes(eventable: :user).order(created_at: :asc) }, class_name: 'Event'

  has_many :discussion_readers

  has_many :explicit_followers,
           -> { where('discussion_readers.following = ?', true) },
           through: :discussion_readers


  include PgSearch
  pg_search_scope :search, against: [:title, :description],
    using: {tsearch: {dictionary: "english"}}

  delegate :name, to: :group, prefix: :group
  delegate :name, to: :author, prefix: :author
  delegate :users, to: :group, prefix: :group
  delegate :full_name, to: :group, prefix: :group
  delegate :email, to: :author, prefix: :author
  delegate :name_and_email, to: :author, prefix: :author
  delegate :locale, to: :author

  def published_at
    created_at
  end

  def followers
    User.
      active.
      joins("LEFT OUTER JOIN discussion_readers dr ON (dr.user_id = users.id AND dr.discussion_id = #{id})").
      joins("LEFT OUTER JOIN memberships m ON (m.user_id = users.id AND m.group_id = #{group_id})").
      where('dr.following = TRUE OR (dr.following IS NULL AND m.following_by_default = TRUE)')
  end

  def followers_without_author
    followers.where('users.id != ?', author_id)
  end

  def group_members_not_following
    group.members.active.where('users.id NOT IN (?)', followers.pluck(:id))
  end

  def archive!
    return if is_archived?
    self.update_attribute(:archived_at, Time.now) and
      Group.update_counters(group_id, discussions_count: -1)
  end

  def is_archived?
    archived_at.present?
  end

  def closed_motions
    motions.closed
  end

  def last_collaborator
    return nil if originator.nil?
    User.find_by_id(originator.to_i)
  end

  def group_members_without_discussion_author
    group.users.where(User.arel_table[:id].not_eq(author_id))
  end

  def current_motion_closing_at
    current_motion.closing_at
  end

  alias_method :current_proposal, :current_motion

  def number_of_comments_since(time)
    comments.where('comments.created_at > ?', time).count
  end

  def viewed!
    Discussion.increment_counter(:total_views, id)
    self.total_views += 1
  end

  def participants
    participants = group.members.where(id: commenters.pluck(:id))
    participants << author
    participants += motion_authors
    participants.uniq
  end

  def motion_authors
    User.find(motions.pluck(:author_id))
  end

  def motion_can_be_raised?
    current_motion.blank?
  end

  def has_previous_versions?
    (previous_version && previous_version.id)
  end

  def last_versioned_at
    if has_previous_versions?
      previous_version.version.created_at
    else
      created_at
    end
  end

  def delayed_destroy
    self.update_attribute(:is_deleted, true)
    self.delay.destroy
  end


  def thread_item_created!(item)
    #update count and last_item_at
    self.items_count += 1
    self.last_item_at = item.created_at

    # update first and last sequence ids
    if self.first_sequence_id == 0
      self.first_sequence_id = item.sequence_id
    end
    self.last_sequence_id = item.sequence_id

    self.save!(validate: false)
  end

  def thread_item_destroyed!(destroyed_item)
    self.items_count -= 1

    if destroyed_item.sequence_id == first_sequence_id
      self.first_sequence_id = sequence_id_or_0(lookup_first_item)
    end

    if destroyed_item.sequence_id == last_sequence_id
      last_item = lookup_last_item
      self.last_sequence_id = sequence_id_or_0(last_item)
      self.last_item_at = last_item.try(:created_at)
    end

    self.save!(validate: false)

    discussion_readers.
      where('last_read_at <= ?', destroyed_item.created_at).
      each(&:reset_items_count!)

    true
  end

  def comment_created!(comment)
    self.comments_count += 1
    self.last_comment_at = comment.created_at

    self.save!(validate: false)
  end

  def comment_destroyed!(destroyed_comment)
    self.comments_count -= 1
    self.last_comment_at = lookup_last_comment.try(:created_at)

    self.save!(validate: false)

    discussion_readers.
      where('last_read_at <= ?', destroyed_comment.created_at).
      each(&:reset_comments_count!)
  end

  def public?
    !private
  end

  def inherit_group_privacy!
    if self[:private].nil? and group.present?
      self[:private] = group.discussion_private_default
    end
  end

  def last_activity_at
    last_item_at || created_at
  end

  private
  def lookup_first_item
    Event.where(discussion_id: id).
          where('sequence_id is not null').
          order("sequence_id asc").
          first
  end

  def lookup_last_item
    Event.where(discussion_id: id).
          where('sequence_id is not null').
          order('sequence_id desc').
          first
  end

  def lookup_last_comment
    comments.order("created_at asc").last
  end

  def sequence_id_or_0(item)
    item.try(:sequence_id) || 0
  end

  def private_is_not_nil
    errors.add(:private, "Please select a privacy") if self[:private].nil?
  end

  def privacy_is_permitted_by_group
    return unless group.present?
    if self.public? and group.private_discussions_only?
      errors.add(:private, "must be private in this group")
    end

    if self.private? and group.public_discussions_only?
      errors.add(:private, "must be public in this group")
    end
  end
end
