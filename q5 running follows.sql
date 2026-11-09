-- Q6a: How do my follows add up over time?

WITH monthly AS (
    SELECT p.year_month, SUM(m.follows) AS follows
    FROM posts p
    JOIN post_metrics m ON m.post_id = p.post_id
    GROUP BY p.year_month
)
SELECT year_month,
       follows,
       SUM(follows) OVER (ORDER BY year_month) AS running_follows,
       ROUND(100.0 * SUM(follows) OVER (ORDER BY year_month)
             / SUM(follows) OVER (), 1)        AS pct_of_total
FROM monthly
ORDER BY year_month;