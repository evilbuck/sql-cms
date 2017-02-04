# == Schema Information
#
# Table name: public.workflows
#
#  id                      :integer          not null, primary key
#  name                    :string           not null
#  slug                    :string           not null
#  customer_id             :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  copied_from_workflow_id :integer
#
# Indexes
#
#  index_workflows_on_copied_from_workflow_id  (copied_from_workflow_id)
#  index_workflows_on_customer_id              (customer_id)
#  index_workflows_on_lowercase_name           (lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (copied_from_workflow_id => workflows.id)
#  fk_rails_...  (customer_id => customers.id)
#

class Workflow < ApplicationRecord

  # This class represents a particular configuration of an SQL Workflow at a particular point in time.
  # Its name and slug case-insensitively unique, here and in the DB.

  include Concerns::SqlHelpers

  include Concerns::SqlSlugs

  auto_normalize

  # Validations

  validates :customer, presence: true

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  validates :slug, presence: true, uniqueness: { case_sensitive: false }

  validate :slug_valid_sql_identifier

  def slug_valid_sql_identifier
    errors.add(:slug, "Is not a valid SQL identifier") unless slug =~ /^[a-z_]([a-z0-9_])*$/
  end

  # Associations

  belongs_to :customer, inverse_of: :workflows

  belongs_to :copied_from_workflow, class_name: 'Workflow', inverse_of: :copied_to_workflows
  has_many :copied_to_workflows, class_name: 'Workflow', foreign_key: :copied_from_workflow_id, inverse_of: :copied_from_workflow, dependent: :nullify

  has_many :notifications, inverse_of: :workflow, dependent: :delete_all
  has_many :notified_users, through: :notifications, source: :user

  has_many :transforms, inverse_of: :workflow, dependent: :destroy

  has_many :data_quality_reports, inverse_of: :workflow, dependent: :delete_all

  has_many :runs, inverse_of: :workflow, dependent: :destroy

  # Instance Methods

  def to_s
    "#{customer.slug}_#{slug}".freeze
  end

  accepts_nested_attributes_for :notified_users

  def emails_to_notify
    @emails_to_notify ||= notified_users.pluck(:email)
  end

  def ordered_transform_groups
    # FIXME - VALIDATE GRAPH IS ACYCLICAL HERE.  (IT CAN ONLY BECOME SO IN VIRTUE OF A RACE CONDITION VIA THE UI, WHICH IS QUITE UNLIKELY GIVEN THE SMALL USER BASE.)

    unused_transform_ids = transforms.map(&:id)
    groups_arr = []

    independent_transforms = transforms.where("NOT EXISTS (SELECT 1 FROM transform_dependencies WHERE prerequisite_transform_id = transforms.id) AND NOT EXISTS (SELECT 1 FROM transform_dependencies WHERE postrequisite_transform_id = transforms.id)")
    groups_arr << independent_transforms
    unused_transform_ids -= independent_transforms.map(&:id)

    while !unused_transform_ids.empty?
      next_group = next_transform_group(used_transform_ids: groups_arr.flat_map(&:id), unused_transform_ids:  unused_transform_ids)
      groups_arr << next_group
      unused_transform_ids -= next_group.map(&:id)
    end

    groups_arr
  end

  private

  def next_transform_group(used_transform_ids:, unused_transform_ids:)
    
  end

end
