rule "auth_error" { pattern: "BAD" transform: { message: "AUTH ERROR" } }
rule "db_error" { pattern: "ERROR: database" transform: { message: "DATABASE CONNECTION FAILED" } }
