# db/setup.rb
# P2 CRITICAL FIX: Increase connection pool to match Puma threads

require 'pg'
require 'connection_pool'

# Database URL from environment
DATABASE_URL = ENV['DATABASE_URL'] || ENV['POSTGRES_URL'] || 'postgresql://localhost/meme_explorer_development'

# CRITICAL FIX: Pool size must be >= Puma max_threads (32) + buffer
# Previous: 25 connections for 32 threads = 7 requests will block
# Fixed: 35 connections (32 threads + 3 buffer for migrations/workers)
DB_POOL = ConnectionPool.new(size: 35, timeout: 5) do
  conn = PG.connect(DATABASE_URL)
  
  # Configure connection for optimal performance
  conn.exec("SET application_name = 'meme_explorer'")
  conn.exec("SET statement_timeout = '30s'") # Prevent runaway queries
  conn.exec("SET idle_in_transaction_session_timeout = '60s'")
  
  conn
end

# DB Wrapper class to make connection pool usage transparent
class DBWrapper
  def initialize(pool)
    @pool = pool
  end

  # Execute SQL and return all results.
  # If called inside a transaction block, reuses the transaction connection
  # to avoid pool deadlock.
  def execute(sql, params = [])
    sql, params = expand_array_params(sql, params)
    translated = translate_sql(sql)
    conn = Thread.current[:db_connection]
    if conn
      conn.exec_params(translated, params).map { |row| row }
    else
      @pool.with do |c|
        c.exec_params(translated, params).map { |row| row }
      end
    end
  end

  # Execute SQL and return first column of first row (like SQLite3's get_first_value)
  def get_first_value(sql, params = [])
    sql, params = expand_array_params(sql, params)
    translated = translate_sql(sql)
    conn = Thread.current[:db_connection]
    run_query = lambda do |c|
      result = c.exec_params(translated, params)
      return nil if result.ntuples == 0
      result[0].values.first
    end
    conn ? run_query.call(conn) : @pool.with { |c| run_query.call(c) }
  end

  # Execute an INSERT and return the new row's id (like SQLite3's last_insert_rowid).
  # Appends RETURNING id to the statement if not already present.
  def last_insert_row_id(sql = nil, params = [])
    if sql
      sql, params = expand_array_params(sql, params)
      translated = translate_sql(sql)
      translated += ' RETURNING id' unless translated =~ /RETURNING\s+id/i
      @pool.with do |conn|
        result = conn.exec_params(translated, params)
        result.ntuples > 0 ? result[0]['id'].to_i : nil
      end
    else
      # Legacy pattern: caller already ran execute(), now wants the id.
      @pool.with do |conn|
        result = conn.exec("SELECT lastval()")
        result[0]['lastval'].to_i
      end
    end
  end

  # Wrap a block in a PostgreSQL transaction.
  # Uses Thread.current[:db_connection] so nested DB.execute calls inside the
  # yielded block reuse the same connection instead of trying to check out a
  # second one from the pool (which would deadlock with timeout:5).
  def transaction
    # Re-entrant: if already in a transaction on this thread, just yield
    return yield if Thread.current[:db_connection]

    @pool.with do |conn|
      Thread.current[:db_connection] = conn
      conn.exec('BEGIN')
      begin
        yield
        conn.exec('COMMIT')
      rescue => e
        conn.exec('ROLLBACK')
        raise e
      ensure
        Thread.current[:db_connection] = nil
      end
    end
  end

  # For backwards compatibility with code that checks connection status
  def closed?
    false
  end

  private

  # Expand Array-valued params into individual placeholders.
  #
  # Allows callers to write:
  #   DB.execute("WHERE id IN (?)", [[1, 2, 3]])
  # which becomes:
  #   "WHERE id IN (?,?,?)" with params [1, 2, 3]
  #
  # Only bare ? placeholders outside string literals are expanded.
  # Non-array params are left unchanged.
  def expand_array_params(sql, params)
    return [sql, params] if params.none? { |p| p.is_a?(Array) }

    new_params  = []
    param_index = 0
    new_sql     = +''
    in_quote    = false
    i           = 0

    while i < sql.length
      ch = sql[i]

      if ch == "'" && !in_quote
        in_quote = true
        new_sql << ch
      elsif ch == "'" && in_quote
        if sql[i + 1] == "'"
          new_sql << "''"
          i += 2
          next
        end
        in_quote = false
        new_sql << ch
      elsif ch == '?' && !in_quote
        param = params[param_index]
        param_index += 1
        if param.is_a?(Array)
          # Replace single ? with ?,?,? and flatten the array into new_params
          new_sql << (['?'] * param.size).join(',')
          new_params.concat(param)
        else
          new_sql << '?'
          new_params << param
        end
      else
        new_sql << ch
      end

      i += 1
    end

    [new_sql, new_params]
  end

  # Translate SQLite-style SQL to PostgreSQL-compatible SQL.
  #
  # Handles:
  #   1. ? positional placeholders  →  $1, $2, $3, ...
  #      Skips ?s inside single-quoted string literals.
  #
  #   2. INSERT OR IGNORE INTO …    →  INSERT INTO … ON CONFLICT DO NOTHING
  #
  #   3. INSERT OR REPLACE INTO …   →  INSERT INTO … ON CONFLICT DO UPDATE SET …
  #      Parses the column list from the VALUES clause and generates
  #      SET col = EXCLUDED.col for every column.
  #
  #   4. datetime('now', '-N unit') →  NOW() - INTERVAL 'N unit'  (SQLite → PG)
  #      Also handles datetime('now') → NOW()
  #
  def translate_sql(sql)
    sql = sql.dup

    # Check flags BEFORE any substitution
    had_or_ignore  = sql =~ /INSERT\s+OR\s+IGNORE\s+INTO/i
    had_or_replace = sql =~ /INSERT\s+OR\s+REPLACE\s+INTO/i

    # ── INSERT OR IGNORE → INSERT … ON CONFLICT DO NOTHING ───────────────
    if had_or_ignore
      sql.gsub!(/INSERT\s+OR\s+IGNORE\s+INTO/i, 'INSERT INTO')
      sql = append_on_conflict_do_nothing(sql) unless sql =~ /ON\s+CONFLICT/i
    end

    # ── INSERT OR REPLACE → INSERT … ON CONFLICT DO UPDATE SET … ─────────
    if had_or_replace
      sql.gsub!(/INSERT\s+OR\s+REPLACE\s+INTO/i, 'INSERT INTO')
      sql = append_on_conflict_do_update(sql) unless sql =~ /ON\s+CONFLICT/i
    end

    # ── datetime('now', '-N unit') → NOW() - INTERVAL 'N unit' ──────────
    sql = translate_datetime(sql)

    # ── integer boolean literals → TRUE/FALSE for BOOLEAN columns ────────
    # Handles patterns like: col = 1, col = 0, SET col = 1, SET col = 0
    # Only applies to known boolean column names to avoid touching integer cols.
    sql = translate_boolean_literals(sql)

    # ── ? → $1, $2, … (skip placeholders inside string literals) ─────────
    sql = translate_placeholders(sql)

    sql
  end

  # Translate SQLite datetime() calls to PostgreSQL equivalents.
  #   datetime('now', '-N unit') → NOW() - INTERVAL 'N unit'
  #   datetime('now')            → NOW()
  #   datetime(column)           → column  (bare column ref — no-op in PG)
  def translate_datetime(sql)
    # datetime('now', '-N unit') or datetime("now", '-N unit')
    sql = sql.gsub(/datetime\s*\(\s*['"]now['"]\s*,\s*['"]\s*(-?\d+)\s+(\w+)\s*['"]\s*\)/i) do
      n    = $1.to_i.abs
      unit = $2
      if $1.to_i < 0
        "NOW() - INTERVAL '#{n} #{unit}'"
      else
        "NOW() + INTERVAL '#{n} #{unit}'"
      end
    end
    # datetime('now') with no offset
    sql = sql.gsub(/datetime\s*\(\s*['"]now['"]\s*\)/i, 'NOW()')
    # datetime(column_name) used as a cast — just strip the wrapper
    sql = sql.gsub(/datetime\s*\(\s*(\w+)\s*\)/i, '\1')
    sql
  end

  # Translate integer boolean literals (0/1) to TRUE/FALSE for known BOOLEAN columns.
  # PostgreSQL BOOLEAN columns reject integer literals; SQLite stored them as integers.
  #
  # Only rewrites for columns that are declared BOOLEAN in the schema:
  #   is_public, completed, two_factor_enabled, active, enabled
  # Columns like `liked`, `views`, `likes`, `shown_count` are INTEGER and kept as-is.
  BOOLEAN_COLUMNS = %w[
    is_public completed two_factor_enabled active enabled subscribed
    is_active is_enabled is_completed verified
  ].freeze

  def translate_boolean_literals(sql)
    BOOLEAN_COLUMNS.each do |col|
      # Match: col = 1, col = 0, SET col = 1, SET col = 0 (word-boundary safe)
      sql = sql.gsub(/\b(#{Regexp.escape(col)})\s*=\s*1\b/, '\1 = TRUE')
      sql = sql.gsub(/\b(#{Regexp.escape(col)})\s*=\s*0\b/, '\1 = FALSE')
    end
    sql
  end

  # Replace each bare ? with $N, skipping ?s inside single-quoted literals.
  def translate_placeholders(sql)
    result   = +''
    counter  = 0
    in_quote = false
    i        = 0

    while i < sql.length
      ch = sql[i]

      if ch == "'" && !in_quote
        in_quote = true
        result << ch
      elsif ch == "'" && in_quote
        # Handle escaped quote ('') inside a string
        if sql[i + 1] == "'"
          result << "''"
          i += 2
          next
        end
        in_quote = false
        result << ch
      elsif ch == '?' && !in_quote
        counter += 1
        result << "$#{counter}"
      else
        result << ch
      end

      i += 1
    end

    result
  end

  # Append "ON CONFLICT DO NOTHING" to an INSERT statement.
  def append_on_conflict_do_nothing(sql)
    sql.rstrip + ' ON CONFLICT DO NOTHING'
  end

  # Append "ON CONFLICT DO UPDATE SET col = EXCLUDED.col, …" by parsing the
  # column list out of the INSERT INTO tbl (col1, col2, …) VALUES … statement.
  def append_on_conflict_do_update(sql)
    # Extract column list: INSERT INTO tbl (col1, col2, ...) VALUES
    if sql =~ /INSERT\s+INTO\s+\w+\s*\(([^)]+)\)\s+VALUES/i
      columns = $1.split(',').map(&:strip)
      assignments = columns.map { |col| "#{col} = EXCLUDED.#{col}" }.join(', ')
      sql.rstrip + " ON CONFLICT DO UPDATE SET #{assignments}"
    else
      # Fallback: can't parse columns, use DO NOTHING to avoid crash
      sql.rstrip + ' ON CONFLICT DO NOTHING'
    end
  end
end

# Create wrapped DB instance
DB = DBWrapper.new(DB_POOL)

# Health check for connection pool
def self.check_db_health
  DB_POOL.with do |conn|
    result = conn.exec("SELECT 1 as healthy")
    result[0]['healthy'] == '1'
  end
rescue => e
  false
end

puts "✅ Database connection pool configured: 35 connections for 32 Puma threads"
