# == Schema Information
#
# Table name: public.data_files
#
#  id             :integer          not null, primary key
#  name           :string           not null
#  metadata       :jsonb            not null
#  customer_id    :integer          not null
#  file_type      :string           default("import"), not null
#  s3_bucket_name :string           not null
#  s3_file_name   :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  deleted_at     :datetime
#
# Indexes
#
#  index_data_files_on_customer_id     (customer_id)
#  index_data_files_on_lowercase_name  (lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#

# For storing a reference to a CSV/TSV/any-tabularly-formatted-file on S3, for the purpose of loading/unloading data to/from the DB
class DataFile < ApplicationRecord

  acts_as_paranoid

  auto_normalize

  # Validations

  validates :customer, :s3_bucket_name, :s3_file_name, presence: true

  FILE_TYPES = %w(import export).freeze

  validates :file_type, presence: true, inclusion: { in: FILE_TYPES }

  validate :metadata_not_null

  def metadata_not_null
    errors.add(:metadata, 'may not be null') unless metadata # {} is #blank?, hence this hair
  end

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  validate :supplied_s3_url_is_not_hosed

  def supplied_s3_url_is_not_hosed
    errors.add(:supplied_s3_url, "must be provided") if supplied_s3_url.blank? && s3_bucket_name.blank? && s3_file_name.blank?
    errors.add(:supplied_s3_url, "is not a valid S3 URL") if supplied_s3_url.present? && s3_bucket_name.blank? && s3_file_name.blank?
  end

  # Callbacks

  before_validation :parse_supplied_s3_url

  def parse_supplied_s3_url
    if supplied_s3_url.present?
      if (http_match = %r{\Ahttp(?:s)?://.+?/([-\w]+)/(.{10,})\Z}.match(supplied_s3_url))
        self.s3_bucket_name = http_match[1]
        self.s3_file_name = http_match[2]
      end
      if (s3_match = %r{\As3://([-\w]+)/(.{10,})\Z}.match(supplied_s3_url))
        self.s3_bucket_name = s3_match[1]
        self.s3_file_name = s3_match[2]
      end
    end
  end

  # Associations

  belongs_to :customer, inverse_of: :data_files

  has_many :transforms, inverse_of: :data_file
  has_many :workflows, through: :transforms

  # Scopes

  scope :sans_deleted, -> { where(deleted_at: nil) }

  # Instance Methods

  alias_attribute :to_s, :name

  attr_accessor :supplied_s3_url

  def s3_presigned_url
    @s3_presigned_url ||
      begin
        s3_bucket = self.class.s3.bucket(s3_bucket_name)
        s3_object = s3_bucket.object(s3_file_name)
        @s3_presigned_url = s3_object.presigned_url(:get) if s3_object.exists?
      end
  end

  def s3_public_url
    @s3_public_url ||
      begin
        s3_bucket = self.class.s3.bucket(s3_bucket_name)
        s3_object = s3_bucket.object(s3_file_name)
        @s3_public_url = s3_object.public_url if s3_object.exists?
      end
  end

  # FIXME - ADD METHOD FOR PROVIDING AN UPLOAD STREAM SYNC TO BE LOADED BY THE CLIENT FROM THE DB, TO CREATE AN S3 FILE THAT DOESN'T ALREADY EXIST
  #         THIS WILL REQUIRE ADDING AN EXTRA `"run_#{run.id}"` PARENT DIRECTORY TO THE SUPPLIED FILE NAME.  MEH.

  # Class Methods

  def self.s3
    @s3 ||= Aws::S3::Resource.new(region: 'us-west-2')
  end

end
