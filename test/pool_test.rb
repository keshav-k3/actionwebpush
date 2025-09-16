# frozen_string_literal: true

require "test_helper"

class PoolTest < Minitest::Test
  def setup
    ActionWebPush.configure do |config|
      config.pool_size = 5
      config.pool_timeout = 10
    end
  end

  def test_pool_creation
    pool = ActionWebPush::Pool.new(size: 3, timeout: 5)

    assert_equal 3, pool.size
    assert_equal 5, pool.timeout
  end

  def test_default_pool_configuration
    pool = ActionWebPush::Pool.new

    assert_equal 5, pool.size  # From configuration
    assert_equal 10, pool.timeout  # From configuration
  end

  def test_pool_executes_tasks
    pool = ActionWebPush::Pool.new(size: 2)
    results = []

    # Submit multiple tasks
    futures = 3.times.map do |i|
      pool.submit do
        sleep 0.1  # Simulate work
        results << "task_#{i}"
        "result_#{i}"
      end
    end

    # Wait for all tasks to complete
    completed_results = futures.map(&:value)

    assert_equal 3, results.length
    assert_equal ["result_0", "result_1", "result_2"], completed_results
  end

  def test_pool_handles_exceptions
    pool = ActionWebPush::Pool.new(size: 1)

    future = pool.submit do
      raise StandardError, "Test error"
    end

    assert_raises(StandardError) do
      future.value
    end
  end

  def test_pool_timeout_handling
    pool = ActionWebPush::Pool.new(size: 1, timeout: 1)

    future = pool.submit do
      sleep 2  # Longer than timeout
      "completed"
    end

    # Should timeout
    assert_raises(Timeout::Error) do
      future.value
    end
  end

  def test_pool_shutdown
    pool = ActionWebPush::Pool.new(size: 2)

    assert pool.running?

    pool.shutdown

    refute pool.running?
  end

  def test_pool_graceful_shutdown
    pool = ActionWebPush::Pool.new(size: 2)
    results = []

    # Submit tasks
    futures = 2.times.map do |i|
      pool.submit do
        sleep 0.1
        results << "task_#{i}"
      end
    end

    # Shutdown gracefully (wait for running tasks)
    pool.shutdown(timeout: 5)

    # All tasks should have completed
    assert_equal 2, results.length
  end

  def test_pool_force_shutdown
    pool = ActionWebPush::Pool.new(size: 2)

    # Submit long-running task
    pool.submit do
      sleep 10
      "never_completed"
    end

    # Force shutdown immediately
    pool.shutdown(force: true)

    refute pool.running?
  end

  def test_pool_rejects_tasks_when_shutdown
    pool = ActionWebPush::Pool.new(size: 1)
    pool.shutdown

    assert_raises(ActionWebPush::Pool::ShutdownError) do
      pool.submit { "task" }
    end
  end

  def test_pool_statistics
    pool = ActionWebPush::Pool.new(size: 2)

    # Submit tasks
    3.times do |i|
      pool.submit do
        sleep 0.01
        "task_#{i}"
      end
    end

    stats = pool.statistics

    assert_kind_of Hash, stats
    assert stats.key?(:submitted_tasks)
    assert stats.key?(:completed_tasks)
    assert stats.key?(:active_threads)
    assert stats.key?(:queue_length)
  end

  def test_pool_with_priority_queue
    pool = ActionWebPush::Pool.new(size: 1, priority_queue: true)
    results = []

    # Submit tasks with different priorities
    low_priority = pool.submit(priority: 1) do
      sleep 0.01
      results << "low"
    end

    high_priority = pool.submit(priority: 10) do
      results << "high"
    end

    medium_priority = pool.submit(priority: 5) do
      results << "medium"
    end

    [low_priority, high_priority, medium_priority].each(&:value)

    # Higher priority tasks should execute first
    assert_equal ["high", "medium", "low"], results
  end

  def test_pool_load_balancing
    pool = ActionWebPush::Pool.new(size: 3)
    thread_ids = []

    # Submit many tasks
    futures = 9.times.map do |i|
      pool.submit do
        thread_ids << Thread.current.object_id
        "task_#{i}"
      end
    end

    futures.each(&:value)

    # Tasks should be distributed across threads
    unique_threads = thread_ids.uniq
    assert unique_threads.length > 1, "Tasks should be distributed across multiple threads"
  end

  def test_pool_health_check
    pool = ActionWebPush::Pool.new(size: 2)

    assert pool.healthy?

    # Simulate unhealthy state
    pool.instance_variable_get(:@executor).stub(:shutdown?, true) do
      refute pool.healthy?
    end
  end

  def test_pool_resize
    pool = ActionWebPush::Pool.new(size: 2)

    assert_equal 2, pool.size

    pool.resize(5)

    assert_equal 5, pool.size
  end

  def test_pool_metrics_collection
    pool = ActionWebPush::Pool.new(size: 2)

    # Submit some tasks
    5.times do |i|
      pool.submit { "task_#{i}" }
    end

    metrics = pool.collect_metrics

    assert_kind_of Hash, metrics
    assert metrics.key?(:total_tasks)
    assert metrics.key?(:successful_tasks)
    assert metrics.key?(:failed_tasks)
    assert metrics.key?(:average_execution_time)
  end
end