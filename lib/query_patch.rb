# $Id$
module RedmineHudson
  module Redmine
    module QueryPatch
      def self.included(base) #:nodoc:
        base.class_eval do

          unloadable

          def available_filters_with_redmine_hudson
            return @available_filters if @available_filters

            available_filters_without_redmine_hudson

            return @available_filters unless project

            job_conditions = "#{HudsonJob.table_name}.project_id = #{project.id}"

            @hudson_filters = []
            @hudson_filters <<
              HudsonQueryFilter.new("hudson_job",
                                    { :type => :list_optional, :order => @available_filters.size + 1,
                                      :values => HudsonJob.find(:all, :conditions => job_conditions, :order => "#{HudsonJob.table_name}.name").collect{|s| [s.name, s.id.to_s] }},
                                    HudsonBuild.table_name,
                                    "hudson_job_id")
            @hudson_filters <<
              HudsonQueryFilter.new("hudson_build",
                                    { :type => :integer, :order => @available_filters.size + 2 },
                                    HudsonBuild.table_name,
                                    "number")

            @hudson_filters.each do |filter|
              @available_filters[filter.name] = filter.available_values
            end
            return @available_filters
          end

         def sql_for_field_with_redmine_hudson(field, value, db_table, db_field, is_custom_filter)
           case field
           when "hudson_build"
             sql = "#{Issue.table_name}.id in"
             sql << "(select changesets_issues.issue_id from changesets_issues"
             sql << " where changesets_issues.changeset_id in"
             sql << "  (select #{Changeset.table_name}.id from #{Changeset.table_name}"
             sql << "   where #{Changeset.table_name}.repository_id = #{project.repository.id}"
             sql << "    and   #{Changeset.table_name}.revision in"
             sql << "     ( select #{HudsonBuildChangeset.table_name}.revision from #{HudsonBuildChangeset.table_name}"
             sql << "        where #{HudsonBuildChangeset.table_name}.hudson_build_id in"
             sql << "        ( select #{HudsonBuild.table_name}.id from #{HudsonBuild.table_name}"
             sql << "         where " + conditions_for( field, value )
             sql << "         and   #{HudsonBuild.table_name}.hudson_job_id in"
             sql << "          ( select #{HudsonJob.table_name}.id from #{HudsonJob.table_name}"
             sql << "            where #{HudsonJob.table_name}.project_id = #{project.id}"
             sql << "          )"
             sql << "       )"
             sql << "    )"
             sql << " )"
             sql << ")"
             return sql

           when "hudson_job"
             sql = "#{Issue.table_name}.id in"
             sql << "(select changesets_issues.issue_id from changesets_issues"
             sql << " where changesets_issues.changeset_id in"
             sql << "  (select #{Changeset.table_name}.id from #{Changeset.table_name}"
             sql << "   where #{Changeset.table_name}.repository_id = #{project.repository.id}"
             sql << "    and   #{Changeset.table_name}.revision in"
             sql << "     ( select #{HudsonBuildChangeset.table_name}.revision from #{HudsonBuildChangeset.table_name}"
             sql << "        where #{HudsonBuildChangeset.table_name}.hudson_build_id in"
             sql << "        ( select #{HudsonBuild.table_name}.id from #{HudsonBuild.table_name}"
             sql << "         where " + conditions_for( field, value )
             sql << "       )"
             sql << "    )"
             sql << " )"
             sql << ")"
             return sql
             
           else
              return sql_for_field_without_redmine_hudson(field, value, db_table, db_field, is_custom_filter)
           end
         end

         def conditions_for(field, value)
           retval = ""

           available_filters
           return retval unless @hudson_filters

           filter = @hudson_filters.detect {|hfilter| hfilter.name == field}
           return retval unless filter

           db_table = filter.db_table
           db_field = filter.db_field

           case operator_for field
           when "="
             retval = "#{db_table}.#{db_field} IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")"
           when "!"
             retval = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + "))"
           when "!*"
             retval = "#{db_table}.#{db_field} IS NULL"
             retval << " OR #{db_table}.#{db_field} = ''"
           when "*"
             retval = "#{db_table}.#{db_field} IS NOT NULL"
             retval << " AND #{db_table}.#{db_field} <> ''"
           when ">="
             retval = "#{db_table}.#{db_field} >= #{value.first.to_i}"
           when "<="
             retval = "#{db_table}.#{db_field} <= #{value.first.to_i}"
           when "!~"
             retval = "#{db_table}.#{db_field} NOT LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
           end
           return retval
         end

         alias_method_chain :available_filters, :redmine_hudson unless method_defined?(:available_filters_without_redmine_hudson)
         alias_method_chain :sql_for_field, :redmine_hudson unless method_defined?(:sql_for_field_without_redmine_hudson)
        end
      end
    end
  end
end