class Event < ApplicationRecord
  include EventState
  include Filterable

  belongs_to :creator, class_name: 'User', foreign_key: 'user_id', counter_cache: :created_events_count
  belongs_to :category, class_name: 'Category', foreign_key: 'category_id'

  has_many :attendances, class_name: 'Attendance',
                         foreign_key: 'attending_event_id',
                         dependent: :destroy
  has_many :attendees, through: :attendances, source: :attendee

  scope :by_category, ->(category_id) { where category_id: category_id }
  scope :by_title, ->(title) { where("lower(title) LIKE ? OR lower(description) LIKE ?", "%#{title.downcase}%", "%#{title.downcase}%") }
  scope :start_date, ->(start_date) { where('date_and_time >= ?', start_date) }
  scope :end_date, ->(end_date) { where('date_and_time <= ?', end_date) }
  scope :by_date, -> { order(date_and_time: :desc) }
  scope :by_attendees_count, -> { order(attendees_count: :desc) }

  before_validation :normalize_title
  before_validation :create_slug

  validates_presence_of :user_id, :title, :venue, :address, :date_and_time,
                        :category_id, :description, :picture

  validates_length_of :title, :venue, maximum: 80
  validates_length_of :description, maximum: 2000
  validate :date_in_future

  mount_uploader :picture, ImageUploader
  validate :picture_size

  geocoded_by :address
  after_validation :geocode, if: ->(obj){ obj.address.present? and obj.address_changed? }

  def per_page
    self.per_page = 15
  end

  def create_slug
    self.slug = title.parameterize
  end

  def self.popular_categories
    Event.includes(:category).upcoming.max_by(7) { |event| event.attendees_count }.map(&:category).uniq
  end

  private

  def normalize_title
    self.title = title.downcase.mb_chars.titleize
  end

  def picture_size
    errors.add(:picture, 'should be less than 10 MB') if picture.size > 10.megabytes
  end

  def date_in_future
    errors.add :date_and_time, 'should be at least one day from now' if date_and_time <= Time.zone.now
  end
end
