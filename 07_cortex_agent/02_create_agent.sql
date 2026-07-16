/* ============================================================================
   07 — Cortex Agent: Programmatic creation (alternatif dari UI)
   ============================================================================ */
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GEN2_SMALL;
USE DATABASE CLIK_WORKSHOP2;
USE SCHEMA PUBLIC;

CREATE OR REPLACE CORTEX AGENT CLIK_ANALYTICS_AGENT
  COMMENT = 'Credit bureau analytics chatbot for CLIK workshop'
  MODEL = 'claude-3-5-sonnet'
  SYSTEM_PROMPT = 'You are a credit bureau analytics assistant for CLIK (PT CRIF Lembaga Informasi Keuangan). You help users analyze loan application data, credit risk metrics, and portfolio performance. Always provide clear explanations with the data. Use Indonesian when user writes in Indonesian. When showing monetary values, use IDR format (Rp).'
  TOOLS = (
    ANALYST(SEMANTIC_VIEW => 'CLIK_WORKSHOP2.PUBLIC.CLIK_CREDIT_ANALYTICS')
  );

-- Test agent via SQL
SELECT SNOWFLAKE.CORTEX.AGENT(
  'CLIK_ANALYTICS_AGENT',
  'Berapa total aplikasi kredit per bulan di tahun 2025?'
) AS response;
