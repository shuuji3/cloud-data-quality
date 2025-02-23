-- Copyright 2022 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

{% macro validate_simple_rule(rule_id, rule_configs, rule_binding_id, column_name, fully_qualified_table_name, include_reference_columns, configs) -%}
  SELECT
    CURRENT_TIMESTAMP() AS _internal_execution_ts,
    '{{ rule_binding_id }}' AS _internal_rule_binding_id,
    '{{ rule_id }}' AS _internal_rule_id,
    '{{ fully_qualified_table_name }}' AS _internal_table_id,
    '{{ column_name }}' AS _internal_column_id,
    data.{{ column_name }} AS _internal_column_value,
{% if rule_configs.get("dimension") %}
    '{{ rule_configs.get("dimension") }}' AS _internal_dimension,
{% else %}
    CAST(NULL AS STRING) AS _internal_dimension,
{% endif %}
    CASE
{% if rule_configs.get("rule_type") == "NOT_NULL" %}
      WHEN {{ rule_configs.get("rule_sql_expr") }} THEN TRUE
{% else %}
      WHEN {{ column_name }} IS NULL THEN CAST(NULL AS BOOLEAN)
      WHEN {{ rule_configs.get("rule_sql_expr") }} THEN TRUE
{% endif %}
    ELSE
      FALSE
    END AS _internal_simple_rule_row_is_valid,
{% if rule_configs.get("rule_type") == "NOT_NULL" %}
    TRUE AS _internal_skip_null_count,
{% else %}
    FALSE AS _internal_skip_null_count,
{% endif %}
    CAST(NULL AS INT64) AS _internal_complex_rule_validation_errors_count,
    CAST(NULL AS BOOLEAN) AS _internal_complex_rule_validation_success_flag,
    r"""{{ configs.get(rule_binding_id ~ '_' ~ rule_id ~ '_failed_records_sql_string') }}"""
    AS _internal_failed_records_query,
  {% if include_reference_columns|length %}
    {% set include_reference_columns_string = "data."~include_reference_columns|join(",data.") %}
    to_json(struct({{include_reference_columns_string}})) AS include_reference_columns_json,
  {% else %}
    CAST(NULL AS JSON) AS include_reference_columns_json,
  {% endif %}
  FROM
    zero_record
  LEFT JOIN
    data
  ON
    zero_record._internal_rule_binding_id = data._internal_rule_binding_id
{% endmacro -%}

{% macro validate_complex_rule(rule_id, rule_configs, rule_binding_id, column_name, fully_qualified_table_name, configs) -%}
  SELECT
    CURRENT_TIMESTAMP() AS _internal_execution_ts,
    '{{ rule_binding_id }}' AS _internal_rule_binding_id,
    '{{ rule_id }}' AS _internal_rule_id,
    '{{ fully_qualified_table_name }}' AS _internal_table_id,
    CAST(NULL AS STRING) AS _internal_column_id,
    NULL AS _internal_column_value,
{% if rule_configs.get("dimension") %}
    '{{ rule_configs.get("dimension") }}' AS _internal_dimension,
{% else %}
    CAST(NULL AS STRING) AS _internal_dimension,
{% endif %}
    CAST(NULL AS BOOLEAN) AS _internal_simple_rule_row_is_valid,
    TRUE AS _internal_skip_null_count,
    custom_sql_statement_validation_errors._internal_complex_rule_validation_errors_count AS _internal_complex_rule_validation_errors_count,
    CASE
      WHEN custom_sql_statement_validation_errors._internal_complex_rule_validation_errors_count IS NULL THEN TRUE
      WHEN custom_sql_statement_validation_errors._internal_complex_rule_validation_errors_count = 0 THEN TRUE
      ELSE FALSE
    END AS _internal_complex_rule_validation_success_flag,
    r"""{{ configs.get(rule_binding_id ~ '_' ~ rule_id ~ '_failed_records_sql_string') }}"""
    AS _internal_failed_records_query,
    CAST(NULL AS JSON) AS include_reference_columns_json,
  FROM
    zero_record
  LEFT JOIN
    (
      SELECT
         *,
        '{{ rule_binding_id }}' AS _rule_binding_id,
        COUNT(*) OVER() AS _internal_complex_rule_validation_errors_count,
      FROM (
      {{ rule_configs.get("rule_sql_expr") }}
      ) custom_sql
    ) custom_sql_statement_validation_errors
  ON
    zero_record._internal_rule_binding_id = custom_sql_statement_validation_errors._rule_binding_id
{% endmacro -%}


{% macro validate_simple_rule_failed_records_query(rule_id, rule_configs, rule_binding_id, column_name, fully_qualified_table_name, include_reference_columns) -%}
  SELECT
    '{{ rule_binding_id }}' AS rule_binding_id,
    '{{ rule_id }}' AS _internal_rule_id,
    '{{ fully_qualified_table_name }}' AS _internal_table_id,
    '{{ column_name }}' AS _internal_column_id,
    data.{{ column_name }} AS _internal_column_value,
    {% for ref_column_name in include_reference_columns %}
        data.{{ ref_column_name }} AS _internal_{{ ref_column_name }},
    {%- endfor -%}
{% if rule_configs.get("dimension") %}
    '{{ rule_configs.get("dimension") }}' AS _internal_dimension,
{% else %}
    CAST(NULL AS STRING) AS _internal_dimension,
{% endif %}
    CASE
{% if rule_configs.get("rule_type") == "NOT_NULL" %}
      WHEN {{ rule_configs.get("rule_sql_expr") }} THEN TRUE
{% else %}
      WHEN {{ column_name }} IS NULL THEN CAST(NULL AS BOOLEAN)
      WHEN {{ rule_configs.get("rule_sql_expr") }} THEN TRUE
{% endif %}
    ELSE
      FALSE
    END AS _internal_simple_rule_row_is_valid,
{% if rule_configs.get("rule_type") == "NOT_NULL" %}
    TRUE AS _internal_skip_null_count,
{% else %}
    FALSE AS _internal_skip_null_count,
{% endif %}
    CAST(NULL AS INT64) AS complex_rule_validation_errors_count,
    CAST(NULL AS BOOLEAN) AS _internal_complex_rule_validation_success_flag,
  FROM
    zero_record
  LEFT JOIN
    data
  ON
    zero_record.rule_binding_id = data.rule_binding_id
{% endmacro -%}

{% macro validate_complex_rule_failed_records_query(rule_id, rule_configs, rule_binding_id, column_name, fully_qualified_table_name) -%}
  SELECT
    '{{ rule_binding_id }}' AS rule_binding_id,
    '{{ rule_id }}' AS _internal_rule_id,
    '{{ fully_qualified_table_name }}' AS _internal_table_id,
    CAST(NULL AS STRING) AS _internal_column_id,
    NULL AS _internal_column_value,
    custom_sql_statement_validation_errors,
{% if rule_configs.get("dimension") %}
    '{{ rule_configs.get("dimension") }}' AS _internal_dimension,
{% else %}
    CAST(NULL AS STRING) AS _internal_dimension,
{% endif %}
    CAST(NULL AS BOOLEAN) AS _internal_simple_rule_row_is_valid,
    TRUE AS _internal_skip_null_count,
    custom_sql_statement_validation_errors.complex_rule_validation_errors_count AS complex_rule_validation_errors_count,
    CASE
      WHEN custom_sql_statement_validation_errors.complex_rule_validation_errors_count IS NULL THEN TRUE
      WHEN custom_sql_statement_validation_errors.complex_rule_validation_errors_count = 0 THEN TRUE
      ELSE FALSE
    END AS _internal_complex_rule_validation_success_flag,
  FROM
    zero_record
  LEFT JOIN
    (
      SELECT
        *,
        '{{ rule_binding_id }}' AS _rule_binding_id,
        COUNT(*) OVER() AS complex_rule_validation_errors_count,
      FROM (
      {{ rule_configs.get("rule_sql_expr") }}
      ) custom_sql
    ) custom_sql_statement_validation_errors
  ON
    zero_record.rule_binding_id = custom_sql_statement_validation_errors._rule_binding_id
{% endmacro -%}
