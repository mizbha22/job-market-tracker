DROP TABLE IF EXISTS job_skills CASCADE;
DROP TABLE IF EXISTS jobs CASCADE;
DROP TABLE IF EXISTS skills CASCADE;
DROP TABLE IF EXISTS companies CASCADE;

CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    name       VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE skills (
    skill_id   SERIAL PRIMARY KEY,
    skill_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE jobs (
    job_id           INT PRIMARY KEY,
    job_code         VARCHAR(30),
    title            VARCHAR(300),
    role_group       VARCHAR(30),
    company_id       INT REFERENCES companies(company_id),
    company_type     VARCHAR(50),
    industry         VARCHAR(100),
    city             VARCHAR(100),
    location_tier    VARCHAR(30),
    work_mode        VARCHAR(30),
    job_type         VARCHAR(30),
    experience_level VARCHAR(60),
    exp_min          NUMERIC(4,1),
    exp_max          NUMERIC(4,1),
    is_fresher       SMALLINT,
    education        VARCHAR(100),
    salary_lpa       NUMERIC(6,2),
    openings         INT,
    applicants       INT,
    company_rating   NUMERIC(3,1),
    posted_date      DATE
);

CREATE TABLE job_skills (
    job_id   INT REFERENCES jobs(job_id),
    skill_id INT REFERENCES skills(skill_id),
    PRIMARY KEY (job_id, skill_id)
);

CREATE INDEX idx_jobs_role ON jobs(role_group);
CREATE INDEX idx_jobs_city ON jobs(city);
CREATE INDEX idx_js_skill  ON job_skills(skill_id);