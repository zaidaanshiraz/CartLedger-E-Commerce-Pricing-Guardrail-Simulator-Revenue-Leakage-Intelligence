/* =====================================================================
   VIEW: vw_customer_rfm
   Author: Mohammed Zaidaan Shiraz
   Purpose: Customer RFM Quintile Scoring (Zero Join Fan-Out)
   Note: Reads directly from pre-aggregated vw_customer_base (1 row per
         customer) without re-joining orders, preventing monetary fan-out.
         Recency is ordered DESC so NTILE(5)=5 represents the most recent
         buyers (smallest recency days).
   ===================================================================== */
CREATE OR ALTER VIEW vw_customer_rfm AS
SELECT
    vc.customer_id,
    vc.customer_name,
    vc.recency,
    vc.frequency,
    vc.monetary,
    NTILE(5) OVER (ORDER BY vc.recency DESC)   AS recency_score,
    NTILE(5) OVER (ORDER BY vc.frequency ASC)  AS frequency_score,
    NTILE(5) OVER (ORDER BY vc.monetary ASC)   AS monetary_score
FROM vw_customer_base vc;
