class Event < ApplicationRecord
  include EventState

  belongs_to :creator, class_name: 'User', foreign_key: 'user_id'
  belongs_to :category, class_name: 'Category', foreign_key: 'category_id'

  default_scope -> { order(date_and_time: :desc) }
  scope :title, -> title { where("title LIKE ?", title) }

  has_many :attendances, class_name: 'Attendance',
                         foreign_key: 'attended_event_id',
                         dependent: :destroy
  has_many :attendees, through: :attendances, source: :attendee

  before_create :create_slug
  before_validation :normalize_title

  validates_presence_of :user_id, :title, :venue, :address, :date_and_time, :category_id,
                        :description, :picture

  validates_length_of :title, :venue, maximum: 140
  validates_length_of :description, maximum: 1500
  validate :date_in_future

  mount_uploader :picture, ImageUploader
  validate :picture_size, :picture_dimensions

  geocoded_by :address
  after_validation :geocode

  def per_page
    self.per_page = 10
  end

  def to_param
    slug
  end

  private

  def create_slug
    self.slug = title.parameterize
  end

  def normalize_title
    self.title = title.downcase.mb_chars.titleize
  end

  def picture_size
    errors.add(:picture, 'should be less than 5 MB') if picture.size > 5.megabytes
  end

  def picture_dimensions
    image = MiniMagick::Image.open(picture.path)
    if image[:width] < 2160 && image[:height] < 1080
      errors.add :picture, 'should be at least 2160px x 1080px'
    end
  end

  def date_in_future
    errors.add :date_and_time, 'should be at least one day from now' if date_and_time <= Time.zone.now
  end
end
