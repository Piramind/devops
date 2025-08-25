WITH params AS (SELECT 'public'::text AS nsp),

col_defs AS (
  SELECT
    n.nspname        AS schema_name,
    c.relname        AS table_name,
    a.attnum,
    format(
      '    %I %s%s%s',
      a.attname,
      format_type(a.atttypid, a.atttypmod),
      CASE WHEN a.attnotnull THEN ' NOT NULL' ELSE '' END,
      COALESCE(' DEFAULT ' || pg_get_expr(ad.adbin, ad.adrelid), '')
    ) AS coldef
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
  LEFT JOIN pg_attrdef ad ON ad.adrelid = c.oid AND ad.adnum = a.attnum
  WHERE c.relkind IN ('r','p')  -- обычные и партиционированные таблицы
    AND n.nspname = (SELECT nsp FROM params)
),

per_table AS (
  SELECT
    schema_name,
    table_name,
    string_agg(coldef, E',\n' ORDER BY attnum) AS cols_ddl
  FROM col_defs
  GROUP BY schema_name, table_name
)

SELECT string_agg(
         format('CREATE TABLE %I.%I (\n%s\n);',
                schema_name, table_name, cols_ddl),
         E'\n\n' ORDER BY schema_name, table_name
       ) AS ddl
FROM per_table;