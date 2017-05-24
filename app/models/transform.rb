# == Schema Information
#
# Table name: public.transforms
#
#  id           :integer          not null, primary key
#  name         :string           not null
#  runner       :string           default("Sql"), not null
#  workflow_id  :integer          not null
#  sql          :text             not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  params       :jsonb
#  s3_file_name :string
#
# Indexes
#
#  index_transforms_on_lowercase_name  (lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (workflow_id => workflows.id)
#

class Transform < ApplicationRecord

  include Concerns::ParamsHelpers

  auto_normalize except: :sql

  # Validations

  validates :sql, :workflow, presence: true

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  validates :runner, presence: true, inclusion: { in: RunnerFactory::RUNNERS }

  JOINED_S3_FILE_RUNNERS = RunnerFactory::S3_FILE_RUNNERS.join(',').freeze
  S3_ATTRIBUTES_PRESENT_ERROR_MSG = "is required for runners of type: #{JOINED_S3_FILE_RUNNERS}".freeze

  validates :s3_file_name, presence: { message: S3_ATTRIBUTES_PRESENT_ERROR_MSG }, if: :s3_file_required?

  # Callbacks

  before_validation :clear_s3_attribute, unless: :s3_file_required?

  private def clear_s3_attribute
    self.s3_file_name = nil
  end

  before_validation :add_placeholder_sql, if: :auto_load?

  private def add_placeholder_sql
    self.sql = "-- To be dynamically generated by the AutoLoad Runner" unless sql.present?
  end

  RUNNER_TO_NAME_H = {
    "CopyFrom" => "LOAD",
    "CopyTo" => "UNLOAD"
  }

  before_validation :maybe_apply_runner_defaults, on: :create, if: :defaults_runner?

  private def maybe_apply_runner_defaults
    if runner&.in?(RunnerFactory::DEFAULTS_RUNNERS)
      runner.sub!('Default', '')
      if table_name = params&.fetch(:table_name)
        self.name = "#{RUNNER_TO_NAME_H[runner]} #{table_name}"
        if default_sql = workflow.send(:"default_#{runner.underscore}_sql")
          self.sql = default_sql
        end
        self.s3_file_name = "#{table_name}"
        if ext = workflow.send(:"default_#{runner.underscore}_s3_file_type")
          self.s3_file_name += ".#{ext.downcase}"
        end
      end
    end
  end

  before_validation :maybe_interpolate_s3_file_name

  def maybe_interpolate_s3_file_name
    unless runner&.in?(RunnerFactory::DEFAULTS_RUNNERS)
      if s3_file_name.present? && params.present?
        self.s3_file_name = self.class.interpolate(string: s3_file_name, params: params, quote_arrays: false)
      end
    end
  end

  # Associations

  belongs_to :workflow, inverse_of: :transforms

  has_many :workflow_configurations, through: :workflow

  has_many :prerequisite_dependencies, class_name: 'TransformDependency', foreign_key: :postrequisite_transform_id, dependent: :delete_all
  has_many :prerequisite_transforms, through: :prerequisite_dependencies, source: :prerequisite_transform

  has_many :postrequisite_dependencies, class_name: 'TransformDependency', foreign_key: :prerequisite_transform_id, dependent: :delete_all
  has_many :postrequisite_transforms, through: :postrequisite_dependencies, source: :postrequisite_transform

  has_many :transform_validations, inverse_of: :transform, dependent: :delete_all
  has_many :validations, through: :transform_validations

  # Scopes

  scope :importing, -> { where(runner: RunnerFactory::IMPORT_S3_FILE_RUNNERS) }

  scope :exporting, -> { where(runner: RunnerFactory::EXPORT_S3_FILE_RUNNERS) }

  scope :file_related, -> { where(runner: RunnerFactory::S3_FILE_RUNNERS) }

  scope :non_file_related, -> { where(runner: RunnerFactory::NON_S3_FILE_RUNNERS) }

  scope :independent, -> { where("NOT EXISTS (SELECT 1 FROM transform_dependencies WHERE postrequisite_transform_id = transforms.id)") }

  scope :dependent, -> { where("EXISTS (SELECT 1 FROM transform_dependencies WHERE postrequisite_transform_id = transforms.id)") }

  # Instance Methods

  concerning :Runners do

    def importing?
      runner&.in?(RunnerFactory::IMPORT_S3_FILE_RUNNERS)
    end

    def exporting?
      runner&.in?(RunnerFactory::EXPORT_S3_FILE_RUNNERS)
    end

    def s3_file_required?
      runner&.in?(RunnerFactory::S3_FILE_RUNNERS)
    end

    def auto_load?
      runner == 'AutoLoad'
    end

    def copy_from?
      runner == 'CopyFrom'
    end

    def defaults_runner?
      runner&.in?(RunnerFactory::DEFAULTS_RUNNERS)
    end

  end

  concerning :S3Files do

    def s3_import_file(workflow_config = nil)
      S3File.create('import', **s3_attributes(workflow_config)) if importing?
    end

    # Not currently used.  Probably unnecessary ... though, hmm, perhaps useful off the Run object and a Likely Transform for a quick local download?
    # def s3_export_file(run:, workflow_config: )
    #   S3File.create('export', **s3_attributes(workflow_config).merge(run: run)) if exporting?
    # end

    private def s3_attributes(workflow_config)
      attributes.with_indifferent_access.slice(:s3_file_name).tap do |h|
        h.merge!(workflow_config.attributes.with_indifferent_access.slice(:s3_region_name, :s3_bucket_name, :s3_file_path)) if workflow_config
      end.symbolize_keys
    end

  end

  # FIXME - The performance of this really sucks for a large number of Transforms for a given Workflow.
  #         There has to be an algorithmic way to get the "Sibling groups" starting from the leaf nodes and going up
  # FIXME - Copy/paste to Workflow model; DRY up sometime
  concerning :EligiblePrerequisiteTransforms do

    included do
      accepts_nested_attributes_for :prerequisite_transforms
    end

    # Any Transform that doesn't directly or indirectly have this Transform as a prerequisite is itself available as a prerequisite (and may already be such).
    # This is how we avoid cycles in the Transform Dependency graph.
    def available_prerequisite_transforms
      base_arel = Transform.where(workflow_id: workflow_id).order(:name)
      if new_record?
        base_arel.all
      else
        # This is grossly inefficient.  I tried to do it with SQL for the first level, and failed.  Oh well.  Refactor later.
        eligible_transforms = base_arel.where("id <> #{id}").all
        # Where's that graph DB when you need it?
        eligible_transforms.reject { |eligible_transform| already_my_postrequisite?(eligible_transform) }
      end
    end

    private

    def already_my_postrequisite?(transform)
      dependents = transform.prerequisite_transforms
      return false if dependents.empty?
      return true if dependents.include?(self)
      dependents.any? { |dependent_transform| already_my_postrequisite?(dependent_transform) }
    end

  end

end
