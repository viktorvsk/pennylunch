class DropLegacyTaskRuns < ActiveRecord::Migration[8.1]
  def change
    drop_table :maintenance_tasks_runs, if_exists: true do |t|
      t.text :arguments
      t.text :backtrace
      t.datetime :created_at, null: false
      t.string :cursor
      t.boolean :cursor_is_json, default: false, null: false
      t.datetime :ended_at
      t.string :error_class
      t.string :error_message
      t.string :job_id
      t.integer :lock_version, default: 0, null: false
      t.text :metadata
      t.datetime :started_at
      t.string :status, default: "enqueued", null: false
      t.string :task_name, null: false
      t.bigint :tick_count, default: 0, null: false
      t.bigint :tick_total
      t.float :time_running, default: 0.0, null: false
      t.datetime :updated_at, null: false
      t.index [ :task_name, :status, :created_at ], name: :index_maintenance_tasks_runs, order: { created_at: :desc }
    end
  end
end
