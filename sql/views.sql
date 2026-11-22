DROP VIEW IF EXISTS v_jobs CASCADE;
DROP VIEW IF EXISTS v_job_skills CASCADE;
DROP VIEW IF EXISTS v_skill_pairs CASCADE;
DROP VIEW IF EXISTS v_monthly_trend CASCADE;

CREATE VIEW v_jobs AS
SELECT j.job_id, j.job_code, j.title, j.role_group,
       CASE WHEN j.role_group <> 'Other Tech' THEN 1 ELSE 0 END AS is_data_role,
       c.name AS company, j.company_type, j.industry, j.city, j.location_tier,
       j.work_mode, j.job_type, j.experience_level,
       CASE WHEN j.experience_level LIKE 'Fresher%' THEN 1
            WHEN j.experience_level LIKE 'Junior%'  THEN 2
            WHEN j.experience_level LIKE 'Mid%'     THEN 3
            WHEN j.experience_level LIKE 'Senior%'  THEN 4
            ELSE 5 END AS exp_order,
       j.is_fresher, j.education, j.salary_lpa, j.openings, j.applicants,
       j.company_rating, j.posted_date
FROM jobs j
JOIN companies c ON c.company_id = j.company_id;

CREATE VIEW v_job_skills AS
SELECT js.job_id, s.skill_name
FROM job_skills js
JOIN skills s ON s.skill_id = js.skill_id;

CREATE VIEW v_skill_pairs AS
SELECT s1.skill_name AS skill_a, s2.skill_name AS skill_b, COUNT(*) AS jobs_together
FROM job_skills a
JOIN job_skills b ON a.job_id = b.job_id AND a.skill_id < b.skill_id
JOIN jobs j       ON j.job_id = a.job_id
JOIN skills s1    ON s1.skill_id = a.skill_id
JOIN skills s2    ON s2.skill_id = b.skill_id
WHERE j.role_group <> 'Other Tech'
GROUP BY s1.skill_name, s2.skill_name
ORDER BY jobs_together DESC
LIMIT 100;

CREATE VIEW v_monthly_trend AS
WITH monthly AS (
    SELECT DATE_TRUNC('month', posted_date)::date AS month, COUNT(*) AS postings
    FROM jobs
    WHERE role_group <> 'Other Tech'
    GROUP BY 1
)
SELECT month, postings,
       ROUND(AVG(postings) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS rolling_3mo
FROM monthly;