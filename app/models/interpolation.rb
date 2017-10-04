# == Schema Information
#
# Table name: interpolations
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  sql        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_interpolations_on_lowercase_name  (lower((name)::text)) UNIQUE
#  index_interpolations_on_lowercase_slug  (lower((slug)::text)) UNIQUE
#

# Unlike normal param-based imputations, the format of these in code begins and ends with a colon, e.g. `:impute_me:`
class Interpolation < ApplicationRecord

  auto_normalize except: :sql

  # Validations

  validates :sql, presence: true

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: { case_sensitive: false }

  validate :slug_validity

  def slug_validity
    if slug =~ /^[^a-z]/ || slug =~ /[^a-z0-9_]/ || slug =~ /_$/
      errors.add(:slug, "must start with a lowercase character, and otherwise be comprised only of lowercase characters, numbers, or underscores")
    end
  end

  # Callbacks

  before_destroy :bail_out_if_used

  def bail_out_if_used
    raise("You cannot nuke an Interpolation that's currently in use.") if used?
  end

  # Instance Methods

  def usage_count
    referencing_transforms.count + referencing_data_quality_reports.count
  end

  def used?
    usage_count > 0
  end

  def referencing_transforms
    referencing_objs(Transform)
  end

  def referencing_data_quality_reports
    referencing_objs(DataQualityReport)
  end

  def referencing_validations
    referencing_objs(Validation)
  end

  private def referencing_objs(klass)
    klass.where("sql LIKE '%:#{slug}:%'")
  end

end