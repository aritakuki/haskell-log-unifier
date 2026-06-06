rule "auth_error" { pattern: "BAD" transform: { message: "AUTH ERROR" } }
rule "db_error" { pattern: "ERROR: database" transform: { message: "DATABASE CONNECTION FAILED" } }
rule "api_timeout" { pattern: "timeout" transform: { message: "API TIMEOUT DETECTED" } }
rule "high_latency" { pattern: "latency" transform: { message: "HIGH LATENCY WARNING" } }
