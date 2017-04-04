class ExecutionPlan

  class << self

    def create(workflow)
      execution_plan = workflow.serialize_and_symbolize.tap do |including_plan_h|
        workflow.included_workflows.each do |included_workflow|
          included_plan_h = included_workflow.serialize_and_symbolize
          merge_workflow_data_quality_reports!(including_plan_h, included_plan_h)
          merge_transforms!(including_plan_h, included_plan_h)
        end
      end
      new(execution_plan)
    end

    def wrap(execution_plan_h)
      new(execution_plan_h)
    end

    private

    # NB: Side-effect!
    def merge_workflow_data_quality_reports!(including_plan_h, included_plan_h)
      including_plan_h[:workflow_data_quality_reports] ||= []
      included_plan_h[:workflow_data_quality_reports] ||= []
      if including_plan_h[:workflow_data_quality_reports].present? || included_plan_h[:workflow_data_quality_reports].present?
        including_plan_h[:workflow_data_quality_reports] += included_plan_h[:workflow_data_quality_reports]
      end
    end

    # NB: Side-effect!
    def merge_transforms!(including_plan_h, included_plan_h)
      including_plan_h[:ordered_transform_groups] ||= []
      included_plan_h[:ordered_transform_groups] ||= []
      if including_plan_h[:ordered_transform_groups].present? || included_plan_h[:ordered_transform_groups].present?
        num_iterations = [including_plan_h[:ordered_transform_groups].size, included_plan_h[:ordered_transform_groups].size].max - 1
        (0..num_iterations).each do |i|
          included_ordered_transform_groups = included_plan_h[:ordered_transform_groups][i]
          if included_ordered_transform_groups.present?
            including_plan_h[:ordered_transform_groups][i] ||= Set.new
            including_plan_h[:ordered_transform_groups][i] += included_ordered_transform_groups
          end
        end
      end
    end
  end

  attr_reader :execution_plan

  def initialize(execution_plan_h)
    @execution_plan = execution_plan_h
  end

  alias_method :to_hash, :execution_plan

  def transform_group(step_index)
    execution_plan[:ordered_transform_groups][step_index] if execution_plan.present?
  end

  def transform_group_transform_ids(step_index)
    transform_group(step_index)&.map { |h| h.fetch(:id, nil) }
  end

  def transform_plan(step_index:, transform_id:)
    transform_group(step_index)&.detect { |h| h[:id] == transform_id }&.deep_symbolize_keys
  end

  def workflow_data_quality_reports
    execution_plan[:workflow_data_quality_reports] if execution_plan.present?
  end

  def workflow_data_quality_report_plan(workflow_data_quality_report_id)
    workflow_data_quality_reports&.detect { |h| h[:id] == workflow_data_quality_report_id }&.symbolize_keys
  end

  def workflow_data_quality_report_ids
    workflow_data_quality_reports&.map { |h| h.fetch(:id, nil) }
  end

end