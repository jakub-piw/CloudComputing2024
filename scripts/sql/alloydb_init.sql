-- Create the users table
CREATE TABLE users (
    id VARCHAR(21) PRIMARY KEY
);

-- Create the locations table
CREATE TABLE locations (
    user_id VARCHAR(21),
    location_id INT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);