import Foundation

enum Fixtures {
    static let instanceJSON = """
    {
      "name": "school-ind-test",
      "status": "running",
      "http_port": 9010,
      "pg_port": 5433,
      "localhost_url": "http://localhost:9010",
      "devnet_url": "http://dhis2-school-ind-test:8080",
      "devnet_db": "dhis2-school-ind-test-db:5432",
      "agent_managed": false,
      "analytics": "doris",
      "dhis2_major_version": "42"
    }
    """

    static let instanceMinimalJSON = """
    {
      "name": "agent-test1",
      "status": "stopped",
      "http_port": null,
      "pg_port": null,
      "localhost_url": null,
      "devnet_url": null,
      "devnet_db": null,
      "agent_managed": true
    }
    """

    static let seedJSON = """
    {
      "path": "sl-demo-v42.sql.gz",
      "source": "seeds",
      "size_bytes": 184729281,
      "modified": "2026-04-01T13:22:08+00:00"
    }
    """

    static let jobRunningJSON = """
    {
      "id": "j-1a2b3c4d",
      "op": "create",
      "instance": "agent-test1",
      "status": "running",
      "created_at": "2026-06-13T09:14:01+00:00",
      "started_at": "2026-06-13T09:14:02+00:00",
      "finished_at": null,
      "exit_code": null,
      "error": null,
      "result": null,
      "log_tail": "...last 20 lines..."
    }
    """

    static let jobSucceededJSON = """
    {
      "id": "j-1a2b3c4d",
      "op": "create",
      "instance": "agent-test1",
      "status": "succeeded",
      "created_at": "2026-06-13T09:14:01+00:00",
      "started_at": "2026-06-13T09:14:02+00:00",
      "finished_at": "2026-06-13T09:15:30+00:00",
      "exit_code": 0,
      "error": null,
      "result": {
        "name": "agent-test1",
        "status": "running",
        "http_port": 9011,
        "pg_port": 5434,
        "localhost_url": "http://localhost:9011",
        "devnet_url": "http://dhis2-agent-test1:8080",
        "devnet_db": "dhis2-agent-test1-db:5432",
        "agent_managed": true
      }
    }
    """

    /// A succeeded backup job: `result` is a GET /seeds element, not an instance.
    static let jobBackupSucceededJSON = """
    {
      "id": "j-9z8y7x6w",
      "op": "backup",
      "instance": "demo1",
      "status": "succeeded",
      "created_at": "2026-06-14T09:14:01+00:00",
      "started_at": "2026-06-14T09:14:02+00:00",
      "finished_at": "2026-06-14T09:15:30+00:00",
      "exit_code": 0,
      "error": null,
      "result": {
        "path": "backups/demo1/demo1_20260614-091401_v42.sql.gz",
        "source": "backups",
        "size_bytes": 928374829,
        "modified": "2026-06-14T09:14:01+00:00"
      }
    }
    """

    static func data(_ s: String) -> Data { Data(s.utf8) }
}
