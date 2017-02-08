class DataQualityReportJob < ApplicationJob

  def perform(run_id:, step_id:)

    run = Run.find(run_id)

    data_quality_report_h = run.data_quality_report_plan(step_id)
    data_quality_report_runner = RunnerFactory.runner_for('DataQualityReport')

    run.with_run_step_log_tracking(step_type: "data_quality_report", step_id: step_id) do
      data_quality_report_runner.run(run: run, plan_h: data_quality_report_h)
    end

  end
end
