-- Q1: Which reel length performs best (including follow ratio)?

SELECT b.bucket_name,
       COUNT(*)                                                                   AS num_posts,
       ROUND(AVG(m.views), 0)                                                     AS avg_views,
       ROUND(AVG(m.reach), 0)                                                     AS avg_reach,
       ROUND(AVG((m.likes + m.comments + m.shares + m.saves) * 1.0 / m.reach), 4) AS avg_engagement_rate,
       ROUND(SUM(m.follows) * 1000.0 / SUM(m.reach), 2)                           AS follows_per_1k_reach
FROM posts p
JOIN post_metrics m     ON m.post_id = p.post_id
JOIN duration_buckets b ON p.duration_sec BETWEEN b.min_sec AND b.max_sec
GROUP BY b.bucket_name
ORDER BY b.sort_order;