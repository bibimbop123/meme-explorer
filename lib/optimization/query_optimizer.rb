# frozen_string_literal: true

# SQL Query Optimizer
# Optimizes common query patterns
# Created: July 22, 2026

module QueryOptimizer
  class << self
    # Optimize SELECT queries with proper indexing hints
    def optimize_select(table, conditions = {}, options = {})
      query = "SELECT "
      query += options[:select] || '*'
      query += " FROM #{table}"
      
      # Add index hints for PostgreSQL
      if options[:use_index]
        query += " /*+ IndexScan(#{table} #{options[:use_index]}) */"
      end
      
      unless conditions.empty?
        where_clauses = conditions.map { |k, v| "#{k} = ?" }
        query += " WHERE #{where_clauses.join(' AND ')}"
      end
      
      # Limit results for better performance
      query += " LIMIT #{options[:limit] || 1000}"
      
      query
    end

    # Batch insert for better performance
    def batch_insert(table, records, batch_size = 1000)
      return 0 if records.empty?
      
      inserted = 0
      records.each_slice(batch_size) do |batch|
        columns = batch.first.keys.join(', ')
        values_placeholder = batch.map { |_|
          "(#{Array.new(batch.first.size, '?').join(', ')})"
        }.join(', ')
        
        query = "INSERT INTO #{table} (#{columns}) VALUES #{values_placeholder}"
        values = batch.flat_map(&:values)
        
        DB.execute(query, *values)
        inserted += batch.size
      end
      
      inserted
    end

    # Optimize JOIN queries
    def optimize_join(base_table, join_table, join_condition, options = {})
      # Use INNER JOIN by default (faster than LEFT JOIN)
      join_type = options[:join_type] || 'INNER JOIN'
      
      query = "SELECT * FROM #{base_table} "
      query += "#{join_type} #{join_table} ON #{join_condition}"
      
      if options[:where]
        query += " WHERE #{options[:where]}"
      end
      
      query
    end

    # Count optimization (use approximate counts for large tables)
    def fast_count(table, exact: false)
      if exact
        DB.execute("SELECT COUNT(*) FROM #{table}").first['count']
      else
        # Use PostgreSQL statistics for fast approximate count
        DB.execute(
          "SELECT reltuples::bigint FROM pg_class WHERE relname = ?",
          table
        ).first['reltuples']
      end
    end
  end
end
