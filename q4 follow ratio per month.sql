-- Q5: How has my follow ratio changed month over month?

WITH monthly AS (
    SELECT p.year_month,
           COUNT(*)                               AS num_posts,
           SUM(m.reach)                           AS total_reach,
           SUM(m.follows)                         AS total_follows,
           SUM(m.follows) * 1000.0 / SUM(m.reach) AS follows_per_1k_reach
    FROM posts p
    JOIN post_metrics m ON m.post_id = p.post_id
    GROUP BY p.year_month
)
SELECT year_month,
       num_posts,
       total_follows,
       ROUND(follows_per_1k_reach, 2)                                                        AS follows_per_1k_reach,
       ROUND(LAG(follows_per_1k_reach) OVER (ORDER BY year_month), 2)                        AS prev_month_ratio,
       ROUND(follows_per_1k_reach - LAG(follows_per_1k_reach) OVER (ORDER BY year_month), 2) AS mom_change
FROM monthly
ORDER BY year_month;