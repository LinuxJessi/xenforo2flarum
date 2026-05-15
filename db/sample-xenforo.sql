-- ============================================================================
-- sample-xenforo.sql — a tiny, fake XenForo database for smoke-testing the kit.
--
-- This is NOT a real forum. It contains just enough data, across the 14 xf_
-- tables nitro-porter's XenForo source reads, to exercise a full migration run:
-- users, roles, signatures, categories, discussions, comments, and one private
-- conversation. The attachment tables are created but intentionally left empty.
--
-- Usage:
--   cp db/sample-xenforo.sql db/source.sql      # then bring up the porter stack
--
-- The schema is modelled on XenForo 2.x but only includes the columns nitro-
-- porter actually reads — it is deliberately minimal, not a full XenForo schema.
-- ============================================================================

SET NAMES utf8mb4;

-- ---------- Users & roles ---------------------------------------------------

DROP TABLE IF EXISTS xf_user_group;
CREATE TABLE xf_user_group (
    user_group_id INT UNSIGNED NOT NULL PRIMARY KEY,
    title VARCHAR(100) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO xf_user_group (user_group_id, title) VALUES
    (1, 'Unregistered / Unconfirmed'),
    (2, 'Registered'),
    (3, 'Administrative'),
    (4, 'Moderating');

DROP TABLE IF EXISTS xf_user;
CREATE TABLE xf_user (
    user_id INT UNSIGNED NOT NULL PRIMARY KEY,
    username VARCHAR(50) NOT NULL DEFAULT '',
    email VARCHAR(120) NOT NULL DEFAULT '',
    custom_title VARCHAR(100) NOT NULL DEFAULT '',
    register_date INT UNSIGNED NOT NULL DEFAULT 0,
    last_activity INT UNSIGNED NOT NULL DEFAULT 0,
    is_admin TINYINT NOT NULL DEFAULT 0,
    is_banned TINYINT NOT NULL DEFAULT 0,
    avatar_date INT UNSIGNED NOT NULL DEFAULT 0,
    user_group_id INT UNSIGNED NOT NULL DEFAULT 2,
    secondary_group_ids VARCHAR(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO xf_user
    (user_id, username, email, custom_title, register_date, last_activity, is_admin, is_banned, avatar_date, user_group_id, secondary_group_ids) VALUES
    (1, 'admin', 'admin@example.com', 'Site Owner', 1700000000, 1715000000, 1, 0, 0, 3, '4'),
    (2, 'alice', 'alice@example.com', 'Regular',    1701000000, 1714000000, 0, 0, 0, 2, ''),
    (3, 'bob',   'bob@example.com',   '',           1702000000, 1713000000, 0, 0, 0, 2, '');

DROP TABLE IF EXISTS xf_user_authenticate;
CREATE TABLE xf_user_authenticate (
    user_id INT UNSIGNED NOT NULL PRIMARY KEY,
    data MEDIUMBLOB
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- `data` is a serialized XenForo auth blob. These are fake — migrated users
-- simply won't be able to log in with the old password, which is fine here.
-- nitro-porter joins user_authenticate to user, so every user needs a row.
INSERT INTO xf_user_authenticate (user_id, data) VALUES
    (1, 'a:2:{s:4:"hash";s:60:"$2y$10$abcdefghijklmnopqrstuvOaBcDeFgHiJkLmNoPqRsTuVwXyZ012345";s:6:"scheme";s:6:"bcrypt";}'),
    (2, 'a:2:{s:4:"hash";s:60:"$2y$10$bcdefghijklmnopqrstuvOaBcDeFgHiJkLmNoPqRsTuVwXyZ012345";s:6:"scheme";s:6:"bcrypt";}'),
    (3, 'a:2:{s:4:"hash";s:60:"$2y$10$cdefghijklmnopqrstuvwOaBcDeFgHiJkLmNoPqRsTuVwXyZ012345";s:6:"scheme";s:6:"bcrypt";}');

DROP TABLE IF EXISTS xf_user_profile;
CREATE TABLE xf_user_profile (
    user_id INT UNSIGNED NOT NULL PRIMARY KEY,
    signature TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- bob's signature is empty on purpose — nitro-porter should skip it.
INSERT INTO xf_user_profile (user_id, signature) VALUES
    (1, 'Running this place since the beginning.'),
    (2, 'Hello from Alice!'),
    (3, '');

-- ---------- Categories / forums ---------------------------------------------

DROP TABLE IF EXISTS xf_node;
CREATE TABLE xf_node (
    node_id INT UNSIGNED NOT NULL PRIMARY KEY,
    title VARCHAR(150) NOT NULL DEFAULT '',
    description TEXT,
    node_type_id VARBINARY(25) NOT NULL DEFAULT '',
    parent_node_id INT UNSIGNED NOT NULL DEFAULT 0,
    display_order INT UNSIGNED NOT NULL DEFAULT 0,
    display_in_list TINYINT NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO xf_node
    (node_id, title, description, node_type_id, parent_node_id, display_order, display_in_list) VALUES
    (1, 'Example Community',  'Top-level category for the demo forum.', 'Category', 0, 1, 1),
    (2, 'Announcements',      'News and updates from the team.',        'Forum',    1, 2, 1),
    (3, 'General Discussion', 'Talk about anything here.',              'Forum',    1, 3, 1);

-- ---------- Threads & posts -------------------------------------------------

DROP TABLE IF EXISTS xf_thread;
CREATE TABLE xf_thread (
    thread_id INT UNSIGNED NOT NULL PRIMARY KEY,
    node_id INT UNSIGNED NOT NULL DEFAULT 0,
    title VARCHAR(150) NOT NULL DEFAULT '',
    reply_count INT UNSIGNED NOT NULL DEFAULT 0,
    view_count INT UNSIGNED NOT NULL DEFAULT 0,
    user_id INT UNSIGNED NOT NULL DEFAULT 0,
    post_date INT UNSIGNED NOT NULL DEFAULT 0,
    sticky TINYINT NOT NULL DEFAULT 0,
    discussion_open TINYINT NOT NULL DEFAULT 1,
    last_post_date INT UNSIGNED NOT NULL DEFAULT 0,
    first_post_id INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- first_post_id must point at a real xf_post row — it becomes the discussion body.
INSERT INTO xf_thread
    (thread_id, node_id, title, reply_count, view_count, user_id, post_date, sticky, discussion_open, last_post_date, first_post_id) VALUES
    (1, 2, 'Welcome to the example forum', 1, 42, 1, 1700100000, 1, 1, 1700300000, 1),
    (2, 3, 'Introduce yourself',           1, 17, 2, 1701100000, 0, 1, 1701200000, 2),
    (3, 3, 'Favorite features?',           1,  9, 3, 1702100000, 0, 1, 1702200000, 4);

DROP TABLE IF EXISTS xf_post;
CREATE TABLE xf_post (
    post_id INT UNSIGNED NOT NULL PRIMARY KEY,
    thread_id INT UNSIGNED NOT NULL DEFAULT 0,
    user_id INT UNSIGNED NOT NULL DEFAULT 0,
    post_date INT UNSIGNED NOT NULL DEFAULT 0,
    message MEDIUMTEXT,
    ip_id INT UNSIGNED NOT NULL DEFAULT 0,
    message_state VARBINARY(25) NOT NULL DEFAULT 'visible'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- The first post of each thread is its discussion body; the rest are comments.
INSERT INTO xf_post
    (post_id, thread_id, user_id, post_date, message, ip_id, message_state) VALUES
    (1, 1, 1, 1700100000, 'Welcome! This is the first post of the demo forum. [b]Have a look around.[/b]', 0, 'visible'),
    (2, 2, 2, 1701100000, 'Hi everyone, I am Alice. Glad to be here!', 0, 'visible'),
    (3, 2, 3, 1701200000, 'Welcome aboard, Alice! - Bob', 0, 'visible'),
    (4, 3, 3, 1702100000, 'What features do you all use the most?', 0, 'visible'),
    (5, 3, 1, 1702200000, 'The search works great. Also tags.', 0, 'visible'),
    (6, 1, 2, 1700300000, 'Thanks for setting this up!', 0, 'visible');

DROP TABLE IF EXISTS xf_ip;
CREATE TABLE xf_ip (
    ip_id INT UNSIGNED NOT NULL PRIMARY KEY,
    ip VARBINARY(16) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- Left empty on purpose: every post above uses ip_id = 0, so nitro-porter's
-- LEFT JOIN on xf_ip simply yields NULL and no IP addresses are recorded.

-- ---------- Attachments (tables only — the sample ships no files) -----------

DROP TABLE IF EXISTS xf_attachment;
CREATE TABLE xf_attachment (
    attachment_id INT UNSIGNED NOT NULL PRIMARY KEY,
    data_id INT UNSIGNED NOT NULL DEFAULT 0,
    content_id INT UNSIGNED NOT NULL DEFAULT 0,
    content_type VARBINARY(25) NOT NULL DEFAULT 'post'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS xf_attachment_data;
CREATE TABLE xf_attachment_data (
    data_id INT UNSIGNED NOT NULL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL DEFAULT '',
    file_size INT UNSIGNED NOT NULL DEFAULT 0,
    user_id INT UNSIGNED NOT NULL DEFAULT 0,
    width INT UNSIGNED NOT NULL DEFAULT 0,
    height INT UNSIGNED NOT NULL DEFAULT 0,
    upload_date INT UNSIGNED NOT NULL DEFAULT 0,
    file_path VARCHAR(255) NOT NULL DEFAULT '',
    file_key VARCHAR(64) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- Both attachment tables are intentionally empty — keeps the smoke test simple.

-- ---------- Private conversations -------------------------------------------

DROP TABLE IF EXISTS xf_conversation_master;
CREATE TABLE xf_conversation_master (
    conversation_id INT UNSIGNED NOT NULL PRIMARY KEY,
    title VARCHAR(150) NOT NULL DEFAULT '',
    user_id INT UNSIGNED NOT NULL DEFAULT 0,
    start_date INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO xf_conversation_master (conversation_id, title, user_id, start_date) VALUES
    (1, 'Welcome aboard', 1, 1701150000);

DROP TABLE IF EXISTS xf_conversation_message;
CREATE TABLE xf_conversation_message (
    message_id INT UNSIGNED NOT NULL PRIMARY KEY,
    conversation_id INT UNSIGNED NOT NULL DEFAULT 0,
    message_date INT UNSIGNED NOT NULL DEFAULT 0,
    user_id INT UNSIGNED NOT NULL DEFAULT 0,
    message MEDIUMTEXT,
    ip_id INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO xf_conversation_message (message_id, conversation_id, message_date, user_id, message, ip_id) VALUES
    (1, 1, 1701150000, 1, 'Hi Alice — welcome to the forum. Ping me if you need anything.', 0);

DROP TABLE IF EXISTS xf_conversation_recipient;
CREATE TABLE xf_conversation_recipient (
    conversation_id INT UNSIGNED NOT NULL,
    user_id INT UNSIGNED NOT NULL,
    recipient_state VARBINARY(25) NOT NULL DEFAULT 'active',
    PRIMARY KEY (conversation_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO xf_conversation_recipient (conversation_id, user_id, recipient_state) VALUES
    (1, 1, 'active'),
    (1, 2, 'active');

DROP TABLE IF EXISTS xf_conversation_user;
CREATE TABLE xf_conversation_user (
    conversation_id INT UNSIGNED NOT NULL,
    owner_user_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (conversation_id, owner_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO xf_conversation_user (conversation_id, owner_user_id) VALUES
    (1, 1);
